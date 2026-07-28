import "../../../../"
import "../../../../components"
import "../../../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../../../../components/common"

Item {
    id: root

    readonly property real artworkSize: Math.max(100, Math.min(280, playerArea.height - 290))
    property bool isSwipingOut: false
    readonly property var player: MediaService.activePlayer
    property int swipeDirection: 1
    property real swipeOffset: 0
    property bool swipeTimerRunning: swipeActionTimer.running

    anchors.fill: parent

    Behavior on swipeOffset {
        enabled: !musicDrag.active && !root.isSwipingOut

        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: swipeActionTimer

        interval: 150

        onTriggered: {
            root.isSwipingOut = true;
            if (root.swipeDirection === 1) {
                MediaService.selectPrevPlayer();
            } else {
                MediaService.selectNextPlayer();
            }
            root.swipeOffset = -root.swipeDirection * root.width;
            swipeInTimer.start();
        }
    }
    Timer {
        id: swipeInTimer

        interval: 20

        onTriggered: {
            root.isSwipingOut = false;
            root.swipeOffset = 0;
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            id: playerArea

            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true // Ensure waves don't overflow the rounded corners

            color: "transparent"
            radius: 18

            // Background Animated Waves & Bubbles
            AnimatedWaves {
                anchors.fill: parent
                color: Config.md3.primary
                running: !!root.player && MediaService.playing
            }
            AnimatedBubbles {
                anchors.fill: parent
                color: Config.md3.primary
                running: !!root.player && MediaService.playing
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                visible: !!root.player

                // Center: Vinyl Artwork with Swipe Gesture
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: root.artworkSize
                    Layout.preferredWidth: root.artworkSize

                    transform: Translate {
                        x: root.swipeOffset
                    }

                    MusicArtwork {
                        anchors.fill: parent
                        player: root.player
                    }
                    DragHandler {
                        id: musicDrag

                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false

                        onActiveChanged: {
                            if (!active && !root.isSwipingOut && !root.swipeTimerRunning) {
                                if (root.swipeOffset < -50) {
                                    root.swipeOffset = -root.width;
                                    root.swipeDirection = -1;
                                    swipeActionTimer.start();
                                } else if (root.swipeOffset > 50) {
                                    root.swipeOffset = root.width;
                                    root.swipeDirection = 1;
                                    swipeActionTimer.start();
                                } else {
                                    root.swipeOffset = 0;
                                }
                            }
                        }
                        onTranslationChanged: {
                            if (!root.isSwipingOut) {
                                root.swipeOffset = translation.x;
                            }
                        }
                    }
                }

                // Title and Artist
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                        text: MediaService.title
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.primary
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                        text: MediaService.artist
                    }
                }

                // Progress Bar
                MusicProgress {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    player: root.player
                }

                // Playback Controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15

                    // Shuffle
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        color: shuffleMouse.containsMouse && root.player && root.player.canControl && root.player.shuffleSupported ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        opacity: root.player && root.player.canControl && root.player.shuffleSupported ? 1 : 0.3
                        radius: 18

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("media-playlist-shuffle-symbolic", "media-playlist-shuffle")

                            layer.effect: ColorOverlay {
                                color: root.player && root.player.shuffle ? Config.md3.primary : Config.md3.on_surface
                            }
                        }
                        MouseArea {
                            id: shuffleMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canControl && root.player.shuffleSupported
                            hoverEnabled: true

                            onClicked: root.player.shuffle = !root.player.shuffle
                        }
                    }

                    // Prev
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        color: prevMouse.containsMouse && root.player && root.player.canGoPrevious ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        opacity: root.player && root.player.canGoPrevious ? 1 : 0.3
                        radius: 18

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("media-skip-backward-symbolic", "media-skip-backward")

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface
                            }
                        }
                        MouseArea {
                            id: prevMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canGoPrevious
                            hoverEnabled: true

                            onClicked: root.player.previous()
                        }
                    }

                    // Play/Pause
                    Rectangle {
                        Layout.preferredHeight: 48
                        Layout.preferredWidth: 48
                        color: root.player && MediaService.playing ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.12)
                        radius: 24

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 22
                            implicitWidth: 22
                            layer.enabled: true
                            source: Quickshell.iconPath(root.player && MediaService.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic", "media-playback-start")

                            layer.effect: ColorOverlay {
                                color: root.player && MediaService.playing ? Config.md3.on_primary : Config.md3.on_surface
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canTogglePlaying

                            onClicked: root.player.togglePlaying()
                        }
                    }

                    // Next
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        color: nextMouse.containsMouse && root.player && root.player.canGoNext ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        opacity: root.player && root.player.canGoNext ? 1 : 0.3
                        radius: 18

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("media-skip-forward-symbolic", "media-skip-forward")

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface
                            }
                        }
                        MouseArea {
                            id: nextMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canGoNext
                            hoverEnabled: true

                            onClicked: root.player.next()
                        }
                    }

                    // Loop
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        color: loopMouse.containsMouse && root.player && root.player.canControl && root.player.loopSupported ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        opacity: root.player && root.player.canControl && root.player.loopSupported ? 1 : 0.3
                        radius: 18

                        IconImage {
                            id: loopIcon

                            anchors.centerIn: parent
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("media-playlist-repeat-symbolic", "media-playlist-repeat")

                            layer.effect: ColorOverlay {
                                color: root.player && root.player.loopState !== MprisLoopState.None ? Config.md3.primary : Config.md3.on_surface
                            }
                        }
                        Rectangle {
                            anchors.bottom: loopIcon.bottom
                            anchors.bottomMargin: -2
                            anchors.right: loopIcon.right
                            anchors.rightMargin: -2
                            color: Config.md3.primary
                            height: 10
                            radius: 5
                            visible: root.player && root.player.loopState === MprisLoopState.Track
                            width: 10

                            Text {
                                anchors.centerIn: parent
                                color: Config.md3.background
                                font.family: Config.fontName
                                font.pixelSize: 7
                                font.weight: Font.ExtraBold
                                text: "1"
                            }
                        }
                        MouseArea {
                            id: loopMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canControl && root.player.loopSupported
                            hoverEnabled: true

                            onClicked: {
                                if (root.player.loopState === MprisLoopState.None)
                                    root.player.loopState = MprisLoopState.Playlist;
                                else if (root.player.loopState === MprisLoopState.Playlist)
                                    root.player.loopState = MprisLoopState.Track;
                                else
                                    root.player.loopState = MprisLoopState.None;
                            }
                        }
                    }
                }

                // Bottom: 3-line Lyrics
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 115
                    border.color: Config.alpha(Config.md3.on_surface, 0.04)
                    border.width: 1
                    color: Config.alpha(Config.md3.on_surface, 0.02)
                    radius: 12
                    visible: !!root.player

                    MusicLyrics {
                        anchors.fill: parent
                        anchors.margins: 8
                        player: root.player
                    }
                }
                Item {
                    Layout.fillHeight: true
                } // Bottom spacer to push everything up
            }

            // Nothing Playing State
            Column {
                anchors.centerIn: parent
                spacing: 15
                visible: !root.player

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Config.alpha(Config.md3.on_surface, 0.055)
                    height: 96
                    radius: 48
                    width: 96

                    IconImage {
                        anchors.centerIn: parent
                        implicitHeight: 48
                        implicitWidth: 48
                        layer.enabled: true
                        source: Quickshell.iconPath("multimedia-audio-player-symbolic")

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface_variant
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    text: "Nothing playing"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    text: "Start media in an MPRIS-compatible app"
                }
            }
        }
    }
}
