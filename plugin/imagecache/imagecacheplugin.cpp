#include "imagecacheplugin.hpp"

#include "cachingimageprovider.hpp"

#include <QQmlEngine>
#include <qqml.h>

void ImageCachePlugin::registerTypes(const char* uri) {
    qmlRegisterModule(uri, 1, 0);
}

void ImageCachePlugin::initializeEngine(QQmlEngine* engine, const char* uri) {
    Q_UNUSED(uri)
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
