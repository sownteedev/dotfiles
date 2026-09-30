import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int activeFile: 0
    readonly property var fileLabels: ["Window rules", "Layer rules"]
    readonly property var fileNames: ["window-rules.kdl", "layer-rules.kdl"]
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
                id: fileTab

                required property int index

                color: root.activeFile === fileTab.index ? Config.alpha(Config.md3.primary, 0.2) : (fileMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.045))
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
                    color: root.activeFile === fileTab.index ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.72)
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                    font.pixelSize: Md3.typeScale.labelLarge.size
                    font.weight: root.activeFile === fileTab.index ? Md3.typeScale.labelLarge.emphasizedWeight : Md3.typeScale.labelLarge.weight
                    text: root.fileLabels[fileTab.index]
                }
                MouseArea {
                    id: fileMouse

                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: root.activeFile === fileTab.index || !editor.dirty
                    hoverEnabled: true

                    onClicked: root.activeFile = fileTab.index
                }
            }
        }
        NiriConfigEditor {
            id: editor

            Layout.fillHeight: true
            Layout.fillWidth: true
            description: "Full source editor for settings that do not map cleanly to simple controls."
            fileName: root.fileNames[root.activeFile]
            title: root.fileLabels[root.activeFile] + " · " + fileName
        }
    }
}
