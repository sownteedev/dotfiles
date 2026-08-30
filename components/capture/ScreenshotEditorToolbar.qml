import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property real availableWidth: 946
    property bool opacityAvailable: false
    property bool reverseSearchBusy: false
    property color selectedColor: "#ff3b30"
    property real selectedOpacity: 1
    property string selectedTool: "pen"
    property real selectedWidth: 6

    signal colorSelected(color colorValue)
    signal opacityChangeFinished
    signal opacityChangeStarted
    signal opacitySelected(real opacityValue)
    signal reverseSearchRequested
    signal toolSelected(string tool)
    signal widthSelected(real widthValue)

    border.color: Config.alpha(Config.md3.on_surface, 0.1)
    border.width: 1
    color: Config.alpha(Config.md3.background, 0.94)
    implicitHeight: contentLayout.implicitHeight + 24
    implicitWidth: Math.min(946, Math.max(884, availableWidth))
    radius: 20

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            id: toolRow

            Layout.fillWidth: true
            spacing: 7

            Repeater {
                model: [
                    {
                        "tool": "select",
                        "description": qsTr("Move layers. Drag an image edge to crop, a corner to resize, or the top handle to rotate."),
                        "glyph": "",
                        "iconName": "screenshot-ui-show-pointer-symbolic",
                        "iconSize": 22,
                        "label": qsTr("Select and move"),
                        "shortcut": qsTr("Shift: snap rotation")
                    },
                    {
                        "tool": "pen",
                        "description": qsTr("Draw freehand strokes."),
                        "fontSize": 24,
                        "fontWeight": Font.Black,
                        "glyph": "✎",
                        "iconScale": 1.18,
                        "label": qsTr("Pen")
                    },
                    {
                        "tool": "highlight",
                        "description": qsTr("Draw a translucent highlight."),
                        "fontSize": 24,
                        "fontWeight": Font.Black,
                        "glyph": "▰",
                        "iconScale": 1.22,
                        "label": qsTr("Highlighter")
                    },
                    {
                        "tool": "line",
                        "customIcon": "straight-line",
                        "description": qsTr("Draw a straight line."),
                        "label": qsTr("Line")
                    },
                    {
                        "tool": "arrow",
                        "description": qsTr("Draw an arrow."),
                        "fontSize": 24,
                        "fontWeight": Font.Black,
                        "glyph": "➜",
                        "iconScale": 1.18,
                        "label": qsTr("Arrow")
                    },
                    {
                        "tool": "rectangle",
                        "customIcon": "rectangle-outline",
                        "description": qsTr("Draw a rectangle outline."),
                        "label": qsTr("Rectangle")
                    },
                    {
                        "tool": "ellipse",
                        "customIcon": "ellipse-outline",
                        "description": qsTr("Draw an ellipse outline."),
                        "label": qsTr("Ellipse")
                    },
                    {
                        "tool": "blur",
                        "customIcon": "blur-drop",
                        "description": qsTr("Blur the selected area."),
                        "label": qsTr("Blur")
                    },
                    {
                        "tool": "pixelate",
                        "customIcon": "pixel-grid",
                        "description": qsTr("Pixelate the selected area."),
                        "label": qsTr("Pixelate")
                    },
                    {
                        "tool": "text",
                        "description": qsTr("Insert text into the screenshot."),
                        "fontSize": 22,
                        "fontWeight": Font.Black,
                        "glyph": "T",
                        "label": qsTr("Text")
                    },
                    {
                        "tool": "number",
                        "customIcon": "number-marker",
                        "description": qsTr("Place numbered markers."),
                        "label": qsTr("Number marker")
                    },
                    {
                        "tool": "callout",
                        "customIcon": "zoom-callout",
                        "description": qsTr("Select an area to create a magnified callout."),
                        "label": qsTr("Zoom callout")
                    },
                    {
                        "tool": "loupe",
                        "customIcon": "pixel-loupe",
                        "description": qsTr("Inspect pixels without changing the image. Hold G temporarily and scroll to change zoom."),
                        "label": qsTr("Magnifier"),
                        "shortcut": qsTr("G + wheel")
                    },
                    {
                        "tool": "ocr",
                        "customIcon": "ocr-scan",
                        "description": qsTr("Drag over text to recognize and copy it."),
                        "label": qsTr("Copy text with OCR")
                    },
                    {
                        "tool": "crop",
                        "description": qsTr("Drag over the area you want to keep."),
                        "iconName": "image-crop-symbolic",
                        "label": qsTr("Crop")
                    },
                    {
                        "tool": "google-lens",
                        "action": "reverse-search",
                        "description": qsTr("Search the edited screenshot with Google Lens."),
                        "googleLens": true,
                        "label": qsTr("Google Lens")
                    },
                    {
                        "tool": "eraser",
                        "description": qsTr("Remove annotations or inserted images."),
                        "glyph": "",
                        "iconName": "draw-eraser-symbolic",
                        "label": qsTr("Eraser"),
                        "tone": "error"
                    }
                ]

                delegate: ScreenshotToolButton {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.minimumWidth: 44
                    Layout.preferredHeight: 42
                    Layout.preferredWidth: 48
                    enabled: modelData.action === "reverse-search" ? !root.reverseSearchBusy : true
                    opacity: enabled ? 1 : 0.55
                    selectedTool: root.selectedTool
                    toolData: modelData

                    onSelected: tool => {
                        if (modelData.action === "reverse-search")
                            root.reverseSearchRequested();
                        else
                            root.toolSelected(tool);
                    }
                }
            }
        }
        RowLayout {
            id: settingsRow

            Layout.fillWidth: true
            Layout.maximumHeight: 32
            Layout.minimumHeight: 32
            Layout.preferredHeight: 32
            spacing: 8

            Item {
                Layout.fillWidth: true
            }
            ScreenshotColorSlider {
                Layout.minimumWidth: 220
                Layout.preferredHeight: 32
                Layout.preferredWidth: 280
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
                Layout.minimumWidth: 120
                Layout.preferredHeight: 32
                Layout.preferredWidth: 140
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

                            Behavior on width {
                                enabled: !sliderMouse.pressed

                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }
                            }
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
                        Behavior on x {
                            enabled: !sliderMouse.pressed

                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
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
            Rectangle {
                Layout.leftMargin: 4
                Layout.preferredHeight: 25
                Layout.preferredWidth: 1
                Layout.rightMargin: 4
                color: Config.alpha(Config.md3.on_surface, 0.12)
                visible: root.opacityAvailable && root.selectedTool !== "select"
            }
            ScreenshotOpacitySlider {
                Layout.minimumWidth: 120
                Layout.preferredHeight: 32
                Layout.preferredWidth: 145
                selectedOpacity: root.selectedOpacity
                visible: root.opacityAvailable

                onOpacityChangeFinished: root.opacityChangeFinished()
                onOpacityChangeStarted: root.opacityChangeStarted()
                onOpacitySelected: opacityValue => root.opacitySelected(opacityValue)
            }
            Item {
                Layout.fillWidth: true
            }
        }
    }
}
