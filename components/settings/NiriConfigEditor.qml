import "../../"
import "../../service"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property bool canApply: !SettingsHubService.busy && editor.text.trim() !== ""
    property string description: "Advanced KDL editor. Changes are validated before Niri reloads."
    readonly property bool dirty: editor.text !== sourceText()
    property int editorHeight: 520
    property string fileName: ""
    property string title: fileName

    function apply() {
        if (!canApply)
            return;
        editor.focus = false;
        SettingsHubService.saveNiriFile(root.fileName, editor.text);
    }
    function reset() {
        editor.focus = false;
        editor.text = sourceText();
    }
    function sourceText() {
        var files = SettingsHubService.niriFiles || {};
        var source = files[root.fileName];
        return source === undefined ? "" : source;
    }
    function syncSource() {
        if (editor.activeFocus)
            return;

        var source = sourceText();
        if (editor.text !== source)
            editor.text = source;
    }

    implicitHeight: content.implicitHeight

    Component.onCompleted: syncSource()
    onFileNameChanged: {
        editor.focus = false;
        Qt.callLater(root.syncSource);
    }

    Connections {
        function onNiriFilesChanged() {
            root.syncSource();
        }

        target: SettingsHubService
    }
    ColumnLayout {
        id: content

        anchors.fill: parent
        spacing: Md3.spacing.sm

        SettingsLabelBlock {
            Layout.fillWidth: true
            emphasized: true
            headline: root.title
            headlineRole: "titleLarge"
            supportingText: root.description
        }
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumHeight: 160
            Layout.preferredHeight: root.editorHeight
            border.color: editor.activeFocus ? Config.alpha(Config.md3.primary, 0.65) : Config.alpha(Config.md3.on_surface, 0.08)
            border.width: 1
            color: Config.alpha(Config.md3.background, 0.46)
            radius: 14

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                ScrollBar.horizontal: SlimScrollBar {
                }
                ScrollBar.vertical: SlimScrollBar {
                }

                TextArea {
                    id: editor

                    color: Config.alpha(Config.md3.on_surface, 0.84)
                    font.family: "monospace"
                    font.pixelSize: Md3.typeScale.bodyLarge.size
                    leftPadding: 10
                    rightPadding: 10
                    selectByKeyboard: true
                    selectByMouse: true
                    tabStopDistance: font.pixelSize * 4
                    wrapMode: TextEdit.NoWrap

                    background: Item {
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
            font.pixelSize: Md3.typeScale.bodySmall.size
            lineHeight: Md3.typeScale.bodySmall.lineHeight
            lineHeightMode: Text.FixedHeight
            text: root.dirty ? "Unsaved changes · Apply or reset before switching files." : "Changes are validated before the live file is replaced."
            wrapMode: Text.Wrap
        }
    }
}
