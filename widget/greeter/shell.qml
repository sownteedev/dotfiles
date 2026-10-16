import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: GreeterSession.pamTestMode ? Quickshell.screens.slice(0, 1) : Quickshell.screens

        delegate: Component {
            GreeterWindow {
                required property var modelData

                primary: modelData === Quickshell.screens[0]
                screen: modelData
            }
        }
    }
}
