import "../../"
import "../../service"
import QtQuick

Item {
    id: root

    readonly property var colorOptions: ["660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399", "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300", "000000", "999999", "cccccc", "ffffff"]

    signal closeRequested
    signal filterChanged

    implicitHeight: 166
    implicitWidth: 302

    Column {
        anchors.fill: parent
        spacing: 8

        Grid {
            columns: 7
            spacing: 6

            Repeater {
                model: root.colorOptions

                delegate: Rectangle {
                    id: swatch

                    required property string modelData
                    readonly property bool selected: WallhavenService.colors.toLowerCase() === modelData

                    Accessible.name: qsTr("Color %1").arg(modelData)
                    Accessible.role: Accessible.Button
                    activeFocusOnTab: true
                    border.color: selected ? Config.md3.primary : Config.alpha(Config.md3.outline, 0.22)
                    border.width: selected ? 3 : 1
                    color: "#" + modelData
                    height: 30
                    radius: 8
                    scale: swatchMouse.containsMouse ? 1.06 : 1
                    width: 38

                    Behavior on scale {
                        ScaleAnimator {
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }

                    MouseArea {
                        id: swatchMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            WallhavenService.colors = swatch.selected ? "" : swatch.modelData;
                            root.filterChanged();
                            root.closeRequested();
                        }
                    }
                }
            }
        }
        WallhavenChoiceButton {
            height: 30
            label: qsTr("Any color")
            selected: WallhavenService.colors === ""
            width: 112

            onClicked: {
                WallhavenService.colors = "";
                root.filterChanged();
                root.closeRequested();
            }
        }
    }
}
