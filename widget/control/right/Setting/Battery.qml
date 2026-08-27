import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets
import "../../../bar" as BarComponents
import "../../../../"
import "../../../../components"
import "../../../../service"

Item {
    id: root

    readonly property string activeProfile: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "balanced";
        }
    }
    readonly property bool autoCpufreqAvailable: BatteryService.autoCpufreqAvailable
    readonly property int batteryPercentage: Math.max(0, BatteryService.batteryPercentage)
    readonly property string batteryStatusText: {
        if (!UPower.displayDevice)
            return qsTr("Unavailable");

        var state = UPower.displayDevice.state;
        if (state === UPowerDeviceState.Charging) {
            var timeToFull = UPower.displayDevice.timeToFull;
            if (timeToFull > 0)
                return qsTr("%1h %2m to full").arg(Math.floor(timeToFull / 3600)).arg(Math.floor((timeToFull % 3600) / 60));

            return qsTr("Charging");
        }
        if (state === UPowerDeviceState.Discharging) {
            var timeToEmpty = UPower.displayDevice.timeToEmpty;
            if (timeToEmpty > 0)
                return qsTr("%1h %2m remaining").arg(Math.floor(timeToEmpty / 3600)).arg(Math.floor((timeToEmpty % 3600) / 60));

            return qsTr("On battery");
        }
        if (state === UPowerDeviceState.FullyCharged)
            return qsTr("Fully charged");

        return UPower.onBattery ? qsTr("On battery") : qsTr("Plugged in");
    }
    property string criticalThresholdText: String(BatteryService.criticalBatteryThreshold)
    property bool customApplyPending: false
    property bool customEditing: false
    property string customEndText: String(BatteryService.chargeEndThreshold)
    property string customStartText: String(BatteryService.chargeStartThreshold)
    readonly property bool customThresholdsValid: /^\d{1,3}$/.test(customStartText) && /^\d{1,3}$/.test(customEndText) && Number(customStartText) >= 0 && Number(customStartText) < Number(customEndText) && Number(customEndText) <= 100
    property string lowThresholdText: String(BatteryService.lowBatteryThreshold)
    readonly property bool policyThresholdsValid: /^\d{1,2}$/.test(lowThresholdText) && /^\d{1,2}$/.test(criticalThresholdText) && Number(lowThresholdText) >= 5 && Number(lowThresholdText) <= 50 && Number(criticalThresholdText) >= 1 && Number(criticalThresholdText) < Number(lowThresholdText)
    readonly property var profilePolicyOptions: [
        {
            "label": qsTr("Don't change"),
            "value": "unchanged"
        },
        {
            "label": qsTr("Power Saver"),
            "value": "power-saver"
        },
        {
            "label": qsTr("Balanced"),
            "value": "balanced"
        },
        {
            "label": qsTr("Performance"),
            "value": "performance"
        }
    ]
    property bool profilePopupOpen: false
    property bool profilePopupOpenAbove: false
    property real profilePopupRightMargin: 12
    property string profilePopupTarget: ""
    property real profilePopupY: 0

    function applyCustomThresholds() {
        if (!customThresholdsValid)
            return;

        if (BatteryService.setChargeThresholds(Number(customStartText), Number(customEndText)))
            customApplyPending = true;
    }
    function applyPolicyThresholds() {
        if (!policyThresholdsValid)
            return;

        BatteryService.setLowBatteryThreshold(Number(lowThresholdText));
        BatteryService.setCriticalBatteryThreshold(Number(criticalThresholdText));
    }
    function openProfilePopup(sourceItem, target) {
        if (profilePopupOpen && profilePopupTarget === target) {
            profilePopupOpen = false;
            return;
        }

        var position = sourceItem.mapToItem(root, 0, 0);
        var popupHeight = profilePolicyOptions.length * 44 + 16;
        var belowY = position.y + sourceItem.height + 8;
        profilePopupTarget = target;
        profilePopupOpenAbove = belowY + popupHeight > height;
        profilePopupY = profilePopupOpenAbove ? position.y - popupHeight - 8 : belowY;
        profilePopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        profilePopupOpen = true;
    }
    function profilePolicyLabel(profile) {
        switch (profile) {
        case "power-saver":
            return qsTr("Power Saver");
        case "balanced":
            return qsTr("Balanced");
        case "performance":
            return qsTr("Performance");
        default:
            return qsTr("Don't change");
        }
    }
    function profilePolicyValue() {
        return profilePopupTarget === "plugged-in" ? BatteryService.pluggedInPowerProfile : BatteryService.batteryPowerProfile;
    }
    function selectProfilePolicy(item) {
        if (!item)
            return;

        if (profilePopupTarget === "plugged-in")
            BatteryService.setPluggedInPowerProfile(String(item.value));
        else
            BatteryService.setBatteryPowerProfile(String(item.value));

        profilePopupOpen = false;
    }
    function syncCustomThresholds() {
        if (!customEditing && !customStartField.inputItem.activeFocus && !customEndField.inputItem.activeFocus) {
            customStartText = String(BatteryService.chargeStartThreshold);
            customEndText = String(BatteryService.chargeEndThreshold);
            customStartField.text = customStartText;
            customEndField.text = customEndText;
        }
    }
    function syncPolicyThresholds() {
        if (!lowThresholdField.inputItem.activeFocus) {
            lowThresholdText = String(BatteryService.lowBatteryThreshold);
            lowThresholdField.text = lowThresholdText;
        }
        if (!criticalThresholdField.inputItem.activeFocus) {
            criticalThresholdText = String(BatteryService.criticalBatteryThreshold);
            criticalThresholdField.text = criticalThresholdText;
        }
    }
    function updateServiceActivity() {
        BatteryService.active = controlRightWindow.active && root.visible;
    }

    anchors.fill: parent

    Component.onCompleted: updateServiceActivity()
    Component.onDestruction: BatteryService.active = false
    onVisibleChanged: {
        updateServiceActivity();
        if (!visible)
            profilePopupOpen = false;
    }

    SettingsPageTransition {
        panelActive: controlRightWindow.active
        targetItem: root
    }
    Connections {
        function onActiveChanged() {
            root.updateServiceActivity();
        }

        target: controlRightWindow
    }
    Connections {
        function onChargeCommandBusyChanged() {
            if (BatteryService.chargeCommandBusy || !root.customApplyPending)
                return;

            if (BatteryService.chargeCommandError === "")
                root.customEditing = false;

            root.customApplyPending = false;
            root.syncCustomThresholds();
        }
        function onChargeEndThresholdChanged() {
            root.syncCustomThresholds();
        }
        function onChargeStartThresholdChanged() {
            root.syncCustomThresholds();
        }
        function onCriticalBatteryThresholdChanged() {
            root.syncPolicyThresholds();
        }
        function onLowBatteryThresholdChanged() {
            root.syncPolicyThresholds();
        }

        target: BatteryService
    }
    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: contentLayout.implicitHeight + 24
        contentWidth: width
        interactive: !root.profilePopupOpen

        ColumnLayout {
            id: contentLayout

            spacing: 24
            width: parent.width

            SettingsSectionCard {
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                color: controlRightWindow.sectionCardColor
                compact: true
                radius: 14
                showHeader: false

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    spacing: 16

                    Item {
                        Layout.preferredHeight: 62
                        Layout.preferredWidth: 86

                        BarComponents.Battery {
                            id: batteryVisual

                            Accessible.ignored: true
                            anchors.centerIn: parent
                            scale: 1.65
                            showReadout: false
                        }
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.55)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            text: BatteryService.deviceName
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            text: root.batteryStatusText
                        }
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 5

                        Text {
                            Layout.alignment: Qt.AlignRight
                            color: batteryVisual.batteryColor
                            font.family: Config.fontName
                            font.pixelSize: 31
                            font.weight: Font.Black
                            horizontalAlignment: Text.AlignRight
                            text: qsTr("%1%").arg(root.batteryPercentage)
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: powerSourceContent.implicitWidth + 18
                            border.color: Config.alpha(batteryVisual.batteryColor, 0.2)
                            border.width: 1
                            color: Config.alpha(batteryVisual.batteryColor, 0.09)
                            radius: 9

                            Row {
                                id: powerSourceContent

                                anchors.centerIn: parent
                                spacing: 6

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: batteryVisual.batteryColor
                                    height: 6
                                    radius: 3
                                    width: 6
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Config.alpha(Config.md3.on_surface, 0.68)
                                    font.family: Config.fontName
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    text: UPower.onBattery ? qsTr("Battery power") : qsTr("External power")
                                }
                            }
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: 2
                    rowSpacing: 10

                    MetricTile {
                        accentColor: Config.md3.primary
                        label: qsTr("Full / design")
                        valueText: qsTr("%1 / %2").arg(BatteryService.fullEnergy).arg(BatteryService.designEnergy)
                    }
                    MetricTile {
                        accentColor: BatteryService.healthNumeric >= 0 && BatteryService.healthNumeric < 75 ? Config.md3.error : Config.md3.secondary
                        label: qsTr("Battery health")
                        valueText: BatteryService.health
                    }
                    MetricTile {
                        accentColor: Config.md3.tertiary
                        label: qsTr("Power rate")
                        valueText: BatteryService.powerDraw
                    }
                    MetricTile {
                        accentColor: Config.md3.secondary
                        label: qsTr("Temperature")
                        valueText: BatteryService.temperature
                    }
                    MetricTile {
                        label: qsTr("Charge cycles")
                        valueText: BatteryService.cycleCount
                    }
                    MetricTile {
                        label: qsTr("Voltage")
                        valueText: BatteryService.voltage
                    }
                    MetricTile {
                        Layout.columnSpan: 2
                        accentColor: Config.md3.tertiary
                        label: qsTr("GPU power")
                        valueText: BatteryService.gpuPower
                        visible: BatteryService.gpuPower !== "N/A"
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: healthWarningContent.implicitHeight + 24
                    border.color: Config.alpha(Config.md3.error, 0.28)
                    border.width: 1
                    color: Config.alpha(Config.md3.error_container, 0.76)
                    radius: 12
                    visible: BatteryService.healthNumeric >= 0 && BatteryService.healthNumeric < 75

                    RowLayout {
                        id: healthWarningContent

                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 11

                        IconImage {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: 20
                            layer.enabled: true
                            source: Quickshell.iconPath("dialog-warning-symbolic")

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_error_container
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_error_container
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                text: qsTr("Battery health is reduced")
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.alpha(Config.md3.on_error_container, 0.76)
                                font.family: Config.fontName
                                font.pixelSize: 12
                                text: qsTr("Usable capacity is %1 of the original design capacity.").arg(BatteryService.health)
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: degradationContent.implicitHeight + 24
                    border.color: Config.alpha(Config.md3.tertiary, 0.3)
                    border.width: 1
                    color: Config.alpha(Config.md3.tertiary_container, 0.72)
                    radius: 12
                    visible: BatteryService.performanceDegraded

                    RowLayout {
                        id: degradationContent

                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 11

                        IconImage {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: 20
                            layer.enabled: true
                            source: Quickshell.iconPath("speedometer-symbolic")

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_tertiary_container
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_tertiary_container
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            text: BatteryService.performanceDegradationText
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
            SettingsSectionCard {
                accentColor: Config.md3.tertiary
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                color: controlRightWindow.sectionCardColor
                compact: true
                iconName: "power-profile-balanced-symbolic"
                note: qsTr("Choose how performance changes with the power source")
                radius: 14
                title: qsTr("Power profiles & saving")
                visible: BatteryService.powerProfilesAvailable

                SettingsChoiceRow {
                    Layout.fillWidth: true
                    label: qsTr("Power mode")
                    note: qsTr("Choose the current performance and energy profile")
                    options: [
                        {
                            "label": qsTr("Saver"),
                            "value": "power-saver"
                        },
                        {
                            "label": qsTr("Balanced"),
                            "value": "balanced"
                        },
                        {
                            "label": qsTr("Performance"),
                            "value": "performance"
                        }
                    ]
                    value: root.activeProfile

                    onSelected: value => {
                        return BatteryService.selectPowerProfile(value);
                    }
                }
                SettingsToggleTile {
                    checked: BatteryService.autoPowerSaverEnabled
                    label: qsTr("Automatic Power Saver")
                    note: qsTr("Use Power Saver when battery reaches %1% or lower").arg(BatteryService.lowBatteryThreshold)
                    updateCheckedInternally: false

                    onToggled: checked => {
                        return BatteryService.autoPowerSaverEnabled = checked;
                    }
                }
                SettingsSelectRow {
                    accentColor: Config.md3.tertiary
                    label: qsTr("Profile when plugged in")
                    note: qsTr("Apply after connecting external power")
                    valueText: root.profilePolicyLabel(BatteryService.pluggedInPowerProfile)

                    onClicked: sourceItem => root.openProfilePopup(sourceItem, "plugged-in")
                }
                SettingsSelectRow {
                    accentColor: Config.md3.tertiary
                    label: qsTr("Profile on battery")
                    note: qsTr("Apply after disconnecting external power")
                    valueText: root.profilePolicyLabel(BatteryService.batteryPowerProfile)

                    onClicked: sourceItem => root.openProfilePopup(sourceItem, "battery")
                }
                SettingsToggleTile {
                    checked: BatteryService.batteryAwareEnabled
                    enabled: BatteryService.batteryAwareAvailable && !BatteryService.batteryAwareBusy
                    label: qsTr("Battery-aware performance")
                    note: qsTr("Let power-profiles-daemon adapt supported actions to battery state")
                    updateCheckedInternally: false

                    onToggled: checked => {
                        return BatteryService.setBatteryAwareEnabled(checked);
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: BatteryService.batteryAwareError
                    visible: text !== ""
                    wrapMode: Text.Wrap
                }
            }
            SettingsSectionCard {
                accentColor: Config.md3.primary
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                color: controlRightWindow.sectionCardColor
                compact: true
                iconName: "battery-good-symbolic"
                note: BatteryService.chargeThresholdSupported ? qsTr("Current limits: %1% → %2%").arg(BatteryService.chargeStartThreshold).arg(BatteryService.chargeEndThreshold) : qsTr("Charging thresholds are not supported by this battery")
                radius: 14
                title: qsTr("Charging limits")

                SettingsChoiceRow {
                    Layout.fillWidth: true
                    enabled: BatteryService.chargeThresholdSupported && !BatteryService.chargeCommandBusy
                    label: qsTr("Charging preset")
                    note: qsTr("Lower limits reduce time spent at a high state of charge")
                    options: [
                        {
                            "label": qsTr("55→60"),
                            "value": "conservation"
                        },
                        {
                            "label": qsTr("75→80"),
                            "value": "preserve"
                        },
                        {
                            "label": qsTr("50→100"),
                            "value": "maximize"
                        },
                        {
                            "label": qsTr("Custom"),
                            "value": "custom"
                        }
                    ]
                    value: root.customEditing ? "custom" : BatteryService.chargeMode

                    onSelected: value => {
                        if (value === "custom") {
                            root.customEditing = true;
                            root.customStartText = String(BatteryService.chargeStartThreshold);
                            root.customEndText = String(BatteryService.chargeEndThreshold);
                            customStartField.text = root.customStartText;
                            customEndField.text = root.customEndText;
                        } else {
                            root.customEditing = false;
                            BatteryService.setChargeMode(value);
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: root.customEditing || BatteryService.chargeMode === "custom"

                    SettingsTextField {
                        id: customStartField

                        Layout.fillWidth: true
                        fieldHeight: 42
                        inputItem.inputMethodHints: Qt.ImhDigitsOnly
                        label: qsTr("Start")
                        placeholder: qsTr("0–99")
                        text: root.customStartText

                        inputItem.validator: IntValidator {
                            bottom: 0
                            top: 99
                        }

                        onTextChanged: root.customStartText = text
                    }
                    SettingsTextField {
                        id: customEndField

                        Layout.fillWidth: true
                        fieldHeight: 42
                        inputItem.inputMethodHints: Qt.ImhDigitsOnly
                        label: qsTr("Stop")
                        placeholder: qsTr("1–100")
                        text: root.customEndText

                        inputItem.validator: IntValidator {
                            bottom: 1
                            top: 100
                        }

                        onTextChanged: root.customEndText = text
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        enabled: root.customThresholdsValid && !BatteryService.chargeCommandBusy
                        iconName: "emblem-ok-symbolic"
                        iconOnly: true
                        primary: true
                        text: qsTr("Apply custom limits")

                        onClicked: root.applyCustomThresholds()
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: onceContent.implicitHeight + 22
                    color: Config.alpha(Config.md3.primary, 0.08)
                    radius: 12

                    RowLayout {
                        id: onceContent

                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                text: BatteryService.fullChargeOnceActive ? qsTr("Temporary full charge is active") : qsTr("Need maximum runtime?")
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.alpha(Config.md3.on_surface, 0.48)
                                font.family: Config.fontName
                                font.pixelSize: 12
                                text: BatteryService.fullChargeOnceActive ? qsTr("Previous limits restore automatically after unplugging") : UPower.onBattery ? qsTr("Connect the charger to enable a one-time full charge") : qsTr("Charge to 100%, then restore the current limits after unplugging")
                                wrapMode: Text.Wrap
                            }
                        }
                        SettingsActionButton {
                            enabled: BatteryService.chargeThresholdSupported && !BatteryService.chargeCommandBusy && (BatteryService.fullChargeOnceActive || !UPower.onBattery)
                            iconName: BatteryService.fullChargeOnceActive ? "edit-undo-symbolic" : "battery-full-charging-symbolic"
                            iconOnly: true
                            text: BatteryService.fullChargeOnceActive ? qsTr("Restore limits now") : qsTr("Charge to 100% once")

                            onClicked: {
                                if (BatteryService.fullChargeOnceActive)
                                    BatteryService.restoreFullChargeOnce();
                                else
                                    BatteryService.startFullChargeOnce();
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: BatteryService.chargeCommandError
                    visible: text !== ""
                    wrapMode: Text.Wrap
                }
            }
            SettingsSectionCard {
                accentColor: Config.md3.error
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                color: controlRightWindow.sectionCardColor
                compact: true
                iconName: "battery-caution-symbolic"
                note: qsTr("Optional actions when the remaining charge becomes low")
                radius: 14
                title: qsTr("Low battery automation")

                SettingsToggleTile {
                    checked: BatteryService.lowBatteryNotificationEnabled
                    label: qsTr("Low battery notification")
                    note: qsTr("Show one notification when the low threshold is crossed")
                    updateCheckedInternally: false

                    onToggled: checked => {
                        return BatteryService.lowBatteryNotificationEnabled = checked;
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingsTextField {
                        id: lowThresholdField

                        Layout.fillWidth: true
                        fieldHeight: 42
                        inputItem.inputMethodHints: Qt.ImhDigitsOnly
                        label: qsTr("Low at (%)")
                        placeholder: qsTr("5–50")
                        text: root.lowThresholdText

                        inputItem.validator: IntValidator {
                            bottom: 5
                            top: 50
                        }

                        onTextChanged: root.lowThresholdText = text
                    }
                    SettingsTextField {
                        id: criticalThresholdField

                        Layout.fillWidth: true
                        fieldHeight: 42
                        inputItem.inputMethodHints: Qt.ImhDigitsOnly
                        label: qsTr("Critical at (%)")
                        placeholder: qsTr("1–49")
                        text: root.criticalThresholdText

                        inputItem.validator: IntValidator {
                            bottom: 1
                            top: 49
                        }

                        onTextChanged: root.criticalThresholdText = text
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        enabled: root.policyThresholdsValid
                        iconName: "document-save-symbolic"
                        iconOnly: true
                        primary: true
                        text: qsTr("Save battery thresholds")

                        onClicked: root.applyPolicyThresholds()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.policyThresholdsValid ? "" : qsTr("Critical level must be lower than the low-battery level")
                    visible: text !== ""
                    wrapMode: Text.Wrap
                }
                SettingsChoiceRow {
                    Layout.fillWidth: true
                    label: qsTr("Critical action")
                    note: qsTr("No system power action is performed unless you select one")
                    options: [
                        {
                            "label": qsTr("None"),
                            "value": "none"
                        },
                        {
                            "label": qsTr("Suspend"),
                            "value": "suspend"
                        },
                        {
                            "label": qsTr("Hibernate"),
                            "value": "hibernate"
                        }
                    ]
                    value: BatteryService.criticalBatteryAction

                    onSelected: value => {
                        return BatteryService.setCriticalBatteryAction(value);
                    }
                }
            }
            SettingsSectionCard {
                accentColor: Config.md3.secondary
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                color: controlRightWindow.sectionCardColor
                compact: true
                iconName: "am-cpu-symbolic"
                note: qsTr("Optional auto-cpufreq overrides")
                radius: 14
                title: qsTr("CPU optimization")
                visible: root.autoCpufreqAvailable

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        text: qsTr("Current governor")
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        text: BatteryService.currentGovernor
                    }
                }
                SettingsChoiceRow {
                    Layout.fillWidth: true
                    label: qsTr("Governor override")
                    options: [
                        {
                            "label": qsTr("Default"),
                            "value": "default"
                        },
                        {
                            "label": qsTr("Powersave"),
                            "value": "powersave"
                        },
                        {
                            "label": qsTr("Performance"),
                            "value": "performance"
                        }
                    ]
                    value: BatteryService.governorOverride

                    onSelected: value => {
                        BatteryService.runCommand("pkexec auto-cpufreq --force " + (value === "default" ? "reset" : value));
                        BatteryService.governorOverride = value;
                    }
                }
                SettingsChoiceRow {
                    Layout.fillWidth: true
                    label: qsTr("CPU turbo override")
                    options: [
                        {
                            "label": qsTr("Auto"),
                            "value": "auto"
                        },
                        {
                            "label": qsTr("Never"),
                            "value": "never"
                        },
                        {
                            "label": qsTr("Always"),
                            "value": "always"
                        }
                    ]
                    value: BatteryService.turboOverride

                    onSelected: value => {
                        BatteryService.runCommand("pkexec auto-cpufreq --turbo " + value);
                        BatteryService.turboOverride = value;
                    }
                }
            }
        }
    }
    SelectPopup {
        accentColor: Config.md3.tertiary
        anchors.fill: parent
        itemActive: item => item && String(item.value) === root.profilePolicyValue()
        model: root.profilePolicyOptions
        openAbove: root.profilePopupOpenAbove
        opened: root.profilePopupOpen
        popupWidth: 224
        popupY: root.profilePopupY
        rightMargin: root.profilePopupRightMargin
        rowHeight: 44

        onDismissed: root.profilePopupOpen = false
        onItemSelected: item => root.selectProfilePolicy(item)
    }

    component MetricTile: Rectangle {
        id: metric

        property color accentColor: Config.md3.primary
        property string label: ""
        property string valueText: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 64
        color: Config.alpha(Config.md3.on_surface, 0.04)
        radius: 12

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 3

            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.48)
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.Medium
                text: metric.label
            }
            Text {
                Layout.fillWidth: true
                color: metric.accentColor
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 15
                font.weight: Font.Bold
                text: metric.valueText
            }
        }
    }
}
