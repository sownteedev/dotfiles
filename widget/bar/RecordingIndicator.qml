import QtQuick
import QtQuick.Layouts
import "../../"
import "../../service"
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

MouseArea {
    id: root

    readonly property bool activeOnThisScreen: {
        var target = CaptureService.recordingScreenName;
        return target === "" || !parentWindow.screen || parentWindow.screen.name === target;
    }
    property bool dismissing: false
    property bool dragConsumed: false
    required property var parentWindow
    readonly property bool showing: activeOnThisScreen && (CaptureService.recordingStarting || CaptureService.recording || CaptureService.recordingSavedVisible)
    readonly property color stateColor: CaptureService.recording ? Config.md3.error : CaptureService.recordingStarting ? Config.md3.tertiary : Config.md3.secondary
    property real swipeOffset: 0

    clip: true
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    implicitHeight: 30
    implicitWidth: showing ? indicatorRow.implicitWidth + 20 : 0
    visible: implicitWidth > 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on swipeOffset {
        enabled: !savedSwipe.active

        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    onClicked: {
        if (dragConsumed || Math.abs(swipeOffset) > 3 || dismissing)
            return;
        if (CaptureService.recording || CaptureService.recordingStarting)
            CaptureService.stopRecording();
        else
            CaptureService.openRecording();
    }
    onPressed: dragConsumed = false
    onShowingChanged: {
        if (!showing) {
            swipeOffset = 0;
            dismissing = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Config.alpha(Config.md3.error, 0.18)
        radius: 10
        visible: CaptureService.recordingSavedVisible && !CaptureService.recording && root.swipeOffset < 0

        IconImage {
            anchors.centerIn: parent
            height: 14
            layer.enabled: true
            source: Quickshell.iconPath("user-trash-symbolic")
            width: 14

            layer.effect: ColorOverlay {
                color: Config.md3.error
            }
        }
    }
    Item {
        id: indicatorContent

        anchors.bottom: parent.bottom
        anchors.top: parent.top
        opacity: Math.max(0, 1 - Math.abs(root.swipeOffset) / Math.max(1, root.width))
        width: parent.width
        x: root.swipeOffset

        Rectangle {
            anchors.fill: parent
            border.color: Config.alpha(root.stateColor, 0.36)
            border.width: 1
            color: Config.alpha(root.stateColor, root.containsMouse ? 0.22 : 0.13)
            radius: 10

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
        RowLayout {
            id: indicatorRow

            anchors.centerIn: parent
            spacing: 7

            Item {
                Layout.preferredHeight: 12
                Layout.preferredWidth: 12

                Rectangle {
                    anchors.centerIn: parent
                    color: root.stateColor
                    height: 8
                    radius: 4
                    width: 8
                }
                Rectangle {
                    anchors.centerIn: parent
                    border.color: root.stateColor
                    border.width: 1
                    color: "transparent"
                    height: 8
                    radius: 4
                    visible: CaptureService.recording
                    width: 8

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: CaptureService.recording

                        NumberAnimation {
                            duration: 750
                            from: 0.8
                            to: 0
                        }
                        PauseAnimation {
                            duration: 120
                        }
                    }
                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: CaptureService.recording

                        NumberAnimation {
                            duration: 750
                            easing.type: Easing.OutCubic
                            from: 1
                            to: 1.8
                        }
                        PauseAnimation {
                            duration: 120
                        }
                    }
                }
            }
            Text {
                color: root.stateColor
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.ExtraBold
                text: CaptureService.recording ? "REC" : CaptureService.recordingStarting ? (CaptureService.recordingCountdownRemaining > 0 ? qsTr("REC in %1").arg(CaptureService.recordingCountdownRemaining) : qsTr("Starting")) : qsTr("Saved")
            }
            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.features: {
                    "tnum": 1
                }
                font.pixelSize: 12
                font.weight: Font.DemiBold
                text: CaptureService.recordingElapsedText
                visible: CaptureService.recording
            }
            Rectangle {
                Layout.preferredHeight: 15
                Layout.preferredWidth: 15
                color: Config.alpha(root.stateColor, 0.20)
                radius: 5
                visible: CaptureService.recording || CaptureService.recordingStarting

                Rectangle {
                    anchors.centerIn: parent
                    color: root.stateColor
                    height: 6
                    radius: 1
                    width: 6
                }
            }
        }
    }
    DragHandler {
        id: savedSwipe

        enabled: CaptureService.recordingSavedVisible && !CaptureService.recording && !root.dismissing
        target: null
        xAxis.enabled: true
        xAxis.maximum: 0
        xAxis.minimum: -root.width
        yAxis.enabled: false

        onActiveChanged: {
            if (active)
                return;
            if (root.swipeOffset < -root.width * 0.34) {
                root.dismissing = true;
                root.swipeOffset = -root.width - 24;
                deleteTimer.restart();
            } else {
                root.swipeOffset = 0;
            }
        }
        onTranslationChanged: {
            root.swipeOffset = Math.min(0, translation.x);
            if (Math.abs(translation.x) > 4)
                root.dragConsumed = true;
        }
    }
    Timer {
        id: deleteTimer

        interval: 170
        repeat: false

        onTriggered: CaptureService.trashRecording()
    }
}
