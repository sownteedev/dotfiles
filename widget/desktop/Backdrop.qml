import QtQuick
import Quickshell
import "../../"
import "../../service"

Scope {
    id: backdropScope

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Wallpaper {
                required property var modelData

                allowVideoFade: false
                decodeAtScreenSize: true
                overlayColor: ThemeService.themeFileValid ? Config.alpha(Config.md3.background, 0.62) : "transparent"
                screen: modelData
                useNativeCache: false
                wallpaperPath: BackdropService.ready ? BackdropService.activeBackdrop : ""
                windowNamespace: "backdrop-" + modelData.name
            }
        }
    }
}
