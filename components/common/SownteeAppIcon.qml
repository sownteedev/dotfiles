import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import "../../"

Item {
    id: root

    readonly property bool branded: kind === "settings" || kind === "calendar"
    property string kind: ""
    property url source: ""

    Accessible.ignored: true
    implicitHeight: 40
    implicitWidth: 40

    IconImage {
        anchors.fill: parent
        mipmap: true
        source: root.branded ? "" : root.source
        visible: !root.branded
    }
    Loader {
        active: root.branded
        anchors.centerIn: parent
        height: 128
        scale: Math.min(root.width, root.height) / 128
        width: 128

        sourceComponent: Item {
            id: artwork

            readonly property bool calendar: root.kind === "calendar"

            Rectangle {
                border.color: Config.md3.outline_variant
                border.width: 2
                color: artwork.calendar ? Config.md3.secondary_container : Config.md3.primary_container
                height: 108
                radius: 30
                width: 108
                x: 8
                y: 8
            }
            Loader {
                active: !artwork.calendar
                anchors.fill: parent

                sourceComponent: Item {
                    Repeater {
                        model: 8

                        Rectangle {
                            required property int index

                            color: Config.md3.on_primary_container
                            height: 24
                            radius: 5
                            width: 16
                            x: 52
                            y: 22

                            transform: Rotation {
                                angle: index * 45
                                origin.x: 8
                                origin.y: 36
                            }
                        }
                    }
                    Rectangle {
                        color: Config.md3.on_primary_container
                        height: 54
                        radius: 27
                        width: 54
                        x: 33
                        y: 31
                    }
                    Rectangle {
                        color: Config.md3.primary_container
                        height: 32
                        radius: 16
                        width: 32
                        x: 44
                        y: 42
                    }
                    Rectangle {
                        color: Config.md3.primary
                        height: 16
                        radius: 8
                        width: 16
                        x: 52
                        y: 50
                    }
                }
            }
            Loader {
                active: artwork.calendar
                anchors.fill: parent

                sourceComponent: Item {
                    Rectangle {
                        color: Config.md3.surface_container_lowest
                        height: 73
                        radius: 15
                        width: 74
                        x: 25
                        y: 27
                    }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Config.md3.primary
                            strokeWidth: -1

                            PathSvg {
                                path: "M40 27 H84 Q99 27 99 42 V49 H25 V42 Q25 27 40 27Z"
                            }
                        }
                        ShapePath {
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            strokeColor: Config.md3.on_primary_container
                            strokeWidth: 6

                            PathSvg {
                                path: "M43 24 V34 M81 24 V34"
                            }
                        }
                    }
                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index

                            color: Config.md3.on_surface
                            height: 11
                            radius: 3
                            width: 11
                            x: 38 + (index % 3) * 18
                            y: index < 3 ? 59 : 77
                        }
                    }
                    Rectangle {
                        color: Config.md3.primary
                        height: 15
                        radius: 5
                        width: 15
                        x: 54
                        y: 75
                    }
                }
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        border.color: Config.md3.surface_container_lowest
        border.width: Math.max(1, Math.round(root.width / 32))
        color: Config.md3.primary
        height: Math.max(11, Math.min(18, root.width * 0.42))
        radius: width / 2
        visible: root.branded
        width: height

        Text {
            anchors.fill: parent
            anchors.verticalCenterOffset: -0.6
            color: Config.md3.on_primary
            font.family: Config.fontName
            font.pixelSize: Math.max(7, Math.round(parent.height * 0.62))
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            text: "S"
            verticalAlignment: Text.AlignVCenter
        }
    }
}
