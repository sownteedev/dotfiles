import "../../service"
import QtQuick

Item {
    id: root

    readonly property var ratioOptions: ["16x9", "16x10", "21x9", "32x9", "48x9", "9x16", "10x16", "9x18", "1x1", "3x2", "4x3", "5x4"]

    signal closeRequested
    signal filterChanged

    implicitHeight: 142
    implicitWidth: 390

    Column {
        anchors.fill: parent
        spacing: 8

        Grid {
            columns: 4
            spacing: 6

            Repeater {
                model: root.ratioOptions

                delegate: WallhavenChoiceButton {
                    required property string modelData

                    height: 30
                    label: modelData.replace("x", " : ")
                    selected: WallhavenService.ratios === modelData
                    width: 93

                    onClicked: {
                        WallhavenService.ratios = selected ? "" : modelData;
                        root.filterChanged();
                        root.closeRequested();
                    }
                }
            }
        }
        WallhavenChoiceButton {
            height: 30
            label: qsTr("Any ratio")
            selected: WallhavenService.ratios === ""
            width: 122

            onClicked: {
                WallhavenService.ratios = "";
                root.filterChanged();
                root.closeRequested();
            }
        }
    }
}
