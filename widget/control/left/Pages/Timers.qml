import QtQuick
import QtQuick.Layouts
import "../../../../"
import "../../../../service"
import "../../../../components"

Item {
    id: root

    readonly property real contentSpacing: 11 + 4 * layoutProgress
    readonly property real controlsHeight: 50
    readonly property point dialCenter: {
        timerFlickable.contentY;
        timerContent.x;
        timerContent.y;
        countdownDial.x;
        countdownDial.y;
        return countdownDial.mapToItem(root, countdownDial.width / 2, countdownDial.height / 2);
    }
    readonly property real dialMinimumSize: 176 + 36 * layoutProgress
    readonly property real dialSize: Responsive.clamp(Math.min(width - 64, height - reservedHeight), dialMinimumSize, 300)
    readonly property real layoutProgress: Responsive.clamp((height - 430) / 120, 0, 1)
    readonly property real pagePadding: 8
    readonly property real pickerHeight: 122 + 6 * layoutProgress
    readonly property real reservedHeight: pagePadding * 2 + contentSpacing * 2 + controlsHeight + pickerHeight

    anchors.fill: parent

    Flickable {
        id: timerFlickable

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: contentHeight > height + 1
        contentHeight: Math.max(height, timerContent.implicitHeight + root.pagePadding * 2)
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height + 1

        ColumnLayout {
            id: timerContent

            spacing: root.contentSpacing
            width: parent.width - root.pagePadding * 2
            x: root.pagePadding
            y: timerFlickable.interactive ? root.pagePadding : Math.max(root.pagePadding, (timerFlickable.height - implicitHeight) / 2)

            CountdownDial {
                id: countdownDial

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: root.dialSize
                Layout.preferredWidth: root.dialSize
                completed: CountdownService.completed
                hasStarted: CountdownService.hasStarted
                preparationProgress: CountdownService.preparationProgress
                preparing: CountdownService.preparing
                progress: CountdownService.progress
                remainingMilliseconds: CountdownService.remainingMilliseconds
                running: CountdownService.running
                totalMilliseconds: CountdownService.totalMilliseconds
            }
            CountdownControls {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: root.controlsHeight
                Layout.preferredWidth: 244
                completed: CountdownService.completed
                hasStarted: CountdownService.hasStarted
                preparing: CountdownService.preparing
                running: CountdownService.running

                onResetRequested: CountdownService.reset()
                onToggleRequested: CountdownService.toggle()
            }
            TimerDurationPicker {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: root.pickerHeight
                Layout.preferredWidth: Math.min(470, root.width - 36)
                interactive: !CountdownService.running && !CountdownService.preparing
                scrollingEnabled: !timerFlickable.interactive || timerFlickable.atYEnd
                totalSeconds: Math.round(CountdownService.totalMilliseconds / 1000)

                onDurationSelected: seconds => CountdownService.setDuration(Math.max(1, seconds))
            }
        }
    }
}
