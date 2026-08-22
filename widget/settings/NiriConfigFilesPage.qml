import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int activeFile: 0
    property var fileLabels: ["Environment", "Autostart", "Workspaces"]
    property var fileNames: ["environment.kdl", "autostart.kdl", "workspaces.kdl"]
    readonly property bool headerActionEnabled: editor.canApply
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Validating…" : "Save & apply"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: editor.dirty

    function resetPage() {
        editor.reset();
    }
    function triggerHeaderAction() {
        editor.apply();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            clip: true
            model: root.fileLabels.length
            orientation: ListView.Horizontal
            spacing: 8

            delegate: Rectangle {
                required property int index

                color: root.activeFile === index ? Config.alpha(Config.md3.primary, 0.2) : (fileMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.045))
                height: 42
                radius: 12
                width: fileLabel.implicitWidth + 32

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                Text {
                    id: fileLabel

                    anchors.centerIn: parent
                    color: root.activeFile === index ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.72)
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: root.fileLabels[index]
                }
                MouseArea {
                    id: fileMouse

                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: root.activeFile === index || !editor.dirty
                    hoverEnabled: true

                    onClicked: root.activeFile = index
                }
            }
        }
        NiriConfigEditor {
            id: editor

            Layout.fillHeight: true
            Layout.fillWidth: true
            description: "Full source editor for settings that do not map cleanly to simple controls."
            editorHeight: Math.max(320, height - 104)
            fileName: root.fileNames[root.activeFile]
            title: root.fileLabels[root.activeFile] + " · " + fileName
        }
    }
}
