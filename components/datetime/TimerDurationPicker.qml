import QtQuick
import QtQuick.Layouts
import "../../"
import ".."

Item {
    id: root

    readonly property int hours: Math.floor(totalSeconds / 3600)
    property bool interactive: true
    readonly property int minutes: Math.floor((totalSeconds % 3600) / 60)
    readonly property int seconds: totalSeconds % 60
    property int totalSeconds: 300

    signal durationSelected(int seconds)

    implicitHeight: 150
    implicitWidth: 480

    Rectangle {
        anchors.fill: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.06)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, 0.34)
        radius: 22
    }
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: wheelRow.verticalCenter
        border.color: Config.alpha(root.interactive ? Config.md3.primary : Config.md3.on_surface, root.interactive ? 0.19 : 0.07)
        border.width: 1
        color: Config.alpha(root.interactive ? Config.md3.primary : Config.md3.on_surface, root.interactive ? 0.085 : 0.035)
        height: 48
        radius: 15
    }
    RowLayout {
        id: wheelRow

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 12
        spacing: 0

        DurationWheel {
            Layout.fillHeight: true
            Layout.fillWidth: true
            interactive: root.interactive
            maximumValue: 23
            unitLabel: "hours"
            value: root.hours

            onValueSelected: value => root.durationSelected(value * 3600 + root.minutes * 60 + root.seconds)
        }
        DurationWheel {
            Layout.fillHeight: true
            Layout.fillWidth: true
            interactive: root.interactive
            maximumValue: 59
            unitLabel: "min"
            value: root.minutes

            onValueSelected: value => root.durationSelected(root.hours * 3600 + value * 60 + root.seconds)
        }
        DurationWheel {
            Layout.fillHeight: true
            Layout.fillWidth: true
            interactive: root.interactive
            maximumValue: 59
            unitLabel: "sec"
            value: root.seconds

            onValueSelected: value => root.durationSelected(root.hours * 3600 + root.minutes * 60 + value)
        }
    }
    Repeater {
        model: 2

        Rectangle {
            color: Config.alpha(Config.md3.on_surface, 0.075)
            height: 26
            width: 1
            x: Math.round(wheelRow.x + wheelRow.width * (index + 1) / 3)
            y: Math.round(wheelRow.y + wheelRow.height / 2 - height / 2)
        }
    }
}
