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
    property int editorHeight: 520
    property string fileName: ""
    property string title: fileName

    function apply() {
        if (!canApply)
            return;
        editor.focus = false;
        SettingsHubService.saveNiriFile(root.fileName, editor.text);
    }
    function syncSource() {
        if (editor.activeFocus)
            return;

        var files = SettingsHubService.niriFiles || {};
        var source = files[root.fileName];
        if (source !== undefined && editor.text !== source)
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

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 20
                font.weight: Font.DemiBold
                text: root.title
            }
            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.48)
                font.family: Config.fontName
                font.pixelSize: 13
                text: root.description
                wrapMode: Text.Wrap
            }
        }
        Rectangle {
            Layout.fillWidth: true
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
                    font.pixelSize: 15
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
            color: Config.alpha(Config.md3.on_surface, 0.4)
            font.family: Config.fontName
            font.pixelSize: 12
            text: "If validation fails, the original file is restored automatically."
        }
    }
}
