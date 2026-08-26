import "../../"
import "../../service"
import QtQuick
import Quickshell

Scope {
    id: desktopVariants

    Variants {
        model: Quickshell.screens

        delegate: Component {
            LazyLoader {
                id: wallpaperLoader

                required property var modelData
                readonly property bool requested: (!LiveWallpaperService.active && !EngineWallpaperService.active) || WallpaperService.liveRevealActive || (WallpaperService.previewActive && WallpaperService.previewPath !== "") || EngineWallpaperService.policyRestarting

                function syncRequestedState() {
                    if (requested) {
                        if (!active && !loading)
                            loading = true;
                    } else if (active) {
                        active = false;
                    } else if (loading) {
                        loading = false;
                    }
                }

                Component.onCompleted: syncRequestedState()
                onRequestedChanged: syncRequestedState()

                Wallpaper {
                    screen: wallpaperLoader.modelData
                    wallpaperPath: WallpaperService.displayWallpaper
                    windowNamespace: "wallpaper-" + wallpaperLoader.modelData.name
                }
            }
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            LazyLoader {
                id: videoLoader

                required property var modelData
                readonly property bool requested: LiveWallpaperService.active
                property Timer unloadTimer: Timer {
                    interval: 120
                    repeat: false

                    onTriggered: videoLoader.releaseRenderer()
                }

                function releaseRenderer() {
                    if (requested)
                        return;
                    if (active)
                        active = false;
                    else if (loading)
                        loading = false;
                }
                function syncRequestedState() {
                    if (requested) {
                        videoLoader.unloadTimer.stop();
                        if (!active && !loading)
                            loading = true;
                    } else if (active || loading) {
                        videoLoader.unloadTimer.restart();
                    }
                }

                Component.onCompleted: syncRequestedState()
                onRequestedChanged: syncRequestedState()

                VideoWallpaper {
                    screen: videoLoader.modelData
                    windowNamespace: "video-wallpaper-" + videoLoader.modelData.name
                }
            }
        }
    }
}
