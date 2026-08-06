#include "cachingimageprovider.hpp"

#include <algorithm>
#include <atomic>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QMutex>
#include <QMutexLocker>
#include <QPainter>
#include <QQuickTextureFactory>
#include <QRunnable>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThreadPool>
#include <QUrl>

namespace {

constexpr qint64 kMaximumCacheBytes = 64LL * 1024 * 1024;
constexpr qsizetype kMaximumCacheFiles = 256;
constexpr int kPruneBatchInterval = 8;

QMutex cacheMutex;
bool initialCachePruneDone = false;
std::atomic<int> cacheWritesSincePrune{0};

QString cacheDirectory() {
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
        + QStringLiteral("/image-cache");
}

void markCacheEntryUsed(const QString& path) {
    QFile file(path);
    if (file.open(QIODevice::ReadOnly))
        file.setFileTime(QDateTime::currentDateTimeUtc(), QFileDevice::FileModificationTime);
}

void pruneCache() {
    QDir directory(cacheDirectory());
    QFileInfoList files = directory.entryInfoList(
        { QStringLiteral("*.jpg") },
        QDir::Files | QDir::NoSymLinks);

    qint64 totalBytes = 0;
    for (const QFileInfo& file : files)
        totalBytes += file.size();

    if (files.size() <= kMaximumCacheFiles && totalBytes <= kMaximumCacheBytes)
        return;

    std::sort(files.begin(), files.end(), [](const QFileInfo& left, const QFileInfo& right) {
        return left.lastModified() < right.lastModified();
    });

    qsizetype remainingFiles = files.size();
    for (const QFileInfo& file : files) {
        if (remainingFiles <= kMaximumCacheFiles && totalBytes <= kMaximumCacheBytes)
            break;

        if (QFile::remove(file.absoluteFilePath())) {
            totalBytes -= file.size();
            --remainingFiles;
        }
    }
}

QString fillName(CachingImageProvider::FillMode fillMode) {
    switch (fillMode) {
    case CachingImageProvider::FillMode::Crop:
        return QStringLiteral("crop");
    case CachingImageProvider::FillMode::Fit:
        return QStringLiteral("fit");
    case CachingImageProvider::FillMode::Stretch:
        return QStringLiteral("stretch");
    }
    return QStringLiteral("crop");
}

QString sourcePathFromId(QString id) {
    id = id.section(QLatin1Char('?'), 0, 0);
    const QString path = QUrl::fromPercentEncoding(id.toUtf8());
    return path.startsWith(QLatin1Char('/')) ? path : QLatin1Char('/') + path;
}

QString cachePathFor(const QString& sourcePath, const QSize& size, CachingImageProvider::FillMode fillMode) {
    const QFileInfo info(sourcePath);
    const QString identity = info.canonicalFilePath()
        + QLatin1Char('|') + QString::number(info.size())
        + QLatin1Char('|') + QString::number(info.lastModified().toMSecsSinceEpoch())
        + QLatin1Char('|') + QString::number(size.width())
        + QLatin1Char('x') + QString::number(size.height())
        + QLatin1Char('|') + fillName(fillMode);
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(identity.toUtf8(), QCryptographicHash::Sha256).toHex());
    return cacheDirectory() + QLatin1Char('/') + hash + QStringLiteral(".jpg");
}

QSize scaledSize(const QSize& source, const QSize& target, CachingImageProvider::FillMode fillMode) {
    if (fillMode == CachingImageProvider::FillMode::Stretch)
        return target;
    return source.scaled(
        target,
        fillMode == CachingImageProvider::FillMode::Crop
            ? Qt::KeepAspectRatioByExpanding
            : Qt::KeepAspectRatio);
}

