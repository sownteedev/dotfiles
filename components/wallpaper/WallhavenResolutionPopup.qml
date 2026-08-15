import "../../"
import "../../service"
import QtQuick
import QtQuick.Controls

Item {
    id: root

    readonly property var resolutionOptions: ["1280x720", "1280x800", "1280x960", "1280x1024", "1600x900", "1600x1000", "1600x1200", "1600x1280", "1920x1080", "1920x1200", "1920x1440", "1920x1536", "2560x1080", "2560x1440", "2560x1600", "2560x1920", "3440x1440", "3840x1600", "3840x2160", "3840x2400"]

    signal closeRequested
    signal filterChanged

    function currentResolution() {
        return WallhavenService.resolutionMode === "exact" ? WallhavenService.resolutions : WallhavenService.atleast;
    }
    function setMode(mode) {
        if (mode === "any") {
            WallhavenService.atleast = "";
            WallhavenService.resolutions = "";
            filterChanged();
            closeRequested();
            return;
        }
        if (WallhavenService.resolutionMode === mode)
            return;

        var current = currentResolution();
        WallhavenService.resolutionMode = mode;
        WallhavenService.atleast = mode === "atleast" ? current : "";
        WallhavenService.resolutions = mode === "exact" ? current : "";
        if (current !== "")
            filterChanged();
    }
    function setResolution(value) {
        if (WallhavenService.resolutionMode === "exact") {
            WallhavenService.resolutions = value;
            WallhavenService.atleast = "";
        } else {
            WallhavenService.atleast = value;
            WallhavenService.resolutions = "";
        }
        filterChanged();
        closeRequested();
    }

    implicitHeight: 224
    implicitWidth: 492

    Column {
        anchors.fill: parent
        spacing: 8

        Row {
            spacing: 6

            Repeater {
                model: [
                    {
                        "label": qsTr("At least"),
                        "value": "atleast"
                    },
                    {
                        "label": qsTr("Exactly"),
                        "value": "exact"
                    },
                    {
                        "label": qsTr("Any"),
                        "value": "any"
                    }
                ]

                delegate: WallhavenChoiceButton {
                    required property var modelData

                    height: 32
                    label: modelData.label
                    selected: modelData.value === "any" ? root.currentResolution() === "" : (root.currentResolution() !== "" && WallhavenService.resolutionMode === modelData.value)
                    selectedTextColor: Config.md3.on_primary_container
                    width: 156

                    onClicked: root.setMode(modelData.value)
                }
            }
        }
        Grid {
            columns: 5
            spacing: 6

            Repeater {
                model: root.resolutionOptions

                delegate: WallhavenChoiceButton {
                    required property string modelData

                    height: 30
                    label: modelData.replace("x", " × ")
                    selected: root.currentResolution() === modelData
                    width: 93

                    onClicked: root.setResolution(modelData)
                }
            }
        }
        Row {
            spacing: 6

            TextField {
                id: customWidth

                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 12
                height: 32
                placeholderText: qsTr("Width")
                selectByMouse: true
                width: 118

                background: Rectangle {
                    color: Config.alpha(Config.md3.on_surface, 0.05)
                    radius: 10
                }
                validator: IntValidator {
                    bottom: 320
                    top: 16384
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.on_surface_variant
                font.pixelSize: 12
                text: "×"
            }
            TextField {
                id: customHeight

                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 12
                height: 32
                placeholderText: qsTr("Height")
                selectByMouse: true
                width: 118

                background: Rectangle {
                    color: Config.alpha(Config.md3.on_surface, 0.05)
                    radius: 10
                }
                validator: IntValidator {
                    bottom: 240
                    top: 16384
                }
            }
            WallhavenChoiceButton {
                accentColor: Config.md3.primary_container
                enabled: customWidth.acceptableInput && customHeight.acceptableInput
                height: 32
                label: qsTr("Apply")
                selected: true
                selectedTextColor: Config.md3.on_primary_container
                width: 78

                onClicked: root.setResolution(customWidth.text + "x" + customHeight.text)
            }
        }
    }
}
