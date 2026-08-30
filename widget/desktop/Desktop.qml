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
                readonly property bool requested: WallpaperService.ready && ((!LiveWallpaperService.active && !EngineWallpaperService.active) || WallpaperService.liveRevealActive || (WallpaperService.previewActive && WallpaperService.previewPath !== "") || EngineWallpaperService.policyRestarting)

                function syncRequestedState() {
                    if (requested) {
                        if (!active && !loading)
                            loading = true;
                    } else if (active)
                        active = false;
                    else if (loading)
                        loading = false;
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
}
