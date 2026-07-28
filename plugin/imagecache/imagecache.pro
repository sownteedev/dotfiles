QT += core gui qml quick

CONFIG += c++17 plugin release
TEMPLATE = lib
TARGET = nativeimagecacheplugin

DESTDIR = $$PWD/qml/Native/ImageCache
OBJECTS_DIR = build/obj
MOC_DIR = build/moc
RCC_DIR = build/rcc
UI_DIR = build/ui

SOURCES += \
    cachingimageprovider.cpp \
    imagecacheplugin.cpp

HEADERS += \
    cachingimageprovider.hpp \
    imagecacheplugin.hpp
