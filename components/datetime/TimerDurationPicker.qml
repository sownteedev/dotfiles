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

    implicitHeight: 128
    implicitWidth: 480

    Rectangle {
        anchors.fill: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.1)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, 0.62)
        radius: Math.round(18 * root.visualScale)
    }
    Rectangle {
        id: wheelPanel

        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(8 * root.visualScale)
        anchors.left: parent.left
        anchors.leftMargin: Math.round(8 * root.visualScale)
        anchors.right: parent.right
        anchors.rightMargin: Math.round(8 * root.visualScale)
        anchors.top: parent.top
        anchors.topMargin: Math.round(8 * root.visualScale)
        border.color: Config.alpha(Config.md3.on_surface, 0.07)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container_high, 0.48)
        radius: Math.round(15 * root.visualScale)

        Repeater {
            model: 3

            delegate: Rectangle {
                required property int index

                border.color: Config.alpha(root.interactive ? Config.md3.primary : Config.md3.on_surface, root.interactive ? 0.16 : 0.055)
                border.width: 1
                color: root.interactive ? Config.alpha(Config.md3.surface_container_highest, 0.88) : Config.alpha(Config.md3.surface_container_highest, 0.42)
                height: Math.max(38, Math.round(42 * root.visualScale))
                radius: Math.round(12 * root.visualScale)
                width: wheelRow.width / 3 - Math.round(10 * root.visualScale)
                x: wheelRow.x + wheelRow.width * index / 3 + Math.round(5 * root.visualScale)
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
    }
}
