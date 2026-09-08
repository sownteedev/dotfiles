import QtQuick
import QtQuick.Layouts
import "../../../../"
import "../../../../service"
import "../../../../components"

Item {
    id: root

    readonly property real activeDialSize: Responsive.clamp(Math.min(width - 24, height - (pagePadding * 2 + contentSpacing + controlsHeight + 20)), dialMinimumSize + 60, 420)
    property real activeProgress: isCountingDown ? 1 : 0
    readonly property real contentSpacing: 14 + 6 * layoutProgress
    readonly property real controlsHeight: 52
    readonly property point dialCenter: {
        timerFlickable.contentY;
        timerContent.x;
        timerContent.y;
        countdownDial.x;
        countdownDial.y;
        return countdownDial.mapToItem(root, countdownDial.width / 2, countdownDial.height / 2);
    }
    readonly property real dialMinimumSize: 200 + 40 * layoutProgress
    readonly property real dialSize: idleDialSize + (activeDialSize - idleDialSize) * activeProgress
    readonly property real idleDialSize: Responsive.clamp(Math.min(width - 32, height - reservedHeight), dialMinimumSize, 350)
    readonly property bool isCountingDown: CountdownService.running || CountdownService.hasStarted || CountdownService.preparing
    readonly property real layoutProgress: Responsive.clamp((height - 430) / 120, 0, 1)
    readonly property real pagePadding: 4
    readonly property real pickerHeight: 140 + 12 * layoutProgress
    readonly property real reservedHeight: pagePadding * 2 + contentSpacing * 2 + controlsHeight + pickerHeight

    anchors.fill: parent

    Behavior on activeProgress {
        NumberAnimation {
            duration: Config.animationDuration(380)
            easing.type: Easing.OutCubic
        }
    }

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

            spacing: 0
            width: parent.width - root.pagePadding * 2
            x: root.pagePadding
            y: Math.max(root.pagePadding, Math.round((timerFlickable.height - implicitHeight) / 2))

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
                Layout.preferredWidth: Math.min(310 + 30 * root.activeProgress, parent.width - 24)
                Layout.topMargin: root.contentSpacing
                completed: CountdownService.completed
                hasStarted: CountdownService.hasStarted
                preparing: CountdownService.preparing
                running: CountdownService.running

                onResetRequested: CountdownService.reset()
                onToggleRequested: CountdownService.toggle()
            }
            Item {
                id: pickerWrapper

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: root.pickerHeight * (1 - root.activeProgress)
                Layout.preferredWidth: Math.min(540, parent.width - 8)
                Layout.topMargin: root.contentSpacing * (1 - root.activeProgress)
                clip: true
                opacity: 1 - root.activeProgress
                visible: root.activeProgress < 0.999

                TimerDurationPicker {
                    anchors.centerIn: parent
                    height: root.pickerHeight
                    interactive: !root.isCountingDown
                    scrollingEnabled: !timerFlickable.interactive || timerFlickable.atYEnd
                    totalSeconds: Math.round(CountdownService.totalMilliseconds / 1000)
                    width: parent.width

                    onDurationSelected: seconds => CountdownService.setDuration(Math.max(1, seconds))
                }
            }
        }
    }
}
