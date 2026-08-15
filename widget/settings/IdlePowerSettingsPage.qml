import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: true

    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        idleToggle.checked = settings.idleEnabled ?? Config.idleEnabled;
        lockField.text = String(settings.idleLockTimeout ?? Config.idleLockTimeout);
        lockedDisplayField.text = String(settings.idleLockedDisplayTimeout ?? Config.idleLockedDisplayTimeout);
        displayField.text = String(settings.idleDisplayTimeout ?? Config.idleDisplayTimeout);
        suspendField.text = String(settings.idleSuspendTimeout ?? Config.idleSuspendTimeout);
        beforeSleepToggle.checked = settings.idleLockBeforeSleep ?? Config.idleLockBeforeSleep;
        caffeineChoice.value = String(settings.caffeineAutoDisableMinutes ?? Config.caffeineAutoDisableMinutes);
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell({
            "idleEnabled": idleToggle.checked,
            "idleLockTimeout": Number(lockField.text),
            "idleLockedDisplayTimeout": Number(lockedDisplayField.text),
            "idleDisplayTimeout": Number(displayField.text),
            "idleSuspendTimeout": Number(suspendField.text),
            "idleLockBeforeSleep": beforeSleepToggle.checked,
            "caffeineAutoDisableMinutes": Number(caffeineChoice.value)
        });
    }

    Component.onCompleted: syncFields()

    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    SettingsPageContent {
        anchors.fill: parent

        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.primary
            compact: true
            note: "Managed by a user systemd service so Quickshell reloads do not leave duplicate swayidle processes"
            title: "Idle policy"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: width >= 620 ? 2 : 1
                rowSpacing: 10
                uniformCellWidths: true

                SettingsToggleTile {
                    id: idleToggle

                    label: "Enable idle management"
                    note: "Caffeine temporarily inhibits this policy"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: beforeSleepToggle

                    checked: true
                    label: "Lock before suspend"
                    note: "Keeps password and face authentication ready on resume"

                    onToggled: value => checked = value
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: width >= 1040 ? 4 : width >= 500 ? 2 : 1
                enabled: idleToggle.checked
                opacity: enabled ? 1 : 0.45
                rowSpacing: 12
                uniformCellWidths: true

                SettingsTextField {
                    id: lockField

                    Layout.fillWidth: true
                    label: "Lock after (seconds)"
                    placeholder: "600"

                    inputItem.validator: IntValidator {
                        bottom: 0
                        top: 86400
                    }
                }
                SettingsTextField {
                    id: lockedDisplayField

                    Layout.fillWidth: true
                    label: "Display off while locked (seconds)"
                    placeholder: "60"

                    inputItem.validator: IntValidator {
                        bottom: 0
                        top: 86400
                    }
                }
                SettingsTextField {
                    id: displayField

                    Layout.fillWidth: true
                    label: "Display off after (seconds)"
                    placeholder: "600"

                    inputItem.validator: IntValidator {
                        bottom: 0
                        top: 86400
                    }
                }
                SettingsTextField {
                    id: suspendField

                    Layout.fillWidth: true
                    label: "Suspend after (seconds)"
                    placeholder: "0 = disabled"

                    inputItem.validator: IntValidator {
                        bottom: 0
                        top: 86400
                    }
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            note: "Choose how long the quick Caffeine toggle remains active"
            title: "Caffeine"

            SettingsChoiceRow {
                id: caffeineChoice

                Layout.fillWidth: true
                Layout.maximumWidth: 760
                label: "Automatic timeout"
                options: [
                    {
                        "label": "Until disabled",
                        "value": "0"
                    },
                    {
                        "label": "30 min",
                        "value": "30"
                    },
                    {
                        "label": "1 hour",
                        "value": "60"
                    },
                    {
                        "label": "2 hours",
                        "value": "120"
                    }
                ]

                onSelected: value => caffeineChoice.value = value
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.tertiary
            compact: true
            note: "The service is applied after saving; zero disables an individual timeout"
            title: "Policy summary"

            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.66)
                font.family: Config.fontName
                font.pixelSize: 14
                text: idleToggle.checked ? "Lock: %1s  ·  Locked display: %2  ·  Display: %3s  ·  Suspend: %4".arg(lockField.text || "0").arg(Number(lockedDisplayField.text || 0) > 0 ? lockedDisplayField.text + "s" : "off").arg(displayField.text || "0").arg(Number(suspendField.text || 0) > 0 ? suspendField.text + "s" : "off") : "Idle management disabled"
                wrapMode: Text.Wrap
            }
        }
    }
}
