import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root

    readonly property bool slowdownValid: isFinite(Number(slowdownField.text)) && Number(slowdownField.text) >= 0.05 && Number(slowdownField.text) <= 10
    readonly property bool headerActionEnabled: !SettingsHubService.busy && slowdownValid
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Applying…" : "Apply animations"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: true

    function syncGlobal() {
        var settings = SettingsHubService.animationSettings || {};
        animationToggle.checked = settings.enabled !== false;
        slowdownField.text = String(settings.slowdown === undefined ? 1 : settings.slowdown);
    }
    function triggerHeaderAction() {
        SettingsHubService.saveAnimationGlobal(animationToggle.checked, Number(slowdownField.text));
    }
    function resetPage() {
        syncGlobal();
    }

    clip: true
    contentHeight: content.implicitHeight
    contentWidth: Math.max(availableWidth, 620)

    ScrollBar.horizontal: SlimScrollBar {
        accentColor: Config.md3.secondary
    }

    ScrollBar.vertical: SlimScrollBar {
        accentColor: Config.md3.secondary
    }

    Component.onCompleted: syncGlobal()

    Connections {
        function onAnimationSettingsChanged() {
            root.syncGlobal();
        }

        target: SettingsHubService
    }
    ColumnLayout {
        id: content

        spacing: 14
        width: root.contentWidth

        Rectangle {
            Layout.fillWidth: true
            color: Config.alpha(Config.md3.on_surface, 0.04)
            implicitHeight: globalContent.implicitHeight + 36
            radius: 16

            ColumnLayout {
                id: globalContent

                anchors.left: parent.left
                anchors.margins: 18
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 16

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                    text: "Animation engine"
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: "Enable Niri animations"
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.5)
                            font.family: Config.fontName
                            font.pixelSize: 12
                            text: "A global switch for every compositor animation"
                        }
                    }
                    ToggleSwitch {
                        id: animationToggle

                        accessibleName: "Enable Niri animations"
                        enabled: !SettingsHubService.busy

                        onToggled: checked => {
                            animationToggle.checked = checked;
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true

                    SettingsTextField {
                        id: slowdownField

                        Layout.fillWidth: true
                        label: "Speed multiplier"
                        placeholder: "1.0"
                    }
                }
                Text {
                    Layout.fillWidth: true
                    font.family: Config.fontName
                    font.pixelSize: 11
                    color: root.slowdownValid ? Config.alpha(Config.md3.on_surface, 0.42) : Config.md3.error
                    text: root.slowdownValid ? "1.0 is normal. Larger values make animations slower." : "Enter a value from 0.05 to 10."
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: 12
            columns: 2
            rowSpacing: 12

            Repeater {
                model: (SettingsHubService.animationSettings || {
                        "entries": []
                    }).entries || []

                delegate: Rectangle {
                    id: animationCard

                    property bool enabledState: modelData.enabled === true
                    required property var modelData

                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.04)
                    implicitHeight: 82
                    radius: 15

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                text: String(animationCard.modelData.name).replace(/-/g, " ")
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.alpha(Config.md3.on_surface, 0.46)
                                elide: Text.ElideRight
                                font.family: "monospace"
                                font.pixelSize: 11
                                text: animationCard.modelData.spec || "Uses Niri defaults"
                            }
                        }
                        ToggleSwitch {
                            accessibleName: "Toggle " + animationCard.modelData.name
                            checked: animationCard.enabledState
                            enabled: !SettingsHubService.busy

                            onToggled: checked => {
                                animationCard.enabledState = checked;
                                SettingsHubService.saveAnimationEntry(animationCard.modelData.name, checked);
                            }
                        }
                    }
                }
            }
        }
        Item {
            Layout.preferredHeight: 4
        }
    }
}
