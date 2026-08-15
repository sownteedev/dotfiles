import "../../"
import "../../service"
import QtQuick
import Quickshell

Variants {
    id: desktopVariants

    model: Quickshell.screens

    delegate: Component {
        LazyLoader {
            id: wallpaperLoader

            required property var modelData
            readonly property bool requested: (!LiveWallpaperService.active && !EngineWallpaperService.active) || WallpaperService.liveRevealActive || WallpaperService.previewActive || EngineWallpaperService.policyRestarting

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
