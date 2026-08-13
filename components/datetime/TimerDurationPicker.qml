pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../"
import ".."

Item {
    id: root

    readonly property int hours: Math.floor(totalSeconds / 3600)
    property bool interactive: true
    readonly property int minutes: Math.floor((totalSeconds % 3600) / 60)
    property bool scrollingEnabled: true
    readonly property int seconds: totalSeconds % 60
    property int totalSeconds: 300
    readonly property real visualScale: Responsive.clamp(height / Math.max(1, implicitHeight), 0.82, 1)
    readonly property int wheelRowHeight: Math.max(34, Math.round(36 * visualScale))

    signal durationSelected(int seconds)

    implicitHeight: 126
    implicitWidth: 480

    Rectangle {
        anchors.fill: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.065)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, 0.3)
        radius: Math.round(16 * root.visualScale)
    }
    Rectangle {
        id: wheelPanel

        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(9 * root.visualScale)
        anchors.left: parent.left
        anchors.leftMargin: Math.round(10 * root.visualScale)
        anchors.right: parent.right
        anchors.rightMargin: Math.round(10 * root.visualScale)
        anchors.top: parent.top
        anchors.topMargin: Math.round(9 * root.visualScale)
        border.color: Config.alpha(root.interactive ? Config.md3.primary : Config.md3.on_surface, root.interactive ? 0.13 : 0.055)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container_high, 0.32)
        radius: Math.round(14 * root.visualScale)

        Repeater {
            model: 3

            delegate: Rectangle {
                required property int index

                border.color: Config.alpha(root.interactive ? Config.md3.primary : Config.md3.on_surface, root.interactive ? 0.2 : 0.065)
                border.width: 1
                color: Config.alpha(root.interactive ? Config.md3.primary : Config.md3.on_surface, root.interactive ? 0.075 : 0.025)
                height: Math.max(38, Math.round(42 * root.visualScale))
                radius: Math.round(11 * root.visualScale)
                width: wheelRow.width / 3 - Math.round(8 * root.visualScale)
                x: wheelRow.x + wheelRow.width * index / 3 + Math.round(4 * root.visualScale)
                y: wheelRow.y + wheelRow.height / 2 - height / 2

                Behavior on border.color {
                    ColorAnimation {
                        duration: 140
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }
            }
        }
        RowLayout {
            id: wheelRow

            anchors.fill: parent
            anchors.leftMargin: Math.round(8 * root.visualScale)
            anchors.rightMargin: Math.round(8 * root.visualScale)
            spacing: 0

            DurationWheel {
                Layout.fillHeight: true
                Layout.fillWidth: true
                interactive: root.interactive
                maximumValue: 23
                rowHeight: root.wheelRowHeight
                scrollingEnabled: root.scrollingEnabled
                unitLabel: qsTr("hr")
                value: root.hours

                onValueSelected: value => root.durationSelected(value * 3600 + root.minutes * 60 + root.seconds)
            }
            DurationWheel {
                Layout.fillHeight: true
                Layout.fillWidth: true
                interactive: root.interactive
                maximumValue: 59
                rowHeight: root.wheelRowHeight
                scrollingEnabled: root.scrollingEnabled
                unitLabel: qsTr("min")
                value: root.minutes

                onValueSelected: value => root.durationSelected(root.hours * 3600 + value * 60 + root.seconds)
            }
            DurationWheel {
                Layout.fillHeight: true
                Layout.fillWidth: true
                interactive: root.interactive
                maximumValue: 59
                rowHeight: root.wheelRowHeight
                scrollingEnabled: root.scrollingEnabled
                unitLabel: qsTr("sec")
                value: root.seconds

                onValueSelected: value => root.durationSelected(root.hours * 3600 + root.minutes * 60 + value)
            }
        }
        Repeater {
            model: 2

            delegate: Rectangle {
                required property int index

                color: Config.alpha(Config.md3.on_surface, 0.055)
                height: Math.max(24, Math.round(28 * root.visualScale))
                width: 1
                x: Math.round(wheelRow.x + wheelRow.width * (index + 1) / 3)
                y: Math.round(wheelRow.y + wheelRow.height / 2 - height / 2)
            }
        }
    }
}
