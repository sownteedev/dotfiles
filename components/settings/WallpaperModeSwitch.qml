import "../../"
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import ".."

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
            "label": qsTr("Image"),
            "icon": "image-x-generic-symbolic"
        },
        {
            "key": "video",
            "label": qsTr("Video"),
            "icon": "media-playback-start-symbolic"
        }
    ]

    signal addRequested(string mode)
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
                id: modeDelegate

                readonly property bool addRevealed: hoverRegion.hovered || activeFocus || addButton.activeFocus
                required property int index
                required property var modelData

                Accessible.name: modelData.label
                Accessible.role: Accessible.PageTab
                activeFocusOnTab: true
                color: "transparent"
                height: parent.height
                radius: height / 2
                width: (root.width - 12) / 2

                Accessible.onPressAction: root.modeRequested(modeDelegate.modelData.key)
                Keys.onReturnPressed: root.modeRequested(modeDelegate.modelData.key)
                Keys.onSpacePressed: root.modeRequested(modeDelegate.modelData.key)

                // Extend the hover region across the gap and the add button,
                // without moving the tab or intercepting its clicks.
                Item {
                    height: root.height
                    width: modeDelegate.width + (modeDelegate.addRevealed ? 52 : 0)
                    x: modeDelegate.addRevealed && modeDelegate.index === 0 ? -52 : 0
                    y: -4
                    z: 5

                    HoverHandler {
                        id: hoverRegion
                    }
                }
                Md3IconButton {
                    id: addButton

                    Accessible.name: modeDelegate.modelData.key === "video" ? qsTr("Add video") : qsTr("Add image")
                    activeFocusOnTab: modeDelegate.addRevealed
                    containerSize: 36
                    containerStyle: "tonal"
                    height: 44
                    iconName: "add"
                    iconSize: 20
                    opacity: modeDelegate.addRevealed ? 1 : 0
                    visible: modeDelegate.addRevealed || opacity > 0
                    width: 44
                    x: modeDelegate.index === 0 ? (modeDelegate.addRevealed ? -52 : -36) : modeDelegate.width + (modeDelegate.addRevealed ? 8 : -8)
                    y: -4
                    z: 4

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animationDuration(70)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: Config.animationDuration(120)
                            easing.type: Easing.OutCubic
                        }
                    }

                    onClicked: {
                        if (modeDelegate.addRevealed)
                            root.addRequested(modeDelegate.modelData.key);
                    }
                }
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
                    id: modeMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.modeRequested(modelData.key)
                }
            }
        }
    }
}
