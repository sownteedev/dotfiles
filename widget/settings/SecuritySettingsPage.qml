import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property bool headerActionVisible: false

    function modelDate(timestamp) {
        if (!timestamp || Number(timestamp) <= 0)
            return "Saved face model";
        return "Added " + Qt.formatDateTime(new Date(Number(timestamp) * 1000), "dd MMM yyyy · HH:mm");
    }

    Component.onCompleted: FaceAuthService.refresh()

    Connections {
        function onOperationFinished(success, message) {
            if (success && FaceAuthService.activeAction === "add")
                modelLabelField.text = "";
        }

        target: FaceAuthService
    }
    ScrollView {
        id: scroll

        anchors.fill: parent
        contentHeight: content.implicitHeight
        contentWidth: availableWidth

        ScrollBar.horizontal: SlimScrollBar {
            accentColor: Config.md3.primary
        }
        ScrollBar.vertical: SlimScrollBar {
            accentColor: Config.md3.primary
        }

        GridLayout {
            id: content

            readonly property int columnCount: 1

            columnSpacing: 12
            columns: columnCount
            rowSpacing: 12
            uniformCellWidths: true
            width: scroll.availableWidth
            x: (scroll.availableWidth - width) / 2

            SettingsSectionCard {
                Layout.column: 0
                Layout.fillWidth: true
                Layout.row: 0
                accentColor: Config.md3.primary
                iconName: "system-lock-screen-symbolic"
                note: FaceAuthService.installed ? "Use your face on the Quickshell lock screen while keeping password fallback" : "Howdy is installed by .installconfigtheme on a fresh Arch setup"
                title: "Lock"

                SettingsToggleRow {
                    checked: FaceAuthService.enabled
                    enabled: FaceAuthService.installed && FaceAuthService.models.length > 0 && !FaceAuthService.busy
                    label: "Enable face authentication"
                    note: FaceAuthService.models.length > 0 ? "Password authentication always remains available" : "Add a face model before enabling"
                    opacity: enabled ? 1 : 0.48

                    onToggled: value => FaceAuthService.setEnabled(value)
                }
            }
            SettingsSectionCard {
                Layout.column: 0
                Layout.columnSpan: content.columnCount
                Layout.fillWidth: true
                Layout.row: 1
                accentColor: Config.md3.secondary
                iconName: "avatar-default-symbolic"
                note: FaceAuthService.installed ? (FaceAuthService.camera !== "" ? "Camera · " + FaceAuthService.camera : "The capture camera is detected when a model is added") : "Install support first, then reopen this page"
                title: "Face models"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    SettingsTextField {
                        id: modelLabelField

                        Layout.fillWidth: true
                        editable: FaceAuthService.installed && !FaceAuthService.busy
                        inputItem.maximumLength: 24
                        label: "New model label"
                        placeholder: "Desk, daylight, glasses…"

                        inputItem.onAccepted: {
                            if (modelLabelField.text.trim() !== "" && FaceAuthService.installed && !FaceAuthService.busy)
                                FaceAuthService.addModel(modelLabelField.text.trim());
                        }
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        enabled: FaceAuthService.installed && !FaceAuthService.busy
                        iconName: "list-add-symbolic"
                        opacity: enabled ? 1 : 0.45
                        primary: true
                        text: FaceAuthService.activeAction === "add" ? "Scanning…" : "Add"

                        onClicked: FaceAuthService.addModel(modelLabelField.text.trim())
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        enabled: FaceAuthService.models.length > 0 && !FaceAuthService.busy
                        iconName: "emblem-ok-symbolic"
                        opacity: enabled ? 1 : 0.45
                        text: FaceAuthService.activeAction === "test" ? "Testing…" : "Test"

                        onClicked: FaceAuthService.testModel()
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        enabled: !FaceAuthService.busy
                        iconName: "view-refresh-symbolic"
                        iconOnly: true
                        opacity: enabled ? 1 : 0.45
                        text: "Refresh"

                        onClicked: FaceAuthService.refresh()
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    color: Config.alpha(FaceAuthService.statusSuccess ? Config.md3.secondary : Config.md3.error, 0.1)
                    implicitHeight: statusRow.implicitHeight + 24
                    radius: 13
                    visible: FaceAuthService.statusMessage !== ""

                    RowLayout {
                        id: statusRow

                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Rectangle {
                            color: FaceAuthService.busy ? Config.md3.primary : FaceAuthService.statusSuccess ? Config.md3.secondary : Config.md3.error
                            implicitHeight: 9
                            implicitWidth: 9
                            radius: width / 2

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: FaceAuthService.busy

                                NumberAnimation {
                                    duration: 550
                                    from: 0.3
                                    to: 1
                                }
                                NumberAnimation {
                                    duration: 550
                                    from: 1
                                    to: 0.3
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: FaceAuthService.statusSuccess ? Config.md3.on_surface : Config.md3.error
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            text: FaceAuthService.statusMessage
                            wrapMode: Text.Wrap
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: FaceAuthService.models.length > 0

                    Repeater {
                        model: FaceAuthService.models

                        delegate: Rectangle {
                            id: modelRow

                            property bool confirmingRemoval: false
                            required property var modelData

                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.04)
                            implicitHeight: 68
                            radius: 13

                            Timer {
                                id: confirmTimer

                                interval: 2500

                                onTriggered: modelRow.confirmingRemoval = false
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 13
                                spacing: 12

                                Rectangle {
                                    color: Config.alpha(Config.md3.secondary, 0.15)
                                    implicitHeight: 40
                                    implicitWidth: 40
                                    radius: 12

                                    Text {
                                        anchors.centerIn: parent
                                        color: Config.md3.secondary
                                        font.family: Config.fontName
                                        font.pixelSize: 19
                                        font.weight: Font.Bold
                                        text: "◉"
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        text: modelRow.modelData.label
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.alpha(Config.md3.on_surface, 0.46)
                                        font.family: Config.fontName
                                        font.pixelSize: 12
                                        text: root.modelDate(modelRow.modelData.time) + " · ID " + modelRow.modelData.id
                                    }
                                }
                                SettingsActionButton {
                                    enabled: !FaceAuthService.busy
                                    iconName: modelRow.confirmingRemoval ? "dialog-warning-symbolic" : "user-trash-symbolic"
                                    opacity: enabled ? 1 : 0.45
                                    text: modelRow.confirmingRemoval ? "Confirm" : "Remove"

                                    onClicked: {
                                        if (!modelRow.confirmingRemoval) {
                                            modelRow.confirmingRemoval = true;
                                            confirmTimer.restart();
                                        } else {
                                            confirmTimer.stop();
                                            FaceAuthService.removeModel(modelRow.modelData.id);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.42)
                    font.family: Config.fontName
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    text: FaceAuthService.installed ? "No face models yet" : "Howdy support is missing"
                    visible: FaceAuthService.models.length === 0
                }
            }
            SettingsSectionCard {
                Layout.column: content.columnCount > 1 ? 1 : 0
                Layout.fillWidth: true
                Layout.row: content.columnCount > 1 ? 0 : 2
                accentColor: Config.md3.error
                iconName: "dialog-warning-symbolic"
                note: "This laptop uses an RGB webcam, not a depth or infrared sensor"
                title: "Security note"

                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.58)
                    font.family: Config.fontName
                    font.pixelSize: 13
                    text: "Face unlock is for convenience and may be fooled by a photo or video. Keep your password private and available. Successful and failed camera snapshots are disabled."
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
