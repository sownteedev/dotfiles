import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

Item {
    id: root

    property var player: null
    readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing

    implicitHeight: 54
    implicitWidth: controls.implicitWidth

    RowLayout {
        id: controls

        anchors.centerIn: parent
        spacing: 10

        MediaButton {
            active: controlEnabled && root.player.shuffle
            controlEnabled: !!root.player && root.player.canControl && root.player.shuffleSupported
            fallbackIcon: "media-playlist-shuffle"
            iconName: "media-playlist-shuffle-symbolic"

            onActivated: root.player.shuffle = !root.player.shuffle
        }
        MediaButton {
            controlEnabled: !!root.player && root.player.canGoPrevious
            fallbackIcon: "media-skip-backward"
            iconName: "media-skip-backward-symbolic"

            onActivated: root.player.previous()
        }
        MediaButton {
            controlEnabled: !!root.player && root.player.canTogglePlaying
            iconName: root.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            primary: true

            onActivated: root.player.togglePlaying()
        }
        MediaButton {
            controlEnabled: !!root.player && root.player.canGoNext
            fallbackIcon: "media-skip-forward"
            iconName: "media-skip-forward-symbolic"

            onActivated: root.player.next()
        }
        MediaButton {
            active: controlEnabled && root.player.loopState !== MprisLoopState.None
            controlEnabled: !!root.player && root.player.canControl && root.player.loopSupported
            fallbackIcon: "media-playlist-repeat"
            iconName: "media-playlist-repeat-symbolic"
            showOneBadge: controlEnabled && root.player.loopState === MprisLoopState.Track

            onActivated: {
                if (root.player.loopState === MprisLoopState.None)
                    root.player.loopState = MprisLoopState.Playlist;
                else if (root.player.loopState === MprisLoopState.Playlist)
                    root.player.loopState = MprisLoopState.Track;
                else
                    root.player.loopState = MprisLoopState.None;
            }
        }
    }

    component MediaButton: Rectangle {
        id: button

        property bool active: false
        property bool controlEnabled: true
        property string fallbackIcon: "media-playback-start-symbolic"
        property string iconName: ""
        property bool primary: false
        property bool showOneBadge: false

        signal activated

        Layout.preferredHeight: primary ? 54 : 40
        Layout.preferredWidth: primary ? 54 : 40
        color: primary ? Config.md3.primary : active ? Config.alpha(Config.md3.primary, 0.18) : buttonMouse.containsMouse && controlEnabled ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
        opacity: controlEnabled ? 1 : 0.3
        radius: width / 2
        scale: buttonMouse.pressed && controlEnabled ? 0.9 : 1

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        IconImage {
            id: controlIcon

            anchors.centerIn: parent
            implicitHeight: implicitWidth
            implicitWidth: button.primary ? 26 : 21
            layer.enabled: true
            source: Quickshell.iconPath(button.iconName, button.fallbackIcon)

            layer.effect: ColorOverlay {
                color: button.primary ? Config.md3.background : button.active ? Config.md3.primary : Config.md3.on_surface
            }
        }
        Rectangle {
            anchors.bottom: controlIcon.bottom
            anchors.bottomMargin: -3
            anchors.right: controlIcon.right
            anchors.rightMargin: -4
            color: Config.md3.primary
            height: 13
            radius: 7
            visible: button.showOneBadge
            width: 13

            Text {
                anchors.centerIn: parent
                color: Config.md3.background
                font.family: Config.fontName
                font.pixelSize: 8
                font.weight: Font.ExtraBold
                text: "1"
            }
        }
        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: button.controlEnabled
            hoverEnabled: true

            onClicked: button.activated()
        }
    }
}
