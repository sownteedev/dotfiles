pragma ComponentBehavior: Bound

import QtQuick
import "../../"

Item {
    id: root

    property bool dropActive: false
    property var entries: []
    readonly property real previewIconSize: Math.max(15, Math.min(23, (Math.min(width, height) - 32) / 3))

    implicitHeight: 92
    implicitWidth: 92

    Rectangle {
        anchors.fill: parent
        border.color: Config.alpha(root.dropActive ? Config.md3.primary : Config.md3.outline_variant, root.dropActive ? 0.56 : 0.22)
        border.width: root.dropActive ? 2 : 0
        color: root.dropActive ? Config.alpha(Config.md3.primary_container, 0.88) : Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.82 : 0.7)
        radius: Math.min(width, height) * 0.24
        scale: root.dropActive ? 1.06 : 1

        Behavior on color {
            ColorAnimation {
                duration: Config.animationDuration(120)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(150)
                easing.type: Easing.OutBack
            }
        }

        Grid {
            anchors.centerIn: parent
            columns: 3
            height: width
            spacing: 3
            width: root.previewIconSize * 3 + spacing * 2

            Repeater {
                model: Math.min(9, root.entries.length)

                delegate: LauncherAppIcon {
                    required property int index

                    entry: root.entries[index]
                    height: root.previewIconSize
                    requestedSourceSize: 96
                    width: root.previewIconSize
                }
            }
        }
    }
}
