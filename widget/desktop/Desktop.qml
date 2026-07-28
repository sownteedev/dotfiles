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

            activeAsync: (!LiveWallpaperService.active && !EngineWallpaperService.active) || WallpaperService.liveRevealActive || WallpaperService.previewActive || EngineWallpaperService.policyRestarting

            Wallpaper {
                screen: wallpaperLoader.modelData
                wallpaperPath: WallpaperService.displayWallpaper
                windowNamespace: "wallpaper-" + wallpaperLoader.modelData.name
            }

        }

    }

}
