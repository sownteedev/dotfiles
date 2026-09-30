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
    implicitHeight: Math.max(80, labelBlock.implicitHeight + 31)
    opacity: enabled ? 1 : Md3.state.disabledContent
    radius: Md3.shape.medium

    Behavior on opacity {
        OpacityAnimator {
            duration: Config.animationDuration(Md3.motion.short2)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Md3.spacing.xxs
        anchors.rightMargin: Md3.spacing.xxs
        spacing: Md3.spacing.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            SettingsLabelBlock {
                id: labelBlock

                Layout.fillWidth: true
                headline: root.label
                supportingText: root.note
            }
            Rectangle {
                Layout.alignment: Qt.AlignTop
                color: Config.md3.secondary_container
                implicitHeight: 32
                implicitWidth: valueLabel.implicitWidth + 18
                radius: Md3.shape.full

                Text {
                    id: valueLabel

                    anchors.centerIn: parent
                    color: Config.md3.on_secondary_container
                    font.family: Config.fontName
                    font.pixelSize: Md3.typography.labelMedium
                    font.weight: Font.Medium
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
                color: Config.md3.surface_container_highest
                height: 8
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
                border.color: Config.md3.surface
                border.width: 3
                color: root.accentColor
                implicitHeight: slider.pressed ? 24 : 20
                implicitWidth: implicitHeight
                radius: width / 2
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Config.animationDuration(Md3.motion.short2)
                    }
                }
            }

            onMoved: root.edited(value)
        }
    }
}
