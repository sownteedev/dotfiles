import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

MouseArea {
    id: root

    readonly property var activeWindow: WorkspaceService.activeWindowByOutput[root.outputName] || null
    readonly property string appId: activeWindow ? (activeWindow.app_id || "desktop").toLowerCase() : "desktop"
    property real maximumTextWidth: -1
    required property string outputName
    readonly property string title: activeWindow ? (activeWindow.title || "niri") : "niri"
    property bool toggleFailed: false
    readonly property bool workspaceFloating: WorkspaceService.floatingByOutput[root.outputName] === true

    implicitHeight: contentLayout.implicitHeight
    implicitWidth: contentLayout.implicitWidth

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    Process {
        id: toggleScriptProcess

        command: [Config.dotfilesDir + "/.config/niri/scripts/toogle-floating-workspace", "--output", root.outputName]

        onExited: (exitCode, exitStatus) => {
            root.toggleFailed = exitCode !== 0;
            if (root.toggleFailed) {
                console.warn("[ActiveClient] Workspace layout toggle failed:", exitCode);
                failureResetTimer.restart();
            }

            WorkspaceService.refresh();
        }
    }
    Timer {
        id: failureResetTimer

        interval: 1800

        onTriggered: root.toggleFailed = false
    }
    RowLayout {
        id: contentLayout

        spacing: 5

        Rectangle {
            id: layoutToggleButton

            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 10
            color: root.toggleFailed ? Config.alpha(Config.md3.error, 0.18) : toggleScriptProcess.running ? Config.alpha(Config.md3.primary, 0.16) : buttonArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.1) : Config.alpha(Config.md3.surface, Config.lightTheme ? 0.7 : 0.5)
            height: 38
            radius: 10
            scale: buttonArea.pressed ? 0.9 : 1
            width: 38

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: buttonArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !toggleScriptProcess.running && root.outputName !== ""
                hoverEnabled: true

                onClicked: {
                    root.toggleFailed = false;
                    toggleScriptProcess.running = true;
                }
            }
            Item {
                id: modeGlyph

                anchors.centerIn: parent
                height: 18
                opacity: toggleScriptProcess.running ? 0.52 : 1
                scale: toggleScriptProcess.running ? 0.88 : 1
                visible: !root.toggleFailed
                width: 28

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: root.workspaceFloating ? 0 : 1
                    scale: root.workspaceFloating ? 0.72 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutBack
                        }
                    }

                    Repeater {
                        model: 2

                        delegate: Rectangle {
                            border.color: root.workspaceFloating ? Config.md3.primary : Config.md3.on_surface
                            border.width: 1.5
                            color: index === 0 ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.2)
                            height: 16
                            radius: 3
                            width: 13
                            x: index * 15
                            y: 1
                        }
                    }
                }
                Item {
                    anchors.fill: parent
                    opacity: root.workspaceFloating ? 1 : 0
                    scale: root.workspaceFloating ? 1 : 0.72

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutBack
                        }
                    }

                    Rectangle {
                        border.color: Config.alpha(Config.md3.primary, 0.62)
                        border.width: 1.5
                        color: Config.alpha(Config.md3.primary, 0.08)
                        height: 13
                        radius: 3
                        width: 18
                        x: 8
                        y: 0
                    }
                    Rectangle {
                        border.color: Config.md3.primary
                        border.width: 1.7
                        color: Config.alpha(Config.md3.primary, 0.16)
                        height: 13
                        radius: 3
                        width: 18
                        x: 1
                        y: 5
                    }
                }
            }
            IconImage {
                id: statusIcon

                anchors.centerIn: parent
                height: 20
                layer.enabled: true
                source: Quickshell.iconPath("dialog-warning-symbolic")
                visible: root.toggleFailed
                width: 20

                layer.effect: ColorOverlay {
                    color: Config.md3.error

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.maximumTextWidth > 0 ? root.maximumTextWidth : Infinity
            Layout.preferredWidth: root.maximumTextWidth > 0 ? Math.min(implicitWidth, root.maximumTextWidth) : implicitWidth
            spacing: 2

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                maximumLineCount: 1
                text: root.appId
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: Font.DemiBold
                maximumLineCount: 1
                text: root.title
            }
        }
    }
}
