import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int acDisplayTimeout: 600
    property int acLockTimeout: 600
    property string acSleepAction: "suspend"
    property int acSuspendTimeout: 0
    property string baselineState: ""
    property int batteryDisplayTimeout: 300
    property int batteryLockTimeout: 300
    property string batterySleepAction: "suspend"
    property int batterySuspendTimeout: 900
    property int caffeineAutoDisableMinutes: 0
    property int dimDuration: 5
    property real dimOpacity: 0.55
    readonly property var dimPresets: [
        {
            "label": qsTr("Never"),
            "value": 0
        },
        {
            "label": qsTr("3 seconds"),
            "value": 3
        },
        {
            "label": qsTr("5 seconds"),
            "value": 5
        },
        {
            "label": qsTr("10 seconds"),
            "value": 10
        },
        {
            "label": qsTr("15 seconds"),
            "value": 15
        },
        {
            "label": qsTr("30 seconds"),
            "value": 30
        }
    ]
    property bool durationPopupOpen: false
    property bool durationPopupOpenAbove: false
    property real durationPopupRightMargin: 12
    property string durationPopupTarget: ""
    property real durationPopupY: 0
    readonly property var durationPresets: [
        {
            "label": qsTr("Never"),
            "value": 0
        },
        {
            "label": qsTr("30 seconds"),
            "value": 30
        },
        {
            "label": qsTr("1 minute"),
            "value": 60
        },
        {
            "label": qsTr("5 minutes"),
            "value": 300
        },
        {
            "label": qsTr("10 minutes"),
            "value": 600
        },
        {
            "label": qsTr("15 minutes"),
            "value": 900
        },
        {
            "label": qsTr("30 minutes"),
            "value": 1800
        },
        {
            "label": qsTr("1 hour"),
            "value": 3600
        }
    ]
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? qsTr("Saving…") : qsTr("Apply & save")
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState
    property bool idleEnabled: true
    property bool lockBeforeSleep: true
    property int lockedDisplayTimeout: 60
    readonly property color policyStatusColor: {
        if (!Config.idleEnabled)
            return Config.md3.outline;
        if (QuickSettingsService.caffeineEnabled)
            return Config.md3.tertiary;
        if (QuickSettingsService.idlePolicyApplying)
            return Config.md3.primary;
        if (QuickSettingsService.idlePolicyError !== "")
            return Config.md3.error;
        return QuickSettingsService.idlePolicyReady ? Config.md3.secondary : Config.md3.outline;
    }
    readonly property string policyStatusNote: {
        if (!Config.idleEnabled)
            return qsTr("Idle timers are disabled");
        if (QuickSettingsService.caffeineEnabled) {
            var remaining = QuickSettingsService.caffeineRemainingSeconds;
            return remaining > 0 ? qsTr("Resumes automatically in %1").arg(durationLabel(remaining)) : qsTr("Remains paused until Caffeine is disabled");
        }
        if (QuickSettingsService.idlePolicyApplying)
            return qsTr("Updating swayidle and the dim service");
        if (QuickSettingsService.idlePolicyError !== "")
            return QuickSettingsService.idlePolicyError;
        if (QuickSettingsService.idlePolicyReady) {
            if (Config.idleDimDuration > 0)
                return qsTr("%1 profile · dim %2 before display off").arg(QuickSettingsService.idleProfileName).arg(durationLabel(Config.idleDimDuration));
            return qsTr("%1 profile · dim disabled").arg(QuickSettingsService.idleProfileName);
        }
        return qsTr("Waiting for the idle service");
    }
    readonly property string policyStatusTitle: {
        if (!Config.idleEnabled)
            return qsTr("Disabled");
        if (QuickSettingsService.caffeineEnabled)
            return qsTr("Paused by Caffeine");
        if (QuickSettingsService.idlePolicyApplying)
            return qsTr("Applying policy…");
        if (QuickSettingsService.idlePolicyError !== "")
            return qsTr("Policy error");
        return QuickSettingsService.idlePolicyReady ? qsTr("Active") : qsTr("Starting…");
    }
    property bool respectInhibitors: true
    property string selectedProfile: "ac"
    property bool separatePowerProfiles: false
    readonly property var sleepOptions: [
        {
            "label": qsTr("Do nothing"),
            "value": "none"
        },
        {
            "label": qsTr("Suspend"),
            "value": "suspend"
        },
        {
            "label": qsTr("Suspend, then hibernate"),
            "value": "suspend-then-hibernate"
        },
        {
            "label": qsTr("Hibernate"),
            "value": "hibernate"
        }
    ]
    property bool sleepPopupOpen: false
    property bool sleepPopupOpenAbove: false
    property real sleepPopupRightMargin: 12
    property real sleepPopupY: 0

    function currentDisplayTimeout() {
        return selectedProfile === "battery" ? batteryDisplayTimeout : acDisplayTimeout;
    }
    function currentLockTimeout() {
        return selectedProfile === "battery" ? batteryLockTimeout : acLockTimeout;
    }
    function currentSleepAction() {
        return selectedProfile === "battery" ? batterySleepAction : acSleepAction;
    }
    function currentState() {
        return {
            "caffeineAutoDisableMinutes": caffeineAutoDisableMinutes,
            "idleBatteryDisplayTimeout": batteryDisplayTimeout,
            "idleBatteryLockTimeout": batteryLockTimeout,
            "idleBatterySleepAction": batterySleepAction,
            "idleBatterySuspendTimeout": batterySuspendTimeout,
            "idleDimDuration": dimDuration,
            "idleDimOpacity": dimOpacity,
            "idleDisplayTimeout": acDisplayTimeout,
            "idleEnabled": idleEnabled,
            "idleLockBeforeSleep": lockBeforeSleep,
            "idleLockedDisplayTimeout": lockedDisplayTimeout,
            "idleLockTimeout": acLockTimeout,
            "idleRespectInhibitors": respectInhibitors,
            "idleSeparatePowerProfiles": separatePowerProfiles,
            "idleSleepAction": acSleepAction,
            "idleSuspendTimeout": acSuspendTimeout
        };
    }
    function currentSuspendTimeout() {
        return selectedProfile === "battery" ? batterySuspendTimeout : acSuspendTimeout;
    }
    function durationLabel(seconds) {
        var value = Math.max(0, Math.round(Number(seconds) || 0));
        if (value === 0)
            return qsTr("Never");
        if (value < 60)
            return value === 1 ? qsTr("1 second") : qsTr("%1 seconds").arg(value);
        if (value % 3600 === 0) {
            var hours = value / 3600;
            return hours === 1 ? qsTr("1 hour") : qsTr("%1 hours").arg(hours);
        }
        if (value % 60 === 0) {
            var minutes = value / 60;
            return minutes === 1 ? qsTr("1 minute") : qsTr("%1 minutes").arg(minutes);
        }
        return qsTr("%1 min %2 sec").arg(Math.floor(value / 60)).arg(value % 60);
    }
    function durationPopupValue() {
        switch (durationPopupTarget) {
        case "lock":
            return currentLockTimeout();
        case "display":
            return currentDisplayTimeout();
        case "sleep":
            return currentSuspendTimeout();
        case "locked-display":
            return lockedDisplayTimeout;
        case "dim":
            return dimDuration;
        default:
            return 0;
        }
    }
    function effectiveDisplayOffTimeout() {
        var lockTimeout = currentLockTimeout();
        var displayTimeout = currentDisplayTimeout();
        if (lockTimeout > 0 && (displayTimeout === 0 || lockTimeout < displayTimeout))
            return lockedDisplayTimeout > 0 ? lockTimeout + lockedDisplayTimeout : 0;
        return displayTimeout;
    }
    function normalizeDuration(value, fallback) {
        var number = Number(value);
        if (!isFinite(number))
            return fallback;
        return Math.max(0, Math.min(86400, Math.round(number)));
    }
    function openDurationPopup(sourceItem, target) {
        if (durationPopupOpen && durationPopupTarget === target) {
            durationPopupOpen = false;
            return;
        }

        sleepPopupOpen = false;
        durationPopupTarget = target;
        var position = sourceItem.mapToItem(root, 0, 0);
        var popupHeight = durationPopup.preferredHeight;
        var belowY = position.y + sourceItem.height + 8;
        durationPopupOpenAbove = belowY + popupHeight > height;
        durationPopupY = durationPopupOpenAbove ? position.y - popupHeight - 8 : belowY;
        durationPopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        durationPopupOpen = true;
    }
    function openSleepPopup(sourceItem) {
        if (sleepPopupOpen) {
            sleepPopupOpen = false;
            return;
        }

        durationPopupOpen = false;
        var position = sourceItem.mapToItem(root, 0, 0);
        var visibleOptions = 0;
        for (var i = 0; i < sleepOptions.length; ++i) {
            if (sleepOptionVisible(sleepOptions[i]))
                visibleOptions += 1;
        }
        var popupHeight = visibleOptions * 44 + 16;
        var belowY = position.y + sourceItem.height + 8;
        sleepPopupOpenAbove = belowY + popupHeight > height;
        sleepPopupY = sleepPopupOpenAbove ? position.y - popupHeight - 8 : belowY;
        sleepPopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        sleepPopupOpen = true;
    }
    function orderWarningText() {
        if (currentLockTimeout() === 0)
            return qsTr("Automatic lock is disabled; waking the display may return to an unlocked session.");
        return qsTr("Display off occurs before lock; waking the display may return to an unlocked session.");
    }
    function profileLabel() {
        if (!separatePowerProfiles)
            return qsTr("Shared policy");
        return selectedProfile === "battery" ? qsTr("Battery policy") : qsTr("Plugged-in policy");
    }
    function resetPage() {
        syncFields();
    }
    function selectDuration(seconds) {
        var value = normalizeDuration(seconds, 0);
        switch (durationPopupTarget) {
        case "lock":
            if (selectedProfile === "battery")
                batteryLockTimeout = value;
            else
                acLockTimeout = value;
            break;
        case "display":
            if (selectedProfile === "battery")
                batteryDisplayTimeout = value;
            else
                acDisplayTimeout = value;
            break;
        case "sleep":
            if (selectedProfile === "battery")
                batterySuspendTimeout = value;
            else
                acSuspendTimeout = value;
            break;
        case "locked-display":
            lockedDisplayTimeout = value;
            break;
        case "dim":
            dimDuration = Math.min(30, value);
            break;
        }
        durationPopupOpen = false;
    }
    function selectSleepAction(item) {
        if (!item)
            return;

        var action = String(item.value || "none");
        if (selectedProfile === "battery")
            batterySleepAction = action;
        else
            acSleepAction = action;
        sleepPopupOpen = false;
    }
    function sleepActionLabel(action) {
        switch (String(action || "none")) {
        case "suspend":
            return qsTr("Suspend");
        case "suspend-then-hibernate":
            return qsTr("Suspend, then hibernate");
        case "hibernate":
            return qsTr("Hibernate");
        default:
            return qsTr("Do nothing");
        }
    }
    function sleepCapabilityNote() {
        if (!QuickSettingsService.sleepCapabilitiesReady)
            return qsTr("Checking sleep support…");
        if (QuickSettingsService.sleepCapabilityHibernate === "na" && QuickSettingsService.sleepCapabilitySuspendThenHibernate === "na")
            return qsTr("Hibernate is unavailable on this system");
        return qsTr("Only sleep modes supported by this system are shown");
    }
    function sleepOptionVisible(item) {
        if (!item || String(item.value) === "none")
            return true;
        return !QuickSettingsService.sleepCapabilitiesReady || QuickSettingsService.supportsSleepAction(String(item.value));
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        idleEnabled = settings.idleEnabled ?? Config.idleEnabled;
        lockBeforeSleep = settings.idleLockBeforeSleep ?? Config.idleLockBeforeSleep;
        separatePowerProfiles = settings.idleSeparatePowerProfiles ?? Config.idleSeparatePowerProfiles;
        respectInhibitors = settings.idleRespectInhibitors ?? Config.idleRespectInhibitors;
        acLockTimeout = normalizeDuration(settings.idleLockTimeout ?? Config.idleLockTimeout, 600);
        acDisplayTimeout = normalizeDuration(settings.idleDisplayTimeout ?? Config.idleDisplayTimeout, 600);
        acSuspendTimeout = normalizeDuration(settings.idleSuspendTimeout ?? Config.idleSuspendTimeout, 0);
        acSleepAction = String(settings.idleSleepAction ?? Config.idleSleepAction);
        batteryLockTimeout = normalizeDuration(settings.idleBatteryLockTimeout ?? Config.idleBatteryLockTimeout, 300);
        batteryDisplayTimeout = normalizeDuration(settings.idleBatteryDisplayTimeout ?? Config.idleBatteryDisplayTimeout, 300);
        batterySuspendTimeout = normalizeDuration(settings.idleBatterySuspendTimeout ?? Config.idleBatterySuspendTimeout, 900);
        batterySleepAction = String(settings.idleBatterySleepAction ?? Config.idleBatterySleepAction);
        lockedDisplayTimeout = normalizeDuration(settings.idleLockedDisplayTimeout ?? Config.idleLockedDisplayTimeout, 60);
        dimDuration = Math.min(30, normalizeDuration(settings.idleDimDuration ?? Config.idleDimDuration, 5));
        dimOpacity = Math.max(0.2, Math.min(0.9, Number(settings.idleDimOpacity ?? Config.idleDimOpacity)));
        caffeineAutoDisableMinutes = Math.max(0, Number(settings.caffeineAutoDisableMinutes ?? Config.caffeineAutoDisableMinutes));
        caffeineChoice.value = String(caffeineAutoDisableMinutes);
        selectedProfile = separatePowerProfiles && BatteryService.onBattery ? "battery" : "ac";
        durationPopupOpen = false;
        sleepPopupOpen = false;
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        durationPopupOpen = false;
        sleepPopupOpen = false;
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: {
        syncFields();
        QuickSettingsService.refreshSleepCapabilities();
    }

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
            iconName: "preferences-system-power-symbolic"
            note: qsTr("swayidle controls idle timing while Quickshell renders dim and lockscreen actions")
            title: qsTr("Idle policy")

            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(root.policyStatusColor, 0.1)
                implicitHeight: statusContent.implicitHeight + 22
                radius: 13

                RowLayout {
                    id: statusContent

                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 11

                    Rectangle {
                        Layout.preferredHeight: 10
                        Layout.preferredWidth: 10
                        color: root.policyStatusColor
                        radius: width / 2

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: QuickSettingsService.idlePolicyApplying

                            NumberAnimation {
                                duration: Config.animationDuration(500)
                                from: 0.35
                                to: 1
                            }
                            NumberAnimation {
                                duration: Config.animationDuration(500)
                                from: 1
                                to: 0.35
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            text: root.policyStatusTitle
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface_variant
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 12
                            text: root.policyStatusNote
                        }
                    }
                    SettingsActionButton {
                        iconName: "view-refresh-symbolic"
                        iconOnly: true
                        text: qsTr("Refresh sleep support")

                        onClicked: QuickSettingsService.refreshSleepCapabilities()
                    }
                    SettingsActionButton {
                        enabled: root.dimOpacity > 0
                        iconName: "display-brightness-symbolic"
                        iconOnly: true
                        text: qsTr("Preview dim")

                        onClicked: IdleDimService.preview(root.dimOpacity)
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: width >= 760 ? 2 : 1
                rowSpacing: 8
                uniformCellWidths: true

                SettingsToggleTile {
                    checked: root.idleEnabled
                    label: qsTr("Enable idle management")
                    note: qsTr("Caffeine temporarily pauses this policy")
                    updateCheckedInternally: false

                    onToggled: value => root.idleEnabled = value
                }
                SettingsToggleTile {
                    checked: root.separatePowerProfiles
                    enabled: root.idleEnabled
                    label: qsTr("Separate power profiles")
                    note: qsTr("Use different timers on battery and external power")
                    updateCheckedInternally: false

                    onToggled: value => {
                        root.separatePowerProfiles = value;
                        root.selectedProfile = value && BatteryService.onBattery ? "battery" : "ac";
                    }
                }
                SettingsToggleTile {
                    checked: root.lockBeforeSleep
                    enabled: root.idleEnabled
                    label: qsTr("Lock before sleep")
                    note: qsTr("Keeps password and face authentication ready on resume")
                    updateCheckedInternally: false

                    onToggled: value => root.lockBeforeSleep = value
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            enabled: root.idleEnabled
            iconName: "preferences-system-time-symbolic"
            note: qsTr("Choose when the session locks, powers off the display, and sleeps")
            title: qsTr("Idle schedule")

            SettingsSegmentedControl {
                Layout.fillWidth: true
                accessibleName: qsTr("Power profile")
                minimumSegmentWidth: 150
                options: [
                    {
                        "label": qsTr("Battery"),
                        "value": "battery"
                    },
                    {
                        "label": qsTr("Plugged in"),
                        "value": "ac"
                    }
                ]
                selectedValue: root.selectedProfile
                visible: root.separatePowerProfiles

                onSelected: value => {
                    root.durationPopupOpen = false;
                    root.sleepPopupOpen = false;
                    root.selectedProfile = value;
                }
            }
            IdlePolicyTimeline {
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                dimDuration: root.dimDuration
                displayTimeout: root.effectiveDisplayOffTimeout()
                lockTimeout: root.currentLockTimeout()
                profileLabel: root.profileLabel()
                sleepAction: root.currentSleepAction()
                sleepTimeout: root.currentSuspendTimeout()
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.error, 0.09)
                implicitHeight: orderWarning.implicitHeight + 20
                radius: 11
                visible: root.currentDisplayTimeout() > 0 && (root.currentLockTimeout() === 0 || root.currentDisplayTimeout() < root.currentLockTimeout())

                Text {
                    id: orderWarning

                    anchors.fill: parent
                    anchors.margins: 10
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.orderWarningText()
                    wrapMode: Text.Wrap
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 14
                columns: width >= 760 ? 2 : 1
                rowSpacing: 4
                uniformCellWidths: true

                SettingsSelectRow {
                    accentColor: Config.md3.secondary
                    label: qsTr("Lock after")
                    note: qsTr("Never leaves the session unlocked")
                    valueText: root.durationLabel(root.currentLockTimeout())

                    onClicked: sourceItem => root.openDurationPopup(sourceItem, "lock")
                }
                SettingsSelectRow {
                    accentColor: Config.md3.secondary
                    label: qsTr("Display off after")
                    note: qsTr("Used while the session is still unlocked")
                    valueText: root.durationLabel(root.currentDisplayTimeout())

                    onClicked: sourceItem => root.openDurationPopup(sourceItem, "display")
                }
                SettingsSelectRow {
                    accentColor: Config.md3.secondary
                    label: qsTr("Sleep action")
                    note: root.sleepCapabilityNote()
                    valueText: root.sleepActionLabel(root.currentSleepAction())

                    onClicked: sourceItem => root.openSleepPopup(sourceItem)
                }
                SettingsSelectRow {
                    accentColor: Config.md3.secondary
                    enabled: root.currentSleepAction() !== "none"
                    label: qsTr("Sleep after")
                    note: qsTr("Countdown starts from the last user input")
                    valueText: root.durationLabel(root.currentSuspendTimeout())

                    onClicked: sourceItem => root.openDurationPopup(sourceItem, "sleep")
                }
            }
            SettingsSelectRow {
                accentColor: Config.md3.secondary
                label: qsTr("Display off while locked")
                note: qsTr("Starts whenever the lock screen appears; shared by both profiles")
                valueText: root.durationLabel(root.lockedDisplayTimeout)

                onClicked: sourceItem => root.openDurationPopup(sourceItem, "locked-display")
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.tertiary
            compact: true
            enabled: root.idleEnabled
            iconName: "display-brightness-symbolic"
            note: qsTr("Tune the transition before display-off and how applications may keep the session awake")
            title: qsTr("Dimming & activity")

            SettingsSelectRow {
                accentColor: Config.md3.tertiary
                label: qsTr("Dim before display off")
                note: qsTr("Choose Never to disable the dim transition")
                valueText: root.durationLabel(root.dimDuration)

                onClicked: sourceItem => root.openDurationPopup(sourceItem, "dim")
            }
            SettingsSliderRow {
                accentColor: Config.md3.tertiary
                enabled: root.dimDuration > 0
                from: 0.2
                label: qsTr("Dim strength")
                note: qsTr("Controls the darkness of the overlay")
                stepSize: 0.05
                to: 0.9
                value: root.dimOpacity
                valueText: qsTr("%1%").arg(Math.round(root.dimOpacity * 100))

                onEdited: value => root.dimOpacity = Math.round(value * 100) / 100
            }
            SettingsToggleTile {
                checked: root.respectInhibitors
                label: qsTr("Allow applications to keep the session awake")
                note: qsTr("Media playback, presentations, and screen sharing may delay lock, display-off, and sleep")
                updateCheckedInternally: false

                onToggled: value => root.respectInhibitors = value
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.primary
            compact: true
            iconName: "media-playback-pause-symbolic"
            note: QuickSettingsService.caffeineEnabled ? root.policyStatusNote : qsTr("Choose how long the quick Caffeine toggle remains active")
            title: qsTr("Caffeine")

            SettingsChoiceRow {
                id: caffeineChoice

                Layout.fillWidth: true
                label: qsTr("Automatic timeout")
                options: [
                    {
                        "label": qsTr("Until disabled"),
                        "value": "0"
                    },
                    {
                        "label": qsTr("30 min"),
                        "value": "30"
                    },
                    {
                        "label": qsTr("1 hour"),
                        "value": "60"
                    },
                    {
                        "label": qsTr("2 hours"),
                        "value": "120"
                    }
                ]

                onSelected: value => {
                    root.caffeineAutoDisableMinutes = Number(value);
                    caffeineChoice.value = String(value);
                }
            }
        }
    }
    SettingsDurationPopup {
        id: durationPopup

        accentColor: Config.md3.secondary
        anchors.fill: parent
        currentValue: root.durationPopupValue()
        maximumSeconds: root.durationPopupTarget === "dim" ? 30 : 86400
        openAbove: root.durationPopupOpenAbove
        opened: root.durationPopupOpen
        popupY: root.durationPopupY
        presets: root.durationPopupTarget === "dim" ? root.dimPresets : root.durationPresets
        rightMargin: root.durationPopupRightMargin
        z: 40

        onDismissed: root.durationPopupOpen = false
        onSelected: seconds => root.selectDuration(seconds)
    }
    SelectPopup {
        accentColor: Config.md3.secondary
        anchors.fill: parent
        itemActive: item => item && String(item.value) === root.currentSleepAction()
        itemVisible: item => root.sleepOptionVisible(item)
        model: root.sleepOptions
        openAbove: root.sleepPopupOpenAbove
        opened: root.sleepPopupOpen
        popupWidth: 280
        popupY: root.sleepPopupY
        rightMargin: root.sleepPopupRightMargin
        rowHeight: 44
        z: 40

        onDismissed: root.sleepPopupOpen = false
        onItemSelected: item => root.selectSleepAction(item)
    }
}
