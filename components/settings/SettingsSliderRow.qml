import "../../"
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property real from: 0
    property string label: ""
    property string note: ""
    property real stepSize: 0.01
    property real to: 1
    property real value: 0
    property string valueText: ""

    signal edited(real value)

    Accessible.description: note
    Accessible.name: label
    Accessible.role: Accessible.Slider
    Layout.fillWidth: true
    color: "transparent"
    implicitHeight: note === "" ? 72 : 86
    opacity: enabled ? 1 : 0.45
    radius: 11

    Behavior on opacity {
        OpacityAnimator {
            duration: Config.animationDuration(120)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: root.label
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.46)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.note
                    visible: text !== ""
                }
            }
            Rectangle {
                color: Config.alpha(root.accentColor, 0.13)
                implicitHeight: 30
                implicitWidth: valueLabel.implicitWidth + 18
                radius: 9

                Text {
                    id: valueLabel

                    anchors.centerIn: parent
                    color: root.accentColor
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    text: root.valueText
                }
            }
        }
        Controls.Slider {
            id: slider

            Accessible.name: root.label
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            from: root.from
            live: true
            snapMode: Controls.Slider.SnapAlways
            stepSize: root.stepSize
            to: root.to
            value: root.value

            background: Rectangle {
                color: Config.alpha(Config.md3.on_surface, 0.11)
                height: 6
                radius: height / 2
                width: slider.availableWidth
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2

                Rectangle {
                    color: root.accentColor
                    height: parent.height
                    radius: parent.radius
                    width: slider.visualPosition * parent.width
                }
            }
            handle: Rectangle {
                border.color: Config.alpha(Config.md3.surface, 0.7)
                border.width: 2
                color: root.accentColor
                implicitHeight: slider.pressed ? 20 : 18
                implicitWidth: implicitHeight
                radius: width / 2
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Config.animationDuration(100)
                    }
                }
            }

            onMoved: root.edited(value)
        }
    }
}
