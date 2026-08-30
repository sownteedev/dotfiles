import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"
import ".."

Rectangle {
    id: root

    readonly property string customIcon: String(toolData.customIcon || "")
    readonly property bool errorTone: String(toolData.tone || "") === "error"
    readonly property color foregroundColor: errorTone ? (toolActive ? Config.md3.on_error_container : Config.md3.error) : toolActive ? Config.md3.background : Config.md3.on_surface
    readonly property real iconExtent: Math.max(16, Math.min(22, Number(toolData.iconSize || 22)))
    required property string selectedTool
    readonly property bool toolActive: selectedTool === toolData.tool
    required property var toolData
    readonly property string toolDescription: String(toolData.description || "")
    readonly property string toolLabel: String(toolData.label || toolData.tool || "")
    readonly property string toolShortcut: String(toolData.shortcut || "")

    signal selected(string tool)

    Accessible.description: toolDescription
    Accessible.name: toolLabel
    Accessible.role: Accessible.Button
    color: errorTone ? (toolActive || pointer.pressed ? Config.md3.error_container : pointer.containsMouse ? Config.alpha(Config.md3.error_container, 0.82) : Config.alpha(Config.md3.error_container, 0.52)) : toolActive ? Config.md3.tertiary : pointer.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container
    implicitHeight: 42
    implicitWidth: 48
    radius: 11
    scale: pointer.pressed ? 0.85 : 1

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.overshoot: 2.5
            easing.type: Easing.OutBack
        }
    }

    Item {
        id: iconFrame

        anchors.centerIn: parent
        height: 24
        width: 24

        Text {
            anchors.fill: parent
            color: root.foregroundColor
            font.family: Config.fontName
            font.pixelSize: Number(root.toolData.fontSize || 23)
            font.weight: Number(root.toolData.fontWeight || Font.Black)
            fontSizeMode: Text.Fit
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            minimumPixelSize: 8
            renderType: Text.NativeRendering
            scale: Number(root.toolData.iconScale || 1)
            text: root.toolData.glyph || ""
            verticalAlignment: Text.AlignVCenter
            visible: !root.toolData.iconName && !root.toolData.googleLens && root.customIcon === ""

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }
        IconImage {
            anchors.centerIn: parent
            height: root.iconExtent
            layer.enabled: visible
            source: visible ? Quickshell.iconPath(root.toolData.iconName, "edit-clear-symbolic") : ""
            visible: !!root.toolData.iconName && !root.toolData.googleLens && root.customIcon === ""
            width: root.iconExtent

            layer.effect: ColorOverlay {
                color: root.foregroundColor

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
        }
        Item {
            anchors.centerIn: parent
            height: 22
            scale: root.iconExtent / 22
            visible: Boolean(root.toolData.googleLens) && root.customIcon === ""
            width: 22

            Rectangle {
                color: "#4285f4"
                height: 3
                radius: 1.5
                width: 8
                x: 1
                y: 1
            }
            Rectangle {
                color: "#4285f4"
                height: 8
                radius: 1.5
                width: 3
                x: 1
                y: 1
            }
            Rectangle {
                color: "#ea4335"
                height: 3
                radius: 1.5
                width: 8
                x: 13
                y: 1
            }
            Rectangle {
                color: "#ea4335"
                height: 8
                radius: 1.5
                width: 3
                x: 18
                y: 1
            }
            Rectangle {
                color: "#34a853"
                height: 8
                radius: 1.5
                width: 3
                x: 1
                y: 13
            }
            Rectangle {
                color: "#34a853"
                height: 3
                radius: 1.5
                width: 8
                x: 1
                y: 18
            }
            Rectangle {
                color: "#fbbc04"
                height: 7
                radius: 3.5
                width: 7
                x: 7.5
                y: 7.5
            }
            Rectangle {
                color: "#4285f4"
                height: 4
                radius: 2
                width: 4
                x: 16
                y: 16
            }
        }
        Loader {
            active: root.customIcon !== ""
            anchors.fill: parent
            sourceComponent: {
                switch (root.customIcon) {
                case "number-marker":
                    return numberMarkerIcon;
                case "zoom-callout":
                    return zoomCalloutIcon;
                case "pixel-loupe":
                    return pixelLoupeIcon;
                case "ocr-scan":
                    return ocrScanIcon;
                case "straight-line":
                    return straightLineIcon;
                case "rectangle-outline":
                    return rectangleOutlineIcon;
                case "ellipse-outline":
                    return ellipseOutlineIcon;
                case "blur-drop":
                    return blurDropIcon;
                case "pixel-grid":
                    return pixelGridIcon;
                default:
                    return null;
                }
            }
        }
    }
    Component {
        id: straightLineIcon

        Item {
            Rectangle {
                anchors.centerIn: parent
                color: root.foregroundColor
                height: 3
                radius: 1.5
                rotation: -62
                width: 21
            }
        }
    }
    Component {
        id: rectangleOutlineIcon

        Item {
            Rectangle {
                anchors.centerIn: parent
                border.color: root.foregroundColor
                border.width: 2
                color: "transparent"
                height: 16
                radius: 1.5
                width: 20
            }
        }
    }
    Component {
        id: ellipseOutlineIcon

        Item {
            Rectangle {
                anchors.centerIn: parent
                border.color: root.foregroundColor
                border.width: 2
                color: "transparent"
                height: 18
                radius: 10
                width: 20
            }
        }
    }
    Component {
        id: blurDropIcon

        Item {
            Shape {
                anchors.centerIn: parent
                height: 22
                width: 18

                ShapePath {
                    fillColor: root.foregroundColor
                    startX: 9
                    startY: 0
                    strokeColor: "transparent"

                    PathCubic {
                        control1X: 8
                        control1Y: 4
                        control2X: 1
                        control2Y: 10
                        x: 1
                        y: 14
                    }
                    PathCubic {
                        control1X: 1
                        control1Y: 19
                        control2X: 4.5
                        control2Y: 22
                        x: 9
                        y: 22
                    }
                    PathCubic {
                        control1X: 13.5
                        control1Y: 22
                        control2X: 17
                        control2Y: 19
                        x: 17
                        y: 14
                    }
                    PathCubic {
                        control1X: 17
                        control1Y: 10
                        control2X: 10
                        control2Y: 4
                        x: 9
                        y: 0
                    }
                }
            }
        }
    }
    Component {
        id: pixelGridIcon

        Item {
            Grid {
                anchors.centerIn: parent
                columnSpacing: 2
                columns: 3
                rowSpacing: 2

                Repeater {
                    model: 9

                    Rectangle {
                        color: root.foregroundColor
                        height: 5
                        radius: 1
                        width: 5
                    }
                }
            }
        }
    }
    Component {
        id: numberMarkerIcon

        Item {
            Rectangle {
                anchors.centerIn: parent
                border.color: root.foregroundColor
                border.width: 2
                color: "transparent"
                height: 20
                radius: 10
                width: 20
            }
            Text {
                anchors.centerIn: parent
                color: root.foregroundColor
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.Black
                renderType: Text.NativeRendering
                text: "1"
            }
        }
    }
    Component {
        id: zoomCalloutIcon

        Item {
            Rectangle {
                border.color: root.foregroundColor
                border.width: 2
                color: "transparent"
                height: 7
                radius: 2
                width: 7
                x: 1
                y: 16
            }
            Rectangle {
                color: root.foregroundColor
                height: 2
                radius: 1
                rotation: -40
                transformOrigin: Item.Center
                width: 8
                x: 6
                y: 12
            }
            Rectangle {
                border.color: root.foregroundColor
                border.width: 2
                color: "transparent"
                height: 14
                radius: 7
                width: 14
                x: 10
                y: 0

                Text {
                    anchors.centerIn: parent
                    color: root.foregroundColor
                    font.family: Config.fontName
                    font.pixelSize: 7
                    font.weight: Font.Black
                    renderType: Text.NativeRendering
                    text: "2×"
                }
            }
        }
    }
    Component {
        id: pixelLoupeIcon

        Item {
            Rectangle {
                border.color: root.foregroundColor
                border.width: 2
                color: "transparent"
                height: 15
                radius: 7.5
                width: 15
                x: 1
                y: 1
            }
            Grid {
                columnSpacing: 1
                columns: 2
                rowSpacing: 1
                x: 6
                y: 6

                Repeater {
                    model: 4

                    Rectangle {
                        color: root.foregroundColor
                        height: 2.5
                        radius: 0.5
                        width: 2.5
                    }
                }
            }
            Rectangle {
                color: root.foregroundColor
                height: 2.5
                radius: 1.25
                rotation: 45
                transformOrigin: Item.Left
                width: 9
                x: 14
                y: 15
            }
        }
    }
    Component {
        id: ocrScanIcon

        Item {
            Text {
                anchors.centerIn: parent
                color: root.foregroundColor
                font.family: Config.fontName
                font.pixelSize: 9
                font.weight: Font.Black
                renderType: Text.NativeRendering
                text: "Aa"
            }
            Repeater {
                model: [
                    {
                        "height": 2,
                        "width": 7,
                        "x": 1,
                        "y": 2
                    },
                    {
                        "height": 7,
                        "width": 2,
                        "x": 1,
                        "y": 2
                    },
                    {
                        "height": 2,
                        "width": 7,
                        "x": 16,
                        "y": 2
                    },
                    {
                        "height": 7,
                        "width": 2,
                        "x": 21,
                        "y": 2
                    },
                    {
                        "height": 2,
                        "width": 7,
                        "x": 1,
                        "y": 20
                    },
                    {
                        "height": 7,
                        "width": 2,
                        "x": 1,
                        "y": 15
                    },
                    {
                        "height": 2,
                        "width": 7,
                        "x": 16,
                        "y": 20
                    },
                    {
                        "height": 7,
                        "width": 2,
                        "x": 21,
                        "y": 15
                    }
                ]

                Rectangle {
                    required property var modelData

                    color: root.foregroundColor
                    height: modelData.height
                    radius: 1
                    width: modelData.width
                    x: modelData.x
                    y: modelData.y
                }
            }
        }
    }
    MouseArea {
        id: pointer

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true

        onClicked: root.selected(root.toolData.tool)
    }
    ScreenshotToolTip {
        description: root.toolDescription
        shortcut: root.toolShortcut
        title: root.toolLabel
        visible: root.enabled && pointer.containsMouse && root.toolLabel !== ""
        x: (root.width - width) / 2
        y: -height - 9
    }
}
