import "."
import "../../../" // for Config and StateManager
import "../../../components"
import "../../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Widgets

PanelWindow {
    id: controlRightWindow

    property bool active: false

    // Bottom Tab navigation
    property int activeBottomTab: 0
    // Tab navigation
    property int activeTab: 0
    readonly property bool airplaneEnabled: QuickSettingsService.airplaneEnabled
    readonly property bool bluetoothEnabled: QuickSettingsService.bluetoothEnabled
    readonly property var bottomPages: ["Stats", "Battery", "Display"]
    readonly property var bottomTabIcons: ["utilities-system-monitor-symbolic", "battery-symbolic", "video-display-symbolic"]
    readonly property var bottomTabLabels: ["Stats", "Battery", "Display"]
    readonly property bool caffeineEnabled: QuickSettingsService.caffeineEnabled
    readonly property var pages: ["Notification", "Wifi", "Bluetooth", "Volume"]
    property int previousBottomTab: 0
    property int previousTab: 0
    readonly property var tabIcons: ["preferences-system-notifications-symbolic", "network-wireless-symbolic", "bluetooth-symbolic", "audio-volume-high-symbolic"]
    readonly property var tabLabels: ["Notifications", "Wi-Fi", "Bluetooth", "Volume"]
    readonly property bool tailscaleEnabled: QuickSettingsService.tailscaleEnabled
    readonly property bool warpEnabled: QuickSettingsService.warpEnabled
    readonly property bool wifiEnabled: QuickSettingsService.wifiEnabled

    signal dismissed
    signal statsUpdated

    function hideControl() {
        active = false;
    }
    function runAction(cmd) {
        QuickSettingsService.runAction(cmd);
    }
    function showControl() {
        active = true;
    }
    function switchBottomTab(newTab) {
        previousBottomTab = activeBottomTab;
        activeBottomTab = newTab;
    }

    // switchTab: use this instead of directly setting activeTab to track direction
    function switchTab(newTab) {
        previousTab = activeTab;
        activeTab = newTab;
    }
    function toggleControl() {
        active = !active;
    }
    function updateStatsPolling() {
        SysStats.pollingEnabled = active && (activeBottomTab === 0 || activeTab === 1);
    }

    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Fill screen to allow clicking outside to close
    anchors.top: true
    color: "transparent"
    focusable: true
    visible: active || slideAnim.running

    Component.onCompleted: {
        if (activeBottomTab >= bottomPages.length)
            activeBottomTab = 0;
        StateManager.controlPanel = controlRightWindow;
        updateStatsPolling();
        QuickSettingsService.active = active;
    }
    Component.onDestruction: {
        SysStats.pollingEnabled = false;
        QuickSettingsService.active = false;
        if (StateManager.controlPanel === controlRightWindow)
            StateManager.controlPanel = null;
    }
    onActiveBottomTabChanged: updateStatsPolling()
    onActiveChanged: {
        updateStatsPolling();
        QuickSettingsService.active = active;
    }
    onActiveTabChanged: updateStatsPolling()

    // Clicks on backdrop close the panel
    MouseArea {
        anchors.fill: parent

        onClicked: hideControl()
    }

    // A full-height DropShadow turns the entire panel into an FBO. Every
    // notification delegate change then repaints that large texture. These two
    // cheap rounded layers preserve the depth without a blur pass.
    Rectangle {
        anchors.fill: popup
        anchors.margins: -10
        color: Config.alpha("#000000", 0.05)
        radius: popup.radius + 10
    }
    Rectangle {
        anchors.fill: popup
        anchors.margins: -5
        color: Config.alpha("#000000", 0.12)
        radius: popup.radius + 5
    }

    // ─── Sliding Sidebar Container ───────────────────────────────────────────────
    Rectangle {
        id: popup

        property real xOffset: active ? 0 : 640

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10 - xOffset
        anchors.top: parent.top
        anchors.topMargin: 10
        border.color: Config.alpha(Config.md3.on_surface, 0.06)
        border.width: 1
        clip: true // Prevent bubbles from flying completely outside the panel bounds

        color: Config.alpha(Config.md3.background, 0.98)
        radius: 20
        width: 650

        Behavior on xOffset {
            NumberAnimation {
                id: slideAnim

                duration: 300
                easing.type: Easing.OutCubic

                onFinished: {
                    if (!controlRightWindow.active)
                        controlRightWindow.dismissed();
                }
            }
        }

        AnimatedBubbles {
            anchors.fill: parent
            bubbleCount: 35
            color: Config.alpha(Config.md3.primary, 0.6)
            running: controlRightWindow.active
        }
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: false
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            // ── 1. Top Control ────────────────────────────────────────────────
            TopControl {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
            }

            // ── 2. Quick Toggle Buttons ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 50
                Layout.rightMargin: 50
                color: Config.md3.surface
                height: 80
                layer.enabled: controlRightWindow.visible
                radius: 40

                layer.effect: DropShadow {
                    color: "#80000000"
                    horizontalOffset: 0
                    radius: 10
                    samples: 20
                    verticalOffset: 0
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 15

                    Button {
                        active: wifiEnabled
                        iconName: wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"

                        onClicked: QuickSettingsService.setWifiEnabled(!wifiEnabled)
                    }
                    Button {
                        active: bluetoothEnabled
                        iconName: "bluetooth-symbolic"

                        onClicked: QuickSettingsService.setBluetoothEnabled(!bluetoothEnabled)
                    }
                    Button {
                        active: airplaneEnabled
                        iconName: "airplane-mode-symbolic"

                        onClicked: QuickSettingsService.setAirplaneEnabled(!airplaneEnabled)
                    }
                    Button {
                        active: QuickSettingsService.dndActive
                        iconName: "notifications-disabled-symbolic"

                        onClicked: QuickSettingsService.dndActive = !QuickSettingsService.dndActive
                    }
                    Button {
                        active: caffeineEnabled
                        iconName: caffeineEnabled ? "caffeine-cup-full-symbolic" : "caffeine-cup-empty-symbolic"

                        onClicked: QuickSettingsService.setCaffeineEnabled(!caffeineEnabled)
                    }
                    Button {
                        active: tailscaleEnabled
                        activeColor: Config.md3.primary
                        iconName: tailscaleEnabled ? "network-vpn-symbolic" : "network-vpn-disconnected-symbolic"

                        onClicked: QuickSettingsService.setTailscaleEnabled(!tailscaleEnabled)
                    }
                    Button {
                        active: warpEnabled
                        iconName: warpEnabled ? "file://" + Config.quickshellDir + "/assets/icons/cloudflare-active.svg" : "file://" + Config.quickshellDir + "/assets/icons/cloudflare.svg"

                        onClicked: QuickSettingsService.setWarpEnabled(!warpEnabled)
                    }
                }
            }

            // ── 3. Tab Content Box ────────────────────────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredHeight: 600
                border.color: Config.alpha(Config.md3.on_surface, 0.065)
                border.width: 1
                clip: true
                color: Config.md3.surface
                radius: 18

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: 20

                        Item {
                            Layout.fillWidth: true
                        }
                        Repeater {
                            model: pages.length

                            delegate: Rectangle {
                                id: tabBtn

                                property bool isActive: (index === activeTab)

                                Layout.preferredWidth: width
                                color: isActive ? Config.md3.primary : (tabMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.06) : "transparent")
                                height: 40
                                layer.enabled: isActive
                                radius: 22
                                width: isActive ? (tabInnerRow.implicitWidth + 36) : 44

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                layer.effect: DropShadow {
                                    color: Config.alpha(Config.md3.primary, 0.35)
                                    horizontalOffset: 0
                                    radius: 8
                                    samples: 16
                                    verticalOffset: 0
                                }
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Row {
                                    id: tabInnerRow

                                    anchors.centerIn: parent
                                    spacing: 10

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 26
                                        layer.enabled: true
                                        source: Quickshell.iconPath(tabIcons[index])
                                        width: 26

                                        layer.effect: ColorOverlay {
                                            color: tabBtn.isActive ? Config.md3.on_primary : Config.md3.on_surface

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 150
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Config.md3.on_primary
                                        font.family: Config.fontName
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        text: tabLabels[index]
                                        visible: tabBtn.isActive
                                    }
                                }
                                MouseArea {
                                    id: tabMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: switchTab(index)
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    // Content page with slide animation
                    Item {
                        id: pageContainer

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true

                        Repeater {
                            model: pages.length

                            delegate: Loader {
                                active: controlRightWindow.visible && (index === activeTab || (index === previousTab && opacity > 0))
                                asynchronous: true
                                height: pageContainer.height
                                opacity: index === activeTab ? 1 : 0
                                source: "Setting/" + pages[index] + ".qml"
                                visible: opacity > 0
                                width: pageContainer.width
                                x: (index === activeTab) ? 0 : (index < activeTab ? -width * 0.35 : width)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: index === activeTab ? Easing.OutQuad : Easing.InQuad
                                    }
                                }
                                Behavior on x {
                                    NumberAnimation {
                                        duration: 320
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }  // end ColumnLayout (tab content ColumnLayout)

            }  // end Rectangle (tab content box)

            // ── 4. Bottom Tab Content Box ────────────────────────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredHeight: 600
                border.color: Config.alpha(Config.md3.on_surface, 0.065)
                border.width: 1
                clip: true
                color: Config.md3.surface
                radius: 18

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: 20

                        Item {
                            Layout.fillWidth: true
                        }
                        Repeater {
                            model: bottomPages.length

                            delegate: Rectangle {
                                id: bottomTabBtn

                                property bool isActive: (index === activeBottomTab)

                                Layout.preferredWidth: width
                                color: isActive ? Config.md3.primary : (bottomTabMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.06) : "transparent")
                                height: 40
                                layer.enabled: isActive
                                radius: 22
                                width: isActive ? (bottomTabInnerRow.implicitWidth + 36) : 44

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                layer.effect: DropShadow {
                                    color: Config.alpha(Config.md3.primary, 0.35)
                                    horizontalOffset: 0
                                    radius: 8
                                    samples: 16
                                    verticalOffset: 0
                                }
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Row {
                                    id: bottomTabInnerRow

                                    anchors.centerIn: parent
                                    spacing: 10

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 26
                                        layer.enabled: true
                                        source: Quickshell.iconPath(bottomTabIcons[index])
                                        width: 26

                                        layer.effect: ColorOverlay {
                                            color: bottomTabBtn.isActive ? Config.md3.on_primary : Config.md3.on_surface

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 150
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Config.md3.on_primary
                                        font.family: Config.fontName
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        text: bottomTabLabels[index]
                                        visible: bottomTabBtn.isActive
                                    }
                                }
                                MouseArea {
                                    id: bottomTabMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: switchBottomTab(index)
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    // Content page with slide animation
                    Item {
                        id: bottomPageContainer

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true

                        Repeater {
                            model: bottomPages.length

                            delegate: Loader {
                                active: controlRightWindow.visible && (index === activeBottomTab || (index === previousBottomTab && opacity > 0))
                                asynchronous: true
                                height: bottomPageContainer.height
                                opacity: index === activeBottomTab ? 1 : 0
                                source: "Setting/" + bottomPages[index] + ".qml"
                                visible: opacity > 0
                                width: bottomPageContainer.width
                                x: (index === activeBottomTab) ? 0 : (index < activeBottomTab ? -width * 0.35 : width)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: index === activeBottomTab ? Easing.OutQuad : Easing.InQuad
                                    }
                                }
                                Behavior on x {
                                    NumberAnimation {
                                        duration: 320
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
