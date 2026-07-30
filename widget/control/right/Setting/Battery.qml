import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.UPower
import "../../../../"
import "../../../../service"
import "../../../../components"

Item {
    id: batteryPageRoot

    readonly property string activeProfile: BatteryService.activeProfile
    readonly property bool autoCpufreqAvailable: BatteryService.autoCpufreqAvailable
    readonly property real batPercent: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property string batStatusText: {
        if (!UPower.displayDevice)
            return "Unknown";
        var state = UPower.displayDevice.state;

        if (state === UPowerDeviceState.Charging) {
            var timeToFull = UPower.displayDevice.timeToFull;
            if (timeToFull > 0) {
                var fh = Math.floor(timeToFull / 3600);
                var fm = Math.floor((timeToFull % 3600) / 60);
                return fh + "h " + fm + "m to full";
            }
            return "Charging";
        } else if (state === UPowerDeviceState.Discharging) {
            var timeToEmpty = UPower.displayDevice.timeToEmpty;
            if (timeToEmpty > 0) {
                var eh = Math.floor(timeToEmpty / 3600);
                var em = Math.floor((timeToEmpty % 3600) / 60);
                return eh + "h " + em + "m remaining";
            }
            return "Discharging";
        } else if (state === UPowerDeviceState.FullyCharged) {
            return "Full";
        }
        return "Unknown";
    }
    property bool chargeDropOpen: false
    readonly property string chargeMode: BatteryService.chargeMode
    readonly property string currentGovernor: BatteryService.currentGovernor
    readonly property string cycleCountVal: BatteryService.cycleCount
    readonly property string designEnergyVal: BatteryService.designEnergy
    readonly property string deviceNameVal: BatteryService.deviceName
    readonly property string governorOverride: BatteryService.governorOverride
    readonly property string gpuPower: BatteryService.gpuPower
    readonly property string healthVal: BatteryService.health

    // Popup properties
    property var popupModel: []
    property bool popupOpen: false
    property bool popupOpenAbove: false
    property string popupType: "power"
    property real popupWidth: 0
    property real popupX: 0
    property real popupY: 0
    readonly property string powerDrawVal: BatteryService.powerDraw
    property bool powerDropOpen: false
    readonly property bool performanceDegraded: BatteryService.performanceDegraded
    readonly property string performanceDegradationText: BatteryService.performanceDegradationText
    readonly property bool powerProfilesAvailable: BatteryService.powerProfilesAvailable
    readonly property string tempVal: BatteryService.temperature
    readonly property string turboOverride: BatteryService.turboOverride
    readonly property string voltageVal: BatteryService.voltage

    function runCommand(command) {
        BatteryService.runCommand(command);
    }
    function updateServiceActivity() {
        BatteryService.active = controlRightWindow.active && batteryPageRoot.visible;
    }

    anchors.fill: parent

    Component.onCompleted: updateServiceActivity()
    Component.onDestruction: BatteryService.active = false
    onVisibleChanged: updateServiceActivity()

    SettingsPageTransition {
        panelActive: controlRightWindow.active
        targetItem: batteryPageRoot
    }
    Connections {
        function onActiveChanged() {
            batteryPageRoot.updateServiceActivity();
        }

        target: controlRightWindow
    }
    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: contentLayout.implicitHeight
        contentWidth: width
        interactive: !batteryPageRoot.popupOpen

        ColumnLayout {
            id: contentLayout

            spacing: 20
            width: parent.width

            // Battery Info Card - one large card containing everything
            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.on_surface, 0.06)
                border.width: 1
                color: Config.md3.surface_container
                implicitHeight: batteryInfoColumn.implicitHeight + 32
                radius: 12

                ColumnLayout {
                    id: batteryInfoColumn

                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Header: "Battery Information" + model name
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            text: "Battery Information"
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.5)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: batteryPageRoot.deviceNameVal
                        }
                    }

                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.06)
                        height: 1
                    }

                    // Status + Percentage row
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: batteryPageRoot.batStatusText
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            text: batteryPageRoot.batPercent + "%"
                        }
                    }

                    // Energy bar
                    Rectangle {
                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.08)
                        height: 8
                        radius: 15

                        Rectangle {
                            color: {
                                var p = batteryPageRoot.batPercent;
                                if (p >= 100)
                                    return Config.md3.secondary;
                                if (p >= 80)
                                    return Config.md3.primary;
                                if (p >= 20)
                                    return Config.md3.tertiary;
                                return Config.md3.error;
                            }
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * (Math.min(Math.max(batteryPageRoot.batPercent, 0), 100) / 100)
                        }
                    }

                    // Stats rows
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.6)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: "Energy Rate:"
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: batteryPageRoot.powerDrawVal
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.6)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: "Design Energy:"
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: batteryPageRoot.designEnergyVal
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.6)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: "Health:"
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: batteryPageRoot.healthVal
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.6)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: "Change cycles:"
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: batteryPageRoot.cycleCountVal
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.6)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: "Temperature:"
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: batteryPageRoot.tempVal
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.6)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: "Voltage:"
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: batteryPageRoot.voltageVal
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.6)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: "GPU Power:"
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            text: batteryPageRoot.gpuPower
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.error, 0.3)
                border.width: 1
                color: Config.md3.error_container
                implicitHeight: degradationContent.implicitHeight + 24
                radius: 12
                visible: batteryPageRoot.performanceDegraded

                RowLayout {
                    id: degradationContent

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    IconImage {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredHeight: 20
                        Layout.preferredWidth: 20
                        source: Quickshell.iconPath("dialog-warning-symbolic")

                        layer.enabled: true
                        layer.effect: ColorOverlay {
                            color: Config.md3.on_error_container
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            color: Config.md3.on_error_container
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            text: "Performance limited"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_error_container, 0.78)
                            font.family: Config.fontName
                            font.pixelSize: 13
                            text: batteryPageRoot.performanceDegradationText
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // 3. Power Mode Dropdown Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: batteryPageRoot.powerProfilesAvailable

                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: "Power Mode"
                }

                // Dropdown Card (the button selector)
                Rectangle {
                    id: powerDropCard

                    Layout.fillWidth: true
                    border.color: powerDropMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                    border.width: 1
                    color: powerDropMouse.pressed ? Config.md3.surface_container_highest : (powerDropMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container)
                    height: 74
                    radius: 12
                    scale: powerDropMouse.pressed ? 0.98 : 1.0

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 80
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                text: {
                                    var p = batteryPageRoot.activeProfile;
                                    if (p === "power-saver")
                                        return "Power Saver";
                                    if (p === "performance")
                                        return "Performance";
                                    return "Balanced";
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface_variant
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                text: {
                                    var p = batteryPageRoot.activeProfile;
                                    if (p === "power-saver")
                                        return "Lowest power consumption, highest battery life";
                                    if (p === "performance")
                                        return "Highest performance, lowest battery life";
                                    return "Default power consumption, good battery life";
                                }
                                wrapMode: Text.WordWrap
                            }
                        }
                        IconImage {
                            height: 16
                            layer.enabled: true
                            rotation: batteryPageRoot.powerDropOpen ? 180 : 0
                            source: Quickshell.iconPath("pan-down-symbolic")
                            width: 16

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface_variant
                            }
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: powerDropMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            if (batteryPageRoot.popupOpen && batteryPageRoot.popupType === "power") {
                                batteryPageRoot.popupOpen = false;
                                batteryPageRoot.powerDropOpen = false;
                            } else {
                                var globalCoords = powerDropCard.mapToItem(batteryPageRoot, 0, 0);
                                var popupHeight = 3 * 46 + 16;
                                var targetY = globalCoords.y + powerDropCard.height + 8;
                                if (targetY + popupHeight > batteryPageRoot.height) {
                                    batteryPageRoot.popupY = globalCoords.y - popupHeight - 8;
                                    batteryPageRoot.popupOpenAbove = true;
                                } else {
                                    batteryPageRoot.popupY = targetY;
                                    batteryPageRoot.popupOpenAbove = false;
                                }
                                batteryPageRoot.popupX = globalCoords.x;
                                batteryPageRoot.popupWidth = powerDropCard.width;
                                batteryPageRoot.popupModel = [
                                    {
                                        label: "Power Saver",
                                        profile: "power-saver"
                                    },
                                    {
                                        label: "Balanced",
                                        profile: "balanced"
                                    },
                                    {
                                        label: "Performance",
                                        profile: "performance"
                                    }
                                ];
                                batteryPageRoot.popupType = "power";
                                batteryPageRoot.popupOpen = true;
                                batteryPageRoot.powerDropOpen = true;
                                batteryPageRoot.chargeDropOpen = false;
                            }
                        }
                    }
                }
            }

            // 4. Battery Charging Dropdown Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: "Battery Charging"
                }

                // Dropdown Card (the button selector)
                Rectangle {
                    id: chargeDropCard

                    Layout.fillWidth: true
                    border.color: chargeDropMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                    border.width: 1
                    color: chargeDropMouse.pressed ? Config.md3.surface_container_highest : (chargeDropMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container)
                    height: 74
                    radius: 12
                    scale: chargeDropMouse.pressed ? 0.98 : 1.0

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 80
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                text: batteryPageRoot.chargeMode === "preserve" ? "Preserve Battery Health" : "Maximize Charge"
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface_variant
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                text: batteryPageRoot.chargeMode === "preserve" ? "Increases battery longevity by maintaining lower charge levels" : "Uses full battery capacity. Degrades batteries more quickly"
                                wrapMode: Text.WordWrap
                            }
                        }
                        IconImage {
                            height: 16
                            layer.enabled: true
                            rotation: batteryPageRoot.chargeDropOpen ? 180 : 0
                            source: Quickshell.iconPath("pan-down-symbolic")
                            width: 16

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface_variant
                            }
                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: chargeDropMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            if (batteryPageRoot.popupOpen && batteryPageRoot.popupType === "charge") {
                                batteryPageRoot.popupOpen = false;
                                batteryPageRoot.chargeDropOpen = false;
                            } else {
                                var globalCoords = chargeDropCard.mapToItem(batteryPageRoot, 0, 0);
                                var popupHeight = 2 * 46 + 16;
                                var targetY = globalCoords.y + chargeDropCard.height + 8;
                                if (targetY + popupHeight > batteryPageRoot.height) {
                                    batteryPageRoot.popupY = globalCoords.y - popupHeight - 8;
                                    batteryPageRoot.popupOpenAbove = true;
                                } else {
                                    batteryPageRoot.popupY = targetY;
                                    batteryPageRoot.popupOpenAbove = false;
                                }
                                batteryPageRoot.popupX = globalCoords.x;
                                batteryPageRoot.popupWidth = chargeDropCard.width;
                                batteryPageRoot.popupModel = [
                                    {
                                        label: "Maximize Charge",
                                        value: "maximize"
                                    },
                                    {
                                        label: "Preserve Battery Health",
                                        value: "preserve"
                                    }
                                ];
                                batteryPageRoot.popupType = "charge";
                                batteryPageRoot.popupOpen = true;
                                batteryPageRoot.chargeDropOpen = true;
                                batteryPageRoot.powerDropOpen = false;
                            }
                        }
                    }
                }
            }

            // 5. CPU Optimization (auto-cpufreq)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: batteryPageRoot.autoCpufreqAvailable

                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: "CPU Optimization"
                }
                Rectangle {
                    Layout.fillWidth: true
                    border.color: Config.alpha(Config.md3.on_surface, 0.06)
                    border.width: 1
                    color: Config.md3.surface_container
                    implicitHeight: autoCpufreqColumn.implicitHeight + 24
                    radius: 12

                    ColumnLayout {
                        id: autoCpufreqColumn

                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        // Row 1: Current Governor
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                text: "Current Governor"
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Text {
                                color: Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                text: batteryPageRoot.currentGovernor
                            }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.06)
                            height: 1
                        }

                        // Row 2: Governor Override
                        SettingsChoiceRow {
                            Layout.fillWidth: true
                            label: "Governor Override"
                            options: [
                                {
                                    "label": "Default",
                                    "value": "default"
                                },
                                {
                                    "label": "Powersave",
                                    "value": "powersave"
                                },
                                {
                                    "label": "Performance",
                                    "value": "performance"
                                }
                            ]
                            value: batteryPageRoot.governorOverride

                            onSelected: function (v) {
                                batteryPageRoot.runCommand("pkexec auto-cpufreq --force " + (v === "default" ? "reset" : v));
                                BatteryService.governorOverride = v;
                            }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.06)
                            height: 1
                        }

                        // Row 3: CPU Turbo Override
                        SettingsChoiceRow {
                            Layout.fillWidth: true
                            label: "CPU Turbo Override"
                            options: [
                                {
                                    "label": "Auto",
                                    "value": "auto"
                                },
                                {
                                    "label": "Never",
                                    "value": "never"
                                },
                                {
                                    "label": "Always",
                                    "value": "always"
                                }
                            ]
                            value: batteryPageRoot.turboOverride

                            onSelected: function (v) {
                                batteryPageRoot.runCommand("pkexec auto-cpufreq --turbo " + v);
                                BatteryService.turboOverride = v;
                            }
                        }
                    }
                }
            }
        }
    }
    SelectPopup {
        anchors.fill: parent
        itemActive: function (item) {
            return batteryPageRoot.popupType === "power" ? batteryPageRoot.activeProfile === item.profile : batteryPageRoot.chargeMode === item.value;
        }
        model: batteryPageRoot.popupModel
        openAbove: batteryPageRoot.popupOpenAbove
        opened: batteryPageRoot.popupOpen
        popupY: batteryPageRoot.popupY

        onDismissed: {
            batteryPageRoot.popupOpen = false;
            batteryPageRoot.powerDropOpen = false;
            batteryPageRoot.chargeDropOpen = false;
        }
        onItemSelected: item => {
            if (batteryPageRoot.popupType === "power") {
                batteryPageRoot.runCommand("powerprofilesctl set " + item.profile);
                batteryPageRoot.powerDropOpen = false;
            } else {
                BatteryService.setChargeMode(item.value);
                BatteryService.chargeMode = item.value;
                batteryPageRoot.chargeDropOpen = false;
            }
            batteryPageRoot.popupOpen = false;
        }
    }
}
