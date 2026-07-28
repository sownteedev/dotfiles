import "../../"
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property int activeIndex: {
        for (var i = 0; i < modes.length; ++i) {
            if (modes[i].key === root.mode)
                return i;
        }
        return 0;
    }
    property string mode: "static"
    property var modes: [
        {
            "key": "static",
            "label": "Static",
            "icon": "image-x-generic-symbolic"
        },
        {
            "key": "video",
            "label": "Live",
            "icon": "media-playback-start-symbolic"
        }
    ]

    signal modeRequested(string mode)

    border.color: Config.alpha(Config.md3.on_surface, 0.12)
    border.width: 1
    color: Config.alpha(Config.md3.surface, 0.88)
    implicitHeight: 44
    implicitWidth: 170
    radius: height / 2

    Rectangle {
        id: highlightPill

        color: Config.md3.primary
        height: root.height - 8
        radius: height / 2
        width: (root.width - 12) / 2
        x: 4 + root.activeIndex * (width + 4)
        y: 4

        Behavior on x {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }
    Row {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: root.modes

            delegate: Rectangle {
                required property int index
                required property var modelData

                color: "transparent"
                height: parent.height
                radius: height / 2
                width: (root.width - 12) / 2

                IconImage {
                    anchors.centerIn: parent
                    height: 20
                    layer.enabled: true
                    source: Quickshell.iconPath(modelData.icon)
                    width: 20

                    layer.effect: ColorOverlay {
                        color: root.mode === modelData.key ? Config.md3.background : Config.md3.on_surface_variant

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.modeRequested(modelData.key)
                }
            }
        }
    }
}
