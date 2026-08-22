import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string baselineState: ""
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState

    function currentState() {
        return {
            "notificationPopupDuration": Number(durationField.text),
            "notificationMaxVisible": Number(maxVisibleField.text),
            "notificationPosition": positionChoice.value,
            "notificationShowOnLock": lockToggle.checked,
            "notificationShowInFullscreen": fullscreenToggle.checked,
            "notificationHistoryLimit": Number(historyLimitField.text),
            "notificationHistoryExcludedApps": historyExcludedField.text,
            "notificationBlockedApps": blockedAppsField.text,
            "notificationDndScheduleEnabled": scheduleToggle.checked,
            "notificationDndStart": startField.text,
            "notificationDndEnd": endField.text
        };
    }
    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        durationField.text = String(settings.notificationPopupDuration ?? Config.notificationPopupDuration);
        maxVisibleField.text = String(settings.notificationMaxVisible ?? Config.notificationMaxVisible);
        positionChoice.value = settings.notificationPosition || Config.notificationPosition;
        lockToggle.checked = settings.notificationShowOnLock ?? Config.notificationShowOnLock;
        fullscreenToggle.checked = settings.notificationShowInFullscreen ?? Config.notificationShowInFullscreen;
        historyLimitField.text = String(settings.notificationHistoryLimit ?? Config.notificationHistoryLimit);
        historyExcludedField.text = settings.notificationHistoryExcludedApps ?? Config.notificationHistoryExcludedApps;
        blockedAppsField.text = settings.notificationBlockedApps ?? Config.notificationBlockedApps;
        scheduleToggle.checked = settings.notificationDndScheduleEnabled ?? Config.notificationDndScheduleEnabled;
        startField.text = settings.notificationDndStart || Config.notificationDndStart;
        endField.text = settings.notificationDndEnd || Config.notificationDndEnd;
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: syncFields()

    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    SettingsPageContent {
        id: pageContent

        anchors.fill: parent

        SettingsSectionCard {
            Layout.columnSpan: pageContent.columnCount
            Layout.fillWidth: true
            accentColor: Config.md3.primary
            compact: true
            note: "Popup placement and lifetime on the currently focused output"
            title: "Popups"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: width >= 620 ? 2 : 1
                rowSpacing: 12
                uniformCellWidths: true

                SettingsTextField {
                    id: durationField

                    Layout.fillWidth: true
                    label: "Default duration (ms)"
                    placeholder: "5000"

                    inputItem.validator: IntValidator {
                        bottom: 1000
                        top: 30000
                    }
                }
                SettingsTextField {
                    id: maxVisibleField

                    Layout.fillWidth: true
                    label: "Maximum visible"
                    placeholder: "3"

                    inputItem.validator: IntValidator {
                        bottom: 1
                        top: 6
                    }
                }
            }
            SettingsChoiceRow {
                id: positionChoice

                Layout.fillWidth: true
                label: "Position"
                options: [
                    {
                        "label": "Top",
                        "value": "top"
                    },
                    {
                        "label": "Top right",
                        "value": "top-right"
                    },
                    {
                        "label": "Bottom right",
                        "value": "bottom-right"
                    }
                ]

                onSelected: value => positionChoice.value = value
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: 1
                rowSpacing: 10
                uniformCellWidths: true

                SettingsToggleTile {
                    id: fullscreenToggle

                    label: "Show over fullscreen applications"
                    note: "Critical items remain in history"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: lockToggle

                    label: "Show on lock screen"
                    note: "Disable to keep content private"

                    onToggled: value => checked = value
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            note: "Schedule adds to manual Do Not Disturb; it does not overwrite the quick toggle"
            title: "Do Not Disturb"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: 1
                rowSpacing: 10
                uniformCellWidths: true

                SettingsToggleTile {
                    id: scheduleToggle

                    label: "Enable schedule"
                    note: "Supports schedules that cross midnight"

                    onToggled: value => checked = value
                }
                SettingsTextField {
                    id: startField

                    Layout.fillWidth: true
                    enabled: scheduleToggle.checked
                    inputItem.maximumLength: 5
                    label: "Start (24-hour)"
                    opacity: enabled ? 1 : 0.45
                    placeholder: "23:00"
                }
                SettingsTextField {
                    id: endField

                    Layout.fillWidth: true
                    enabled: scheduleToggle.checked
                    inputItem.maximumLength: 5
                    label: "End (24-hour)"
                    opacity: enabled ? 1 : 0.45
                    placeholder: "07:00"
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.tertiary
            compact: true
            note: "Use comma-separated application names; matching is case-insensitive"
            title: "History and application rules"

            SettingsTextField {
                id: historyLimitField

                Layout.preferredWidth: 260
                label: "History limit"
                placeholder: "100"

                inputItem.validator: IntValidator {
                    bottom: 0
                    top: 500
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: width >= 620 ? 2 : 1
                rowSpacing: 12
                uniformCellWidths: true

                SettingsTextField {
                    id: blockedAppsField

                    Layout.fillWidth: true
                    label: "Disable popups for"
                    placeholder: "Spotify, Screenshot"
                }
                SettingsTextField {
                    id: historyExcludedField

                    Layout.fillWidth: true
                    label: "Do not save history for"
                    placeholder: "Password Manager"
                }
            }
        }
    }
}
