import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            GreeterWindow {
                required property var modelData

                primary: modelData === Quickshell.screens[0]
                screen: modelData
            }
        }
    }
}