QImage decodeScaled(const QString& sourcePath, const QSize& target, CachingImageProvider::FillMode fillMode) {
    QImageReader reader(sourcePath);
    reader.setAutoTransform(true);

    const QSize sourceSize = reader.size();
    if (sourceSize.isValid() && !sourceSize.isEmpty())
        reader.setScaledSize(scaledSize(sourceSize, target, fillMode));

    QImage image = reader.read();
    if (image.isNull())
        return {};

    const QSize wanted = scaledSize(image.size(), target, fillMode);
    if (image.size() != wanted)
        image = image.scaled(wanted, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);

    if (fillMode == CachingImageProvider::FillMode::Stretch)
        return image;

    if (fillMode == CachingImageProvider::FillMode::Crop) {
        // Directly crop from the centre — avoids a canvas allocation.
        const int x = (image.width()  - target.width())  / 2;
        const int y = (image.height() - target.height()) / 2;
        return image.copy(x, y, target.width(), target.height());
    }

    // Fit: paint centred onto an opaque canvas.
    QImage canvas(target, QImage::Format_RGB32);
    canvas.fill(Qt::black);
    QPainter painter(&canvas);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    painter.drawImage((target.width() - image.width()) / 2, (target.height() - image.height()) / 2, image);
    return canvas;
}

class CachingImageResponse final : public QQuickImageResponse, public QRunnable {
public:
    CachingImageResponse(QString id, QSize requestedSize, CachingImageProvider::FillMode fillMode)
        : m_id(std::move(id))
        , m_requestedSize(requestedSize)
        , m_fillMode(fillMode) {
        setAutoDelete(false);
    }

    QQuickTextureFactory* textureFactory() const override {
        return QQuickTextureFactory::textureFactoryForImage(m_image);
    }

    QString errorString() const override {
        return m_error;
    }

    void run() override {
        process();
        emit finished();
    }

private:
    void process() {
        const QString sourcePath = sourcePathFromId(m_id);
        if (!QFileInfo::exists(sourcePath)) {
            m_error = QStringLiteral("Image does not exist: ") + sourcePath;
            return;
        }

        QSize target = m_requestedSize;
        if (target.width() <= 0 || target.height() <= 0) {
            QImageReader reader(sourcePath);
            target = reader.size();
        }
        if (!target.isValid() || target.isEmpty()) {
            m_error = QStringLiteral("Invalid image size: ") + sourcePath;
            return;
        }

        const QString cachePath = cachePathFor(sourcePath, target, m_fillMode);
        {
            QMutexLocker locker(&cacheMutex);
            if (!initialCachePruneDone) {
                pruneCache();
                initialCachePruneDone = true;
            }
        }

        QImageReader cachedReader(cachePath);
        if (cachedReader.canRead()) {
            m_image = cachedReader.read();
            if (!m_image.isNull()) {
                QMutexLocker locker(&cacheMutex);
                markCacheEntryUsed(cachePath);
                return;
            }
        }

        m_image = decodeScaled(sourcePath, target, m_fillMode);
        if (m_image.isNull()) {
            m_error = QStringLiteral("Could not decode image: ") + sourcePath;
            return;
        }

        {
            QMutexLocker locker(&cacheMutex);
            QDir().mkpath(cacheDirectory());
            QSaveFile output(cachePath);
            if (output.open(QIODevice::WriteOnly) && m_image.save(&output, "JPEG", 92) && output.commit()) {
                if (++cacheWritesSincePrune >= kPruneBatchInterval) {
                    cacheWritesSincePrune.store(0);
                    pruneCache();
                }
            }
        }
    }

    QString m_id;
    QSize m_requestedSize;
    CachingImageProvider::FillMode m_fillMode;
    QImage m_image;
    QString m_error;
};

} // namespace

CachingImageProvider::CachingImageProvider(FillMode fillMode)
    : m_fillMode(fillMode) {
}

QQuickImageResponse* CachingImageProvider::requestImageResponse(const QString& id, const QSize& requestedSize) {
    auto* response = new CachingImageResponse(id, requestedSize, m_fillMode);
    QThreadPool::globalInstance()->start(response);
    return response;
}
