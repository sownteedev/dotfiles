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

    onClicked: popupLoader.active = !popupLoader.active
    onVisibleChanged: {
        if (!visible)
            popupLoader.active = false;
    }

    Item {
        anchors.centerIn: parent
        height: 24
        width: 24

        Rectangle {
            anchors.centerIn: parent
            color: Config.alpha(Config.md3.tertiary, root.containsMouse ? 0.24 : 0.14)
            height: 26
            radius: 13
            width: 26

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }
        IconImage {
            id: microphoneIcon

            anchors.centerIn: parent
            height: 19
            source: Quickshell.iconPath("microphone-sensitivity-high-symbolic")
            visible: false
            width: 19
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

            readonly property bool inputAvailable: inputNode && inputNode.audio
            readonly property real inputGain: inputAvailable ? inputNode.audio.volume : 0
            readonly property var inputNode: Pipewire.defaultAudioSource

            anchor.edges: Edges.Bottom | Edges.Left
            anchor.item: root
            anchor.margins.left: -34
            anchor.margins.top: 30
            color: "transparent"
            grabFocus: true
            implicitHeight: popupColumn.implicitHeight + 50
            implicitWidth: 320
            visible: true

            onVisibleChanged: {
                if (!visible)
                    popupLoader.active = false;
            }

            PwObjectTracker {
                objects: microphonePopup.inputNode ? [microphonePopup.inputNode] : []
            }
            Rectangle {
                id: popupCard

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 6
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 16
                border.color: Config.alpha(Config.md3.tertiary, 0.32)
                border.width: 1
                color: Config.md3.surface_container
                layer.enabled: true
                radius: 16

                layer.effect: DropShadow {
                    color: "#70000000"
                    horizontalOffset: 0
                    radius: 9
                    samples: 19
                    verticalOffset: 4
                }

                ColumnLayout {
                    id: popupColumn

                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

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
                                source: Quickshell.iconPath("microphone-sensitivity-high-symbolic")
                                visible: false
                                width: 21
                            }
                            ColorOverlay {
                                anchors.fill: headerMicIcon
                                color: Config.md3.tertiary
                                source: headerMicIcon
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                text: "Microphone in use"
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface_variant
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 13
                                text: AudioService.microphoneApps.length + (AudioService.microphoneApps.length === 1 ? " application" : " applications") + " · base input " + Math.round(microphonePopup.inputGain * 100) + "%"
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.08)
                        height: 1
                    }
                    Repeater {
                        model: AudioService.microphoneApps.slice(0, 4)

                        delegate: Rectangle {
                            id: appCard

                            required property var modelData
                            readonly property bool streamAvailable: streamNode && streamNode.audio
                            readonly property real streamGain: streamAvailable ? streamNode.audio.volume : 0
                            readonly property bool streamMuted: streamAvailable ? streamNode.audio.muted : true
                            readonly property var streamNode: modelData ? modelData.node : null
                            readonly property real streamPeak: Math.max(0, Math.min(1, peakMonitor.peak))

                            Layout.fillWidth: true
                            Layout.preferredHeight: 76
                            color: Config.md3.surface
                            opacity: streamAvailable ? 1 : 0.5
                            radius: 12

                            PwNodePeakMonitor {
                                id: peakMonitor

                                enabled: microphonePopup.visible && appCard.streamAvailable && !appCard.streamMuted
                                node: appCard.streamNode
                            }
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 9

                                    Rectangle {
                                        Layout.preferredHeight: 30
                                        Layout.preferredWidth: 30
                                        color: Config.md3.surface_container_high
                                        radius: 9

                                        IconImage {
                                            anchors.centerIn: parent
                                            height: 19
                                            source: Quickshell.iconPath(appCard.modelData.icon || "audio-input-microphone-symbolic")
                                            width: 19
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            color: Config.md3.on_surface
                                            elide: Text.ElideRight
                                            font.family: Config.fontName
                                            font.pixelSize: 14
                                            font.weight: Font.Bold
                                            text: appCard.modelData.name
                                        }
                                    }
                                    Rectangle {
                                        Layout.preferredHeight: 30
                                        Layout.preferredWidth: 30
                                        color: streamMuteMouse.containsMouse ? Config.alpha(appCard.streamMuted ? Config.md3.error : Config.md3.tertiary, 0.22) : Config.alpha(appCard.streamMuted ? Config.md3.error : Config.md3.on_surface, 0.1)
                                        radius: 9

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }

                                        IconImage {
                                            id: streamMuteIcon

                                            anchors.centerIn: parent
                                            height: 17
                                            source: Quickshell.iconPath(appCard.streamMuted ? "microphone-sensitivity-muted-symbolic" : "microphone-sensitivity-high-symbolic")
                                            visible: false
                                            width: 17
                                        }
                                        ColorOverlay {
                                            anchors.fill: streamMuteIcon
                                            color: appCard.streamMuted ? Config.md3.error : Config.md3.on_surface
                                            source: streamMuteIcon
                                        }
                                        MouseArea {
                                            id: streamMuteMouse

                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: appCard.streamAvailable
                                            hoverEnabled: true

                                            onClicked: appCard.streamNode.audio.muted = !appCard.streamNode.audio.muted
                                        }
                                    }
                                }
                                CustomVolumeSlider {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 20
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
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        text: "+" + (AudioService.microphoneApps.length - 4) + " more"
                        visible: AudioService.microphoneApps.length > 4
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
