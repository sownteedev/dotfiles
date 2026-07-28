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
                screen: modelData
                useNativeCache: false
                wallpaperPath: BackdropService.ready ? BackdropService.activeBackdrop : ""
                windowNamespace: "backdrop-" + modelData.name
            }
        }
    }
}
