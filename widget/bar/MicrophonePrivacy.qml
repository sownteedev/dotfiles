import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

MouseArea {
    id: root

    required property var parentWindow

    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    implicitHeight: 30
    implicitWidth: 26
    visible: AudioService.microphoneInUse

    onClicked: {
        if (popupLoader.active)
            popupLoader.active = false;
        else if (popupLoader.loading)
            popupLoader.loading = false;
        else
            popupLoader.loading = true;
    }
    onVisibleChanged: {
        if (!visible) {
            if (popupLoader.active)
                popupLoader.active = false;
            else if (popupLoader.loading)
                popupLoader.loading = false;
        }
    }

    Item {
        anchors.centerIn: parent
        height: 24
        scale: root.containsMouse ? 1.08 : 1
        width: 24

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        IconImage {
            id: microphoneIcon

            anchors.centerIn: parent
            height: 20
            source: Quickshell.iconPath("audio-input-microphone-symbolic")
            visible: false
            width: 20
        }
        ColorOverlay {
            anchors.fill: microphoneIcon
            color: Config.md3.tertiary
            source: microphoneIcon
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            border.color: Config.md3.background
            border.width: 1
            color: Config.md3.error
            height: 6
            radius: 3
            width: 6
        }
    }
    LazyLoader {
        id: popupLoader

        active: false

        PopupWindow {
            id: microphonePopup

            readonly property real desiredHeight: popupColumn.implicitHeight + 38 + shadowPadding * 2
            readonly property real screenHeight: root.parentWindow && root.parentWindow.screen ? root.parentWindow.screen.height : 720
            readonly property real shadowPadding: Math.min(24, Math.ceil(Math.max(8, Config.shellComponentShadowBlur + Math.max(Math.abs(Config.shellComponentShadowOffsetX), Math.abs(Config.shellComponentShadowOffsetY)) + Math.max(0, Config.shellComponentShadowSpread) + 2)))

            anchor.edges: Edges.Bottom | Edges.Left
            anchor.item: root
            anchor.margins.left: -28 - shadowPadding
            anchor.margins.top: 36 - shadowPadding
            color: "transparent"
            grabFocus: true
            implicitHeight: Responsive.fit(desiredHeight, screenHeight - 70, 180)
            implicitWidth: Math.min(268 + shadowPadding * 2, Math.max(0, root.parentWindow && root.parentWindow.screen ? root.parentWindow.screen.width - 16 : 268 + shadowPadding * 2))
            visible: true

            onVisibleChanged: {
                if (!visible)
                    popupLoader.active = false;
            }

            ShellShadow {
                componentShadow: true
                cornerRadius: popupCard.radius
                target: popupCard
            }
            Rectangle {
                id: popupCard

                anchors.bottom: parent.bottom
                anchors.bottomMargin: microphonePopup.shadowPadding
                anchors.left: parent.left
                anchors.leftMargin: microphonePopup.shadowPadding
                anchors.right: parent.right
                anchors.rightMargin: microphonePopup.shadowPadding
                anchors.top: parent.top
                anchors.topMargin: microphonePopup.shadowPadding + 10
                border.color: Config.alpha(Config.md3.tertiary, 0.32)
                border.width: 1
                color: Config.md3.surface_container
                radius: 16

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 14
                    boundsBehavior: Flickable.StopAtBounds
                    clip: contentHeight > height
                    contentHeight: popupColumn.implicitHeight
                    contentWidth: width
                    flickableDirection: Flickable.VerticalFlick
                    interactive: contentHeight > height

                    ColumnLayout {
                        id: popupColumn

                        spacing: 10
                        width: parent.width

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                color: Config.alpha(Config.md3.tertiary, 0.14)
                                height: 36
                                radius: 12
                                width: 36

                                IconImage {
                                    id: headerMicIcon

                                    anchors.centerIn: parent
                                    height: 21
                                    source: Quickshell.iconPath("audio-input-microphone-symbolic")
                                    visible: false
                                    width: 21
                                }
                                ColorOverlay {
                                    anchors.fill: headerMicIcon
                                    color: Config.md3.tertiary
                                    source: headerMicIcon
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                text: "Microphone in use"
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.08)
                            height: 1
                        }
                        Repeater {
                            model: AudioService.microphoneApps

                            delegate: Rectangle {
                                id: appCard

                                required property var modelData
                                readonly property bool streamAvailable: streamNode && streamNode.audio
                                readonly property real streamGain: streamAvailable ? streamNode.audio.volume : 0
                                readonly property bool streamMuted: streamAvailable ? streamNode.audio.muted : true
                                readonly property var streamNode: modelData ? modelData.node : null
                                readonly property real streamPeak: Math.max(0, Math.min(1, peakMonitor.peak))

                                Layout.fillWidth: true
                                Layout.preferredHeight: 68
                                color: Config.md3.surface
                                opacity: streamAvailable ? 1 : 0.55
                                radius: 10

                                PwNodePeakMonitor {
                                    id: peakMonitor

                                    enabled: microphonePopup.visible && appCard.streamAvailable && !appCard.streamMuted
                                    node: appCard.streamNode
                                }
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 9

                                        Rectangle {
                                            Layout.preferredHeight: 28
                                            Layout.preferredWidth: 28
                                            color: Config.md3.surface_container_high
                                            radius: 8

                                            IconImage {
                                                anchors.centerIn: parent
                                                height: 18
                                                source: Quickshell.iconPath(appCard.modelData.icon || "audio-input-microphone-symbolic")
                                                width: 18
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            color: Config.md3.on_surface
                                            elide: Text.ElideRight
                                            font.family: Config.fontName
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            text: appCard.modelData.name
                                        }
                                        Rectangle {
                                            Layout.preferredHeight: 27
                                            Layout.preferredWidth: 27
                                            color: Config.alpha(appCard.streamMuted ? Config.md3.error : Config.md3.on_surface, streamMuteMouse.containsMouse ? 0.18 : 0.08)
                                            radius: 8

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 130
                                                }
                                            }

                                            IconImage {
                                                id: streamMuteIcon

                                                anchors.centerIn: parent
                                                height: 15
                                                source: Quickshell.iconPath(appCard.streamMuted ? "microphone-sensitivity-muted-symbolic" : "microphone-sensitivity-high-symbolic")
                                                visible: false
                                                width: 15
                                            }
                                            ColorOverlay {
                                                anchors.fill: streamMuteIcon
                                                color: appCard.streamMuted ? Config.md3.error : Config.md3.on_surface_variant
                                                source: streamMuteIcon
                                            }
                                            MouseArea {
                                                id: streamMuteMouse

                                                anchors.fill: parent
                                                cursorShape: appCard.streamAvailable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                enabled: appCard.streamAvailable
                                                hoverEnabled: true

                                                onClicked: appCard.streamNode.audio.muted = !appCard.streamNode.audio.muted
                                            }
                                        }
                                    }
                                    CustomVolumeSlider {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 16
                                        highlightColor: Config.md3.tertiary
                                        isMuted: appCard.streamMuted
                                        peakColor: appCard.streamPeak > 0.88 ? Config.md3.error : appCard.streamPeak > 0.68 ? Config.md3.tertiary : Config.md3.secondary
                                        peakValue: appCard.streamPeak
                                        showPeak: true
                                        value: appCard.streamGain

                                        onSliderMoved: value => {
                                            if (appCard.streamAvailable)
                                                appCard.streamNode.audio.volume = value;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                border.color: Config.alpha(Config.md3.tertiary, 0.32)
                border.width: 1
                color: Config.md3.surface_container
                height: 12
                rotation: 45
                width: 12
                x: popupCard.x + 40 - width / 2
                y: popupCard.y - height / 2
            }
            Rectangle {
                color: Config.md3.surface_container
                height: 6
                width: 20
                x: popupCard.x + 40 - width / 2
                y: popupCard.y
            }
        }
    }
}
