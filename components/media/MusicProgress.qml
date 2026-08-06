import "../../"
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property real displayedPosition: 0
    readonly property real duration: rawDuration > 0 && rawDuration < 86400 ? rawDuration : 0
    property var player: null
    readonly property real progress: duration > 0 ? Math.max(0, Math.min(1, displayedPosition / duration)) : 0
    // Some browser MPRIS implementations expose an Int64 sentinel as length.
    // Treat anything above one day as unknown instead of rendering years.
    readonly property real rawDuration: player && player.lengthSupported ? Math.max(0, Number(player.length || 0)) : 0
    readonly property bool seekable: player && player.canSeek && player.positionSupported && duration > 0
    property bool seeking: false

    function formatTime(seconds) {
        var safeSeconds = Math.max(0, Math.floor(Number(seconds) || 0));
        var hours = Math.floor(safeSeconds / 3600);
        var minutes = Math.floor(safeSeconds % 3600 / 60);
        var remainder = safeSeconds % 60;
        if (hours > 0)
            return hours + ":" + (minutes < 10 ? "0" : "") + minutes + ":" + (remainder < 10 ? "0" : "") + remainder;

        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder;
    }
    function syncPosition() {
        if (!seeking)
            displayedPosition = player && player.positionSupported ? Math.max(0, player.position) : 0;
    }

    implicitHeight: 24

    onPlayerChanged: syncPosition()

    Connections {
        function onPositionChanged() {
            root.syncPosition();
        }
        function onPostTrackChanged() {
            root.syncPosition();
        }

        enabled: !!root.player
        target: root.player
    }
    Timer {
        interval: 500
        repeat: true
        running: !!root.player && MediaService.playing && !root.seeking

        onTriggered: root.syncPosition()
    }
    RowLayout {
        anchors.fill: parent
        spacing: 12

        Text {
            Layout.minimumWidth: 40
            color: Config.alpha(Config.md3.on_surface, 0.6)
            font.family: Config.fontName
            font.pixelSize: 12
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            text: root.formatTime(root.displayedPosition)
        }
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            Rectangle {
                id: trackBg

                anchors.verticalCenter: parent.verticalCenter
                color: Config.alpha(Config.md3.on_surface, 0.1)
                height: progressMouse.containsMouse || root.seeking ? 6 : 4
                radius: height / 2
                width: parent.width

                Behavior on height {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
            Rectangle {
                id: trackActive

                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.primary
                height: trackBg.height
                radius: trackBg.radius
                width: parent.width * root.progress
            }
            Rectangle {
                id: thumb

                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.primary
                height: width
                opacity: width > 0 ? 1 : 0
                radius: width / 2
                width: progressMouse.containsMouse || root.seeking ? 12 : 0
                x: Math.max(0, Math.min(parent.width - width, trackActive.width - width / 2))

                Behavior on width {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }
            MouseArea {
                id: progressMouse

                function preview(mouseX) {
                    var realX = Math.max(0, Math.min(width, mouseX));
                    root.displayedPosition = (realX / width) * root.duration;
                }

                anchors.fill: parent
                anchors.margins: -10
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.seekable
                hoverEnabled: true

                onCanceled: {
                    root.seeking = false;
                    root.syncPosition();
                }
                onPositionChanged: mouse => {
                    if (pressed)
                        preview(mouse.x);
                }
                onPressed: mouse => {
                    root.seeking = true;
                    preview(mouse.x);
                }
                onReleased: {
                    if (root.player)
                        root.player.position = root.displayedPosition;
                    root.seeking = false;
                    root.syncPosition();
                }
            }
        }
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 40
            Layout.preferredHeight: 16

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Config.alpha(Config.md3.on_surface, 0.6)
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.DemiBold
                text: root.duration > 0 ? root.formatTime(root.duration) : ""
                visible: root.duration > 0
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.error
                height: 16
                radius: 4
                visible: root.duration <= 0 && !!root.player
                width: liveText.implicitWidth + 10

                Text {
                    id: liveText

                    anchors.centerIn: parent
                    color: Config.md3.on_error
                    font.family: Config.fontName
                    font.pixelSize: 10
                    font.weight: Font.ExtraBold
                    text: "LIVE"
                }
            }
        }
    }
}
