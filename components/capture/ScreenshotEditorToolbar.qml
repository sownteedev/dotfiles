import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property color selectedColor: "#ff3b30"
    property string selectedTool: "pen"
    property real selectedWidth: 6

    signal colorSelected(color colorValue)
    signal toolSelected(string tool)
    signal widthSelected(real widthValue)

    border.color: Config.alpha(Config.md3.on_surface, 0.1)
    border.width: 1
    color: Config.alpha(Config.md3.background, 0.94)
    implicitHeight: contentLayout.implicitHeight + 24
    implicitWidth: Math.max(toolRow.implicitWidth, settingsRow.implicitWidth) + 24
    radius: 20

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            id: toolRow

            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {
                        "tool": "select",
                        "glyph": "",
                        "iconName": "screenshot-ui-show-pointer-symbolic"
                    },
                    {
                        "tool": "pen",
                        "glyph": "✎"
                    },
                    {
                        "tool": "highlight",
                        "glyph": "▰"
                    },
                    {
                        "tool": "line",
                        "glyph": "╱"
                    },
                    {
                        "tool": "arrow",
                        "glyph": "➜"
                    },
                    {
                        "tool": "rectangle",
                        "glyph": "□"
                    },
                    {
                        "tool": "ellipse",
                        "glyph": "○"
                    },
                    {
                        "tool": "blur",
                        "glyph": "◐"
                    },
                    {
                        "tool": "pixelate",
                        "glyph": "▦"
                    },
                    {
                        "tool": "text",
                        "glyph": "T"
                    },
                    {
                        "tool": "number",
                        "glyph": "①"
                    },
                    {
                        "tool": "ocr",
                        "glyph": "OCR",
                        "fontSize": 11
                    },
                    {
                        "tool": "crop",
                        "glyph": "⌗"
                    }
                ]

                delegate: ScreenshotToolButton {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.minimumWidth: 44
                    Layout.preferredHeight: 42
                    Layout.preferredWidth: 48
                    selectedTool: root.selectedTool
                    toolData: modelData

                    onSelected: tool => {
                        return root.toolSelected(tool);
                    }
                }
            }
        }
        RowLayout {
            id: settingsRow

            Layout.fillWidth: true
            spacing: 8

            ScreenshotColorSlider {
                Layout.fillWidth: true
                Layout.minimumWidth: 300
                Layout.preferredHeight: 32
                Layout.preferredWidth: 360
                selectedColor: root.selectedColor
                visible: root.selectedTool !== "select"

                onColorSelected: colorValue => {
                    return root.colorSelected(colorValue);
                }
            }
            Rectangle {
                Layout.leftMargin: 4
                Layout.preferredHeight: 25
                Layout.preferredWidth: 1
                Layout.rightMargin: 4
                color: Config.alpha(Config.md3.on_surface, 0.12)
                visible: root.selectedTool !== "select"
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 170
                Layout.preferredHeight: 32
                Layout.preferredWidth: 170
                spacing: 8
                visible: root.selectedTool !== "select"

                Text {
                    Layout.preferredWidth: 38
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignRight
                    text: {
                        if (root.selectedTool === "text")
                            return Math.round(root.selectedWidth * 3) + " px";

                        if (root.selectedTool === "number")
                            return Math.round(24 + root.selectedWidth) + " px";

                        if (root.selectedTool === "pixelate")
                            return Math.round(5 + root.selectedWidth * 0.75) + " px";

                        return Math.round(root.selectedWidth) + " px";
                    }
                }
                Item {
                    id: widthSlider

                    function updateWidth(mouseX) {
                        var ratio = Math.max(0, Math.min(1, mouseX / width));
                        root.widthSelected(2 + ratio * 22);
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.alpha(Config.md3.on_surface, 0.12)
                        height: 6
                        radius: 3

                        Rectangle {
                            color: Config.md3.tertiary
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * Math.max(0, Math.min(1, (root.selectedWidth - 2) / 22))
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        border.color: Config.md3.background
                        border.width: 2
                        color: Config.md3.tertiary
                        height: 16
                        radius: 8
                        scale: sliderMouse.pressed ? 1.18 : 1
                        width: 16
                        x: Math.max(0, Math.min(parent.width - width, parent.width * (root.selectedWidth - 2) / 22 - width / 2))

                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }
                    MouseArea {
                        id: sliderMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onPositionChanged: mouse => {
                            if (pressed)
                                widthSlider.updateWidth(mouse.x);
                        }
                        onPressed: mouse => {
                            return widthSlider.updateWidth(mouse.x);
                        }
                    }
                }
            }
            ScreenshotToolButton {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 48
                selectedTool: root.selectedTool
                toolData: {
                    "tool": "eraser",
                    "glyph": "",
                    "iconName": "draw-eraser-symbolic"
                }

                onSelected: tool => {
                    return root.toolSelected(tool);
                }
            }
        }
    }
}
