import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower

GreeterEntrance {
    id: root

    readonly property var activeNetwork: {
        var values = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : [];
        for (var i = 0; i < values.length; ++i) {
            if (values[i] && values[i].connected)
                return values[i];
        }
        return null;
    }
    readonly property bool batteryCharging: batteryDevice && (batteryDevice.state === UPowerDeviceState.Charging || batteryDevice.state === UPowerDeviceState.PendingCharge || (batteryDevice.state === UPowerDeviceState.FullyCharged && !UPower.onBattery))
    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool batteryExternalPower: batteryDevice && (!UPower.onBattery || batteryCharging || batteryDevice.state === UPowerDeviceState.FullyCharged)
    readonly property int batteryPercentage: batteryDevice ? Math.round(batteryDevice.percentage * 100) : 0
    readonly property bool canIdle: interactive && visible && !GreeterSession.working && !GreeterSession.checkingLockout && !GreeterSession.launching && !GreeterSession.waitingForResponse && !loginCard.sessionPickerOpen
    readonly property real controlScale: Math.max(1, Math.min(1.1, scaleFactor))
    readonly property int controlSize: Math.round(48 * controlScale)
    readonly property var devices: Networking.devices ? Networking.devices.values : []
    property real exitProgress: GreeterSession.launching ? 1 : 0
    property bool exitShaderFailed: false
    readonly property bool hasBattery: batteryDevice && batteryDevice.ready && batteryDevice.isLaptopBattery
    property bool idleMode: false
    property real idleProgress: idleMode ? 1 : 0
    property bool interactive: true
    readonly property bool networkConnected: wiredDevice || activeNetwork !== null
    readonly property string networkIcon: wiredDevice ? "󰈀" : activeNetwork ? (activeNetwork.signalStrength > 0.7 ? "󰤨" : activeNetwork.signalStrength > 0.4 ? "󰤥" : "󰤟") : "󰤭"
    readonly property string networkLabel: wiredDevice ? qsTr("Wired") : activeNetwork ? (activeNetwork.name || qsTr("Connected")) : qsTr("Offline")
    property date now: new Date()
    readonly property real scaleFactor: Math.max(0.8, Math.min(1.4, Math.min(width / 1600, height / 900)))
    property int wakeKey: 0
    readonly property var wifiDevice: {
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }
    readonly property var wiredDevice: {
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].type === DeviceType.Wired && devices[i].connected)
                return devices[i];
        }
        return null;
    }

    function restartIdleCountdown() {
        if (root.canIdle && !root.idleMode)
            idleTimer.restart();
    }

    contentReady: GreeterTheme.ready && greeterBackground.ready
    exiting: GreeterSession.launching

    Behavior on exitProgress {
        NumberAnimation {
            duration: GreeterSession.exitTransitionDuration
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on idleProgress {
        NumberAnimation {
            duration: 360
            easing.type: Easing.InOutCubic
        }
    }

    Keys.onPressed: event => {
        if (!root.interactive || (!root.idleMode && root.wakeKey === 0))
            return;
        event.accepted = true;
        if (root.idleMode && !event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            root.wakeKey = event.key;
            root.idleMode = false;
        }
    }
    Keys.onReleased: event => {
        if (root.wakeKey !== 0 && event.key === root.wakeKey) {
            event.accepted = true;
            if (!event.isAutoRepeat) {
                root.wakeKey = 0;
                loginCard.focusInput();
                root.restartIdleCountdown();
            }
        }
    }
    onIdleProgressChanged: {
        if (idleProgress === 0 && wakeKey === 0 && !loginCard.sessionPickerOpen)
            loginCard.focusInput();
    }

    Timer {
        id: idleTimer

        interval: 10000
        running: root.canIdle && !root.idleMode && root.wakeKey === 0

        onTriggered: {
            if (root.canIdle) {
                root.idleMode = true;
                loginCard.clearSecret();
                root.forceActiveFocus();
            }
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: true

        onTriggered: root.now = new Date()
    }

    // 1. Wallpaper & Dynamic Background
    Rectangle {
        anchors.fill: parent
        color: GreeterTheme.background

        gradient: Gradient {
            GradientStop {
                color: GreeterTheme.surfaceContainerLowest
                position: 0
            }
            GradientStop {
                color: GreeterTheme.background
                position: 0.5
            }
            GradientStop {
                color: GreeterTheme.surfaceContainerLow
                position: 1
            }
        }
    }
    GreeterBackground {
        id: greeterBackground

        anchors.fill: parent
    }
    Rectangle {
        readonly property real restingOpacity: greeterBackground.hasBackground ? (GreeterTheme.isDark ? 0.35 : 0.22) : 0

        anchors.fill: parent
        color: GreeterTheme.scrim
        opacity: restingOpacity + (1 - restingOpacity) * root.exitProgress
        visible: opacity > 0
    }
    Item {
        id: foregroundContent

        anchors.fill: parent
        enabled: !GreeterSession.launching
        layer.effect: root.exitShaderFailed ? null : exitEffect
        layer.enabled: GreeterSession.launching || root.exitProgress > 0
        opacity: 1 - root.exitProgress

        transform: Translate {
            y: -18 * root.controlScale * root.exitProgress
        }

        // 3. Top Navigation & Status Bar
        Item {
            id: topBar

            anchors.left: parent.left
            anchors.leftMargin: Math.max(32, 40 * root.scaleFactor)
            anchors.right: parent.right
            anchors.rightMargin: Math.max(32, 40 * root.scaleFactor)
            anchors.top: parent.top
            anchors.topMargin: Math.max(24, 36 * root.scaleFactor)
            height: Math.round(42 * root.scaleFactor)
            z: 60

            // Left: Branding Capsule
            Item {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: root.controlSize
                width: height

                RowLayout {
                    id: brandRow

                    anchors.centerIn: parent
                    spacing: 0

                    Rectangle {
                        Layout.preferredHeight: Math.round(32 * root.controlScale)
                        Layout.preferredWidth: Layout.preferredHeight
                        border.color: GreeterTheme.primary
                        border.width: 1
                        color: "transparent"
                        radius: height / 2

                        Text {
                            anchors.centerIn: parent
                            color: GreeterTheme.primary
                            font.family: "Inter Variable"
                            font.pixelSize: Math.round(16 * root.controlScale)
                            font.weight: Font.Black
                            text: "S"
                        }
                    }
                }
            }

            // Right: Status Pills (Network & Battery)
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(10 * root.controlScale)

                StatusPill {
                    Layout.preferredHeight: root.controlSize
                    Layout.preferredWidth: root.controlSize
                    accentColor: root.networkConnected ? GreeterTheme.primary : GreeterTheme.surfaceVariantText
                    border.width: 0
                    color: "transparent"
                    icon: root.networkIcon
                    scaleFactor: root.controlScale * 2
                }
                Item {
                    Layout.preferredHeight: root.controlSize
                    Layout.preferredWidth: batteryRow.implicitWidth + Math.round(24 * root.controlScale)
                    visible: root.hasBattery

                    Row {
                        id: batteryRow

                        anchors.centerIn: parent
                        spacing: 0

                        GreeterBatteryIcon {
                            accentColor: root.batteryExternalPower ? GreeterTheme.secondary : root.batteryPercentage <= 20 ? GreeterTheme.error : root.batteryPercentage <= 50 ? GreeterTheme.tertiary : GreeterTheme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            charging: root.batteryCharging
                            externalPower: root.batteryExternalPower
                            percentage: root.batteryPercentage
                            scaleFactor: root.controlScale
                        }
                    }
                }
            }
        }

        // 4. Main Presentation Area
        Item {
            id: mainViewport

            anchors.bottom: bottomBar.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topBar.bottom

            // ═══════════════════════════════════════════════════════════════
            // Split Minimal Layout: Architectural Vertical Clock (Left) + MD3 Card (Right)
            // ═══════════════════════════════════════════════════════════════

            // Left Half: Architectural Vertical Clock
            Item {
                id: splitClock

                readonly property real restingX: parent.width < 960 ? Math.round((parent.width - width) / 2) : Math.round(Math.max(48, (parent.width * 0.5 - width) / 2))

                height: splitClockContent.implicitHeight
                scale: 1 + root.idleProgress * Math.max(0, Math.min(0.25, (parent.height - 48) / height - 1))
                width: Math.max(clockMetrics.advanceWidth, dateRow.implicitWidth)
                x: restingX + (Math.round((parent.width - width) / 2) - restingX) * root.idleProgress
                y: {
                    var centerY = Math.round((parent.height - height) / 2);
                    var restingY = parent.width < 960 ? Math.max(16, loginCard.y - height - 42) : centerY;
                    return restingY + (centerY - restingY) * root.idleProgress;
                }

                TextMetrics {
                    id: clockMetrics

                    font: hourText.font
                    text: "00"
                }
                ColumnLayout {
                    id: splitClockContent

                    spacing: 9
                    width: parent.width

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: GreeterTheme.primary
                            height: 3
                            radius: 1.5
                            width: 40
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Repeater {
                                model: 5

                                Rectangle {
                                    required property int index

                                    anchors.verticalCenter: parent.verticalCenter
                                    color: GreeterTheme.withAlpha(GreeterTheme.primary, index === 4 ? 0.85 : 0.3)
                                    height: index === 4 ? 12 : 6
                                    radius: 1
                                    width: 2
                                }
                            }
                        }
                    }
                    Column {
                        id: timeDigits

                        Layout.fillWidth: true
                        spacing: -28

                        Text {
                            id: hourText

                            color: GreeterTheme.primary
                            font.family: "Inter Display"
                            font.letterSpacing: -8
                            font.pixelSize: Math.round(Math.min(280, Math.max(180, root.height * 0.245)))
                            font.weight: Font.Black
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatTime(root.now, "HH")
                            width: parent.width
                        }
                        Text {
                            id: minuteText

                            color: GreeterTheme.backgroundText
                            font.family: "Inter Display"
                            font.letterSpacing: -8
                            font.pixelSize: hourText.font.pixelSize
                            font.weight: Font.Black
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatTime(root.now, "mm")
                            width: parent.width
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: GreeterTheme.withAlpha(GreeterTheme.primary, 0.25)

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: GreeterTheme.primary
                            height: 5
                            radius: 2.5
                            width: 5
                        }
                    }
                    RowLayout {
                        id: dateRow

                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        Rectangle {
                            Layout.preferredHeight: 2
                            Layout.preferredWidth: 16
                            color: GreeterTheme.primary
                            radius: 1
                        }
                        Text {
                            color: GreeterTheme.surfaceVariantText
                            font.capitalization: Font.AllUppercase
                            font.family: "Inter Display"
                            font.letterSpacing: 1.8
                            font.pixelSize: Math.round(18 * root.scaleFactor)
                            font.weight: Font.DemiBold
                            text: root.now.toLocaleDateString(Qt.locale(), "ddd d MMM")
                        }
                    }
                }
            }

            // Right Half: MD3 Login Card
            LoginCard {
                id: loginCard

                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: parent.width < 960 ? 80 : 0
                defaultUser: GreeterSession.configuredUser
                enabled: root.interactive && !root.idleMode && root.wakeKey === 0
                opacity: 1 - root.idleProgress
                visible: root.interactive && opacity > 0
                width: Math.min(implicitWidth, Math.max(0, parent.width - 48))
                x: parent.width < 960 ? Math.round((parent.width - width) / 2) : Math.round(parent.width * 0.5 + Math.max(20, (parent.width * 0.5 - width) / 2))
                z: 20

                transform: Translate {
                    y: 48 * root.idleProgress
                }

                onInputActivity: root.restartIdleCountdown()
            }
        }

        // 5. Bottom Controls (Power & Reboot Actions)
        Item {
            id: bottomBar

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(24, 36 * root.scaleFactor)
            anchors.left: parent.left
            anchors.leftMargin: Math.max(32, 40 * root.scaleFactor)
            anchors.right: parent.right
            anchors.rightMargin: Math.max(32, 40 * root.scaleFactor)
            height: Math.round(48 * root.scaleFactor)
            z: 60

            HoverHandler {
                id: bottomHover

                enabled: root.interactive
                margin: Math.max(32, 40 * root.scaleFactor)
            }
            Row {
                id: powerActions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.interactive && bottomHover.hovered && !GreeterSession.working && !GreeterSession.launching
                opacity: root.interactive && bottomHover.hovered ? 1 : 0
                spacing: Math.round(12 * root.controlScale)
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                MdIconButton {
                    accessibleName: qsTr("Restart")
                    iconGlyph: "󰜉"
                    pill: false
                    scaleFactor: root.controlScale

                    onClicked: GreeterSession.reboot()
                }
                MdIconButton {
                    accessibleName: qsTr("Power off")
                    destructive: true
                    iconGlyph: "󰐥"
                    pill: false
                    scaleFactor: root.controlScale

                    onClicked: GreeterSession.powerOff()
                }
            }
        }
    }
    Component {
        id: exitEffect

        GreeterExitTransition {
            progress: root.exitProgress

            onFailed: root.exitShaderFailed = true
        }
    }
}
