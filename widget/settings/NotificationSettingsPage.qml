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
    property int notificationCriticalTimeout: 0
    property int notificationLowTimeout: 5000
    property int notificationNormalTimeout: 5000
    readonly property var timeoutOptions: [
        {
            "label": qsTr("3 seconds"),
            "value": 3000
        },
        {
            "label": qsTr("5 seconds"),
            "value": 5000
        },
        {
            "label": qsTr("10 seconds"),
            "value": 10000
        },
        {
            "label": qsTr("15 seconds"),
            "value": 15000
        },
        {
            "label": qsTr("30 seconds"),
            "value": 30000
        },
        {
            "label": qsTr("1 minute"),
            "value": 60000
        },
        {
            "label": qsTr("Never"),
            "value": 0
        }
    ]
    property bool timeoutPopupOpen: false
    property bool timeoutPopupOpenAbove: false
    property real timeoutPopupRightMargin: 12
    property string timeoutPopupTarget: ""
    property real timeoutPopupY: 0

    function currentState() {
        return {
            "notificationCriticalTimeout": notificationCriticalTimeout,
            "notificationLowTimeout": notificationLowTimeout,
            "notificationMaxVisible": Number(maxVisibleField.text),
            "notificationNormalTimeout": notificationNormalTimeout,
            "notificationPopupDuration": notificationNormalTimeout,
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
    function normalizeTimeout(value, fallback) {
        var timeout = Number(value);
        if (!isFinite(timeout) || timeout < 0)
            return fallback;

        return Math.round(timeout);
    }
    function openTimeoutPopup(sourceItem, target) {
        if (timeoutPopupOpen && timeoutPopupTarget === target) {
            timeoutPopupOpen = false;
            return;
        }

        var position = sourceItem.mapToItem(root, 0, 0);
        var popupHeight = timeoutOptions.length * 44 + 16;
        var belowY = position.y + sourceItem.height + 8;
        timeoutPopupTarget = target;
        timeoutPopupOpenAbove = belowY + popupHeight > height;
        timeoutPopupY = timeoutPopupOpenAbove ? position.y - popupHeight - 8 : belowY;
        timeoutPopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        timeoutPopupOpen = true;
    }
    function resetPage() {
        syncFields();
    }
    function selectTimeout(item) {
        if (!item)
            return;

        var timeout = normalizeTimeout(item.value, 5000);
        if (timeoutPopupTarget === "low")
            notificationLowTimeout = timeout;
        else if (timeoutPopupTarget === "critical")
            notificationCriticalTimeout = timeout;
        else
            notificationNormalTimeout = timeout;
        timeoutPopupOpen = false;
    }
    function selectedTimeout() {
        if (timeoutPopupTarget === "low")
            return notificationLowTimeout;
        if (timeoutPopupTarget === "critical")
            return notificationCriticalTimeout;
        return notificationNormalTimeout;
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        var legacyTimeout = normalizeTimeout(settings.notificationPopupDuration ?? Config.notificationPopupDuration, 5000);
        notificationCriticalTimeout = normalizeTimeout(settings.notificationCriticalTimeout ?? Config.notificationCriticalTimeout, 0);
        notificationLowTimeout = normalizeTimeout(settings.notificationLowTimeout ?? legacyTimeout, legacyTimeout);
        notificationNormalTimeout = normalizeTimeout(settings.notificationNormalTimeout ?? legacyTimeout, legacyTimeout);
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
        timeoutPopupOpen = false;
        baselineState = JSON.stringify(currentState());
    }
    function timeoutLabel(value) {
        var timeout = normalizeTimeout(value, 5000);
        if (timeout === 0)
            return qsTr("Never");
        if (timeout === 60000)
            return qsTr("1 minute");

        var seconds = timeout / 1000;
        return seconds === 1 ? qsTr("1 second") : qsTr("%1 seconds").arg(seconds);
    }
    function triggerHeaderAction() {
        timeoutPopupOpen = false;
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
            iconName: "preferences-system-notifications-symbolic"
            note: "Popup placement and lifetime on the currently focused output"
            title: "Popups"

            SettingsTextField {
                id: maxVisibleField

                Layout.preferredWidth: 260
                label: "Maximum visible"
                placeholder: "3"

                inputItem.validator: IntValidator {
                    bottom: 1
                    top: 6
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
            accentColor: Config.md3.tertiary
            compact: true
            iconName: "preferences-system-time-symbolic"
            note: qsTr("Used when an application does not request its own popup lifetime")
            title: qsTr("Notification timeouts")

            SettingsSelectRow {
                accentColor: Config.md3.tertiary
                label: qsTr("Low priority")
                valueText: root.timeoutLabel(root.notificationLowTimeout)

                onClicked: sourceItem => root.openTimeoutPopup(sourceItem, "low")
            }
            SettingsSelectRow {
                accentColor: Config.md3.tertiary
                label: qsTr("Normal priority")
                valueText: root.timeoutLabel(root.notificationNormalTimeout)

                onClicked: sourceItem => root.openTimeoutPopup(sourceItem, "normal")
            }
            SettingsSelectRow {
                accentColor: Config.md3.tertiary
                label: qsTr("Critical priority")
                valueText: root.timeoutLabel(root.notificationCriticalTimeout)

                onClicked: sourceItem => root.openTimeoutPopup(sourceItem, "critical")
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            iconName: "notifications-disabled-symbolic"
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
            iconName: "document-properties-symbolic"
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
    SelectPopup {
        accentColor: Config.md3.tertiary
        anchors.fill: parent
        itemActive: item => item && Number(item.value) === root.selectedTimeout()
        model: root.timeoutOptions
        openAbove: root.timeoutPopupOpenAbove
        opened: root.timeoutPopupOpen
        popupWidth: 220
        popupY: root.timeoutPopupY
        rightMargin: root.timeoutPopupRightMargin
        rowHeight: 44
        z: 20

        onDismissed: root.timeoutPopupOpen = false
        onItemSelected: item => root.selectTimeout(item)
    }
}
