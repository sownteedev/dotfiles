#include "imagecacheplugin.hpp"

#include "cachingimageprovider.hpp"

#include <QDir>
#include <QIcon>
#include <QQmlEngine>
#include <QStandardPaths>
#include <qqml.h>

void ImageCachePlugin::registerTypes(const char* uri) {
    qmlRegisterModule(uri, 1, 0);
}

void ImageCachePlugin::initializeEngine(QQmlEngine* engine, const char* uri) {
    Q_UNUSED(uri)
    // Some applications install unthemed icons directly under an XDG icons
    // directory. Keep those discoverable without a desktop platform theme.
    const auto originalFallbackPaths = QIcon::fallbackSearchPaths();
    auto fallbackPaths = originalFallbackPaths;
    QStringList iconDirectories {QDir::home().filePath(QStringLiteral(".icons"))};
    for (const auto& dataDirectory : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)) {
        const QDir directory(dataDirectory);
        iconDirectories.append(directory.filePath(QStringLiteral("icons")));
        iconDirectories.append(directory.filePath(QStringLiteral("pixmaps")));
    }
    for (const auto& directory : iconDirectories) {
        if (QDir(directory).exists() && !fallbackPaths.contains(directory))
            fallbackPaths.append(directory);
    }
    if (fallbackPaths != originalFallbackPaths)
        QIcon::setFallbackSearchPaths(fallbackPaths);

    engine->addImageProvider(
        QStringLiteral("dotfcache"),
        new CachingImageProvider(CachingImageProvider::FillMode::Crop));
    engine->addImageProvider(
        QStringLiteral("dotffitcache"),
        new CachingImageProvider(CachingImageProvider::FillMode::Fit));
    engine->addImageProvider(
        QStringLiteral("dotfstretchcache"),
        new CachingImageProvider(CachingImageProvider::FillMode::Stretch));
}
