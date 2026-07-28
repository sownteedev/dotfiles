import QtQuick
import QtQuick.Layouts
import "../../../../"
import "../../../../service"
import "../../../../components"

Item {
    id: root

    readonly property real dialSize: Math.min(400, Math.max(270, Math.min(width - 56, height - 246)))

    anchors.fill: parent

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        CountdownDial {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: root.dialSize
            Layout.preferredWidth: root.dialSize
            completed: CountdownService.completed
            hasStarted: CountdownService.hasStarted
            progress: CountdownService.progress
            remainingMilliseconds: CountdownService.remainingMilliseconds
            running: CountdownService.running
            totalMilliseconds: CountdownService.totalMilliseconds
        }
        CountdownControls {
            Layout.alignment: Qt.AlignHCenter
            completed: CountdownService.completed
            hasStarted: CountdownService.hasStarted
            running: CountdownService.running

            onResetRequested: CountdownService.reset()
            onToggleRequested: CountdownService.toggle()
        }
        TimerDurationPicker {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 150
            Layout.preferredWidth: Math.min(480, root.width - 36)
            interactive: !CountdownService.running
            totalSeconds: Math.round(CountdownService.totalMilliseconds / 1000)

            onDurationSelected: seconds => CountdownService.setDuration(Math.max(1, seconds))
        }
    }
}
