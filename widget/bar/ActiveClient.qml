import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

MouseArea {
    id: root

    readonly property string appId: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.appId || "desktop").toLowerCase() : "desktop"
    readonly property string title: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "niri") : "niri"

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

        command: [Config.dotfilesDir + "/.config/niri/scripts/toogle-floating-workspace"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[ActiveClient] Workspace layout toggle failed:", exitCode);

            WorkspaceService.refresh();
        }
    }
    RowLayout {
        id: contentLayout

        spacing: 5

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 10
            color: Config.md3.surface
            height: 38
            radius: 10
            width: 38

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !toggleScriptProcess.running

                onClicked: {
                    toggleScriptProcess.running = true;
                }
            }
            IconImage {
                anchors.centerIn: parent
                height: 20
                layer.enabled: true
                source: WorkspaceService.isWorkspaceFloating ? Quickshell.iconPath("view-restore-symbolic") : Quickshell.iconPath("view-grid-symbolic")
                width: 20

                layer.effect: ColorOverlay {
                    color: toggleScriptProcess.running ? Config.md3.on_surface_variant : Config.md3.on_surface

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
            spacing: 2

            Text {
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                text: root.appId
            }
            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: Font.DemiBold
                text: root.title.length > 40 ? root.title.substring(0, 40) + "..." : root.title
            }
        }
    }
}
