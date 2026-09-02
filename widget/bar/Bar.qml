import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../../"
import "../../service"

PanelWindow {
    id: bar

    readonly property bool compact: width < 1600
    readonly property real densityScale: Config.barDensity === "compact" ? 0.82 : Config.barDensity === "spacious" ? 1.18 : 1
    readonly property real horizontalInset: Responsive.clamp(width * 0.01, 10, 25) * densityScale
    readonly property bool narrow: width < 1280
    readonly property real statusClusterSpacing: Responsive.clamp(width * 0.007, 10, 14) * densityScale
    readonly property real statusIconSpacing: Responsive.clamp(width * 0.014, 18, 26) * densityScale
    readonly property bool themeReady: ThemeService.hasAppliedTheme || (ThemeService.themeFileResolved && !Config.matugenEnabled)

    WlrLayershell.namespace: Config.shellBlurBarEnabled ? "blur-bar" : "quickshell-bar"
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: themeReady ? (Config.shellBlurBarEnabled ? Config.alpha(Config.md3.background, Config.lightTheme ? Config.shellBlurBarOpacityLight : Config.shellBlurBarOpacityDark) : Config.md3.background) : "transparent"
    implicitHeight: Config.barHeight

    SystemClock {
        id: systemClock
    }
    IdleInhibitor {
        enabled: QuickSettingsService.caffeineEnabled
        window: bar
    }
    Item {
        anchors.fill: parent
        opacity: bar.themeReady ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: bar.horizontalInset
            anchors.rightMargin: bar.horizontalInset
            spacing: bar.narrow ? Responsive.spacingS : Responsive.spacingM

            Item {
                id: leftZone

                readonly property real preferredActiveTextWidth: Responsive.clamp(width * 0.38, 118, 280)

                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                clip: true
                visible: Config.barShowActiveClient || Config.barShowMedia

                Flickable {
                    id: leftFlickable

                    anchors.fill: parent
                    boundsBehavior: Flickable.StopAtBounds
                    clip: contentWidth > width
                    contentHeight: height
                    contentWidth: Math.max(width, leftContent.implicitWidth)
                    flickableDirection: Flickable.HorizontalFlick
                    interactive: contentWidth > width

                    RowLayout {
                        id: leftContent

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: bar.compact ? Responsive.spacingL : Responsive.spacingXL

                        ActiveClient {
                            id: activeClient

                            maximumTextWidth: Math.min(leftZone.preferredActiveTextWidth, Math.max(64, mediaItem.visible ? leftZone.width * 0.38 : leftZone.width - 60))
                            outputName: bar.screen ? bar.screen.name : ""
                            visible: Config.barShowActiveClient
                        }
                        Media {
                            id: mediaItem

                            maximumWidth: Math.min(350, Math.max(90, leftZone.width - activeClient.implicitWidth - leftContent.spacing))
                            visible: Config.barShowMedia && implicitWidth > 0
                        }
                    }
                }
            }
            Item {
                id: workspaceViewport

                Layout.fillHeight: true
                Layout.preferredWidth: Math.min(workspaceStrip.implicitWidth, bar.width * (bar.narrow ? 0.34 : bar.compact ? 0.38 : 0.42))
                visible: Config.barShowWorkspaces

                Flickable {
                    id: workspaceFlickable

                    anchors.fill: parent
                    boundsBehavior: Flickable.StopAtBounds
                    clip: contentWidth > width
                    contentHeight: height
                    contentWidth: workspaceStrip.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    interactive: contentWidth > width

                    Workspaces {
                        id: workspaceStrip

                        compact: bar.compact
                        height: workspaceFlickable.height
                        outputName: bar.screen ? bar.screen.name : ""
                        x: workspaceFlickable.contentWidth <= workspaceFlickable.width ? (workspaceFlickable.width - implicitWidth) / 2 : 0
                    }
                }
            }
            Item {
                id: rightZone

                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                clip: true

                Flickable {
                    id: rightFlickable

                    function alignRight() {
                        contentX = Math.max(0, contentWidth - width);
                    }

                    anchors.fill: parent
                    boundsBehavior: Flickable.StopAtBounds
                    clip: contentWidth > width
                    contentHeight: height
                    contentWidth: Math.max(width, rightContent.implicitWidth)
                    flickableDirection: Flickable.HorizontalFlick
                    interactive: contentWidth > width

                    Component.onCompleted: alignRight()
                    onContentWidthChanged: {
                        if (!moving)
                            Qt.callLater(alignRight);
                    }
                    onWidthChanged: {
                        if (!moving)
                            Qt.callLater(alignRight);
                    }

                    RowLayout {
                        id: rightContent

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: bar.statusIconSpacing
                        x: rightFlickable.contentWidth - implicitWidth

                        RecordingIndicator {
                            parentWindow: bar
                            visible: Config.barShowRecording
                        }
                        SysTray {
                            itemSpacing: bar.statusIconSpacing
                            parentWindow: bar
                            visible: Config.barShowSysTray
                        }
                        MicrophonePrivacy {
                            parentWindow: bar
                            visible: Config.barShowMicrophone && AudioService.microphoneInUse
                        }
                        TailscaleStatus {
                        }
                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            implicitHeight: 22
                            implicitWidth: 22
                            visible: QuickSettingsService.caffeineEnabled

                            onClicked: QuickSettingsService.setCaffeineEnabled(false)

                            IconImage {
                                anchors.fill: parent
                                layer.enabled: true
                                source: Quickshell.iconPath("caffeine-cup-full-symbolic")

                                layer.effect: ColorOverlay {
                                    color: Config.md3.primary
                                }
                            }
                        }
                        Wifi {
                            hoverExpansionEnabled: !bar.compact
                            targetScreen: bar.screen
                            visible: Config.barShowNetwork
                        }
                        BluetoothStatus {
                            hoverExpansionEnabled: !bar.compact
                            targetScreen: bar.screen
                            visible: Config.barShowBluetooth
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: bar.statusClusterSpacing + 7
                            visible: Config.barShowBattery || Config.barShowWeather || Config.barShowNotifications

                            Weather {
                                compact: bar.compact
                                visible: Config.barShowWeather
                            }
                            Battery {
                                visible: Config.barShowBattery
                            }
                            NotificationIcon {
                                targetScreen: bar.screen
                                visible: Config.barShowNotifications
                            }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: bar.compact ? 10 : 12
                            visible: Config.barShowClock

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: bar.compact ? 15 : 18
                                font.weight: Font.DemiBold
                                text: "│"
                            }
                            MouseArea {
                                id: clockArea

                                hoverEnabled: true
                                implicitHeight: 30
                                implicitWidth: clockLayout.implicitWidth

                                ColumnLayout {
                                    id: clockLayout

                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0

                                    Text {
                                        Layout.alignment: Qt.AlignRight
                                        color: Config.md3.on_surface
                                        font.family: Config.fontName
                                        font.pixelSize: bar.compact ? 14 : 16
                                        font.weight: Font.Bold
                                        text: systemClock.date ? Qt.formatDateTime(systemClock.date, Config.clock24h ? "HH : mm" : "hh : mm A") : ""
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignRight
                                        color: Config.md3.on_surface_variant
                                        font.family: Config.fontName
                                        font.pixelSize: bar.compact ? 12 : 15
                                        font.weight: Font.Medium
                                        text: systemClock.date ? Qt.formatDateTime(systemClock.date, "ddd, dd MMM yyyy") : ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
