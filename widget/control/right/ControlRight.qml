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
import Quickshell.Wayland
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
    readonly property var bottomPages: ["Display", "Battery", "Volume"]
    readonly property var bottomTabIcons: ["video-display-symbolic", "power-profile-balanced-symbolic", "audio-volume-high-symbolic"]
    readonly property var bottomTabLabels: ["Display", qsTr("Power"), "Volume"]
    readonly property bool caffeineEnabled: QuickSettingsService.caffeineEnabled
    readonly property bool compact: Responsive.constrained(panelWidth, height - outerMargin * 2, 560, 760)
    readonly property real contentMargin: compact ? 14 : 20
    property real edgeDragProgress: 0
    property bool edgeDragging: false
    property bool edgeSnapAnimating: false
    property int edgeSnapDuration: 300
    property bool effectsEnabled: false
    readonly property bool effectsRunning: active && effectsEnabled && !edgeDragging && !edgeSnapAnimating
    readonly property real outerMargin: 10
    readonly property var pages: ["Notification", "Wifi", "Bluetooth"]
    readonly property real panelWidth: Responsive.sidePanelWidth(width)
    property int previousBottomTab: 0
    property int previousTab: 0
    readonly property color sectionBorderColor: Config.md3.outline_variant
    readonly property color sectionCardBorderColor: Config.alpha(Config.md3.outline_variant, 0.72)
    readonly property color sectionCardColor: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.92 : 0.76)
    readonly property color sectionColor: Config.alpha(Config.md3.surface_container_low, Config.lightTheme ? 0.94 : 0.84)
    readonly property bool sideBySideSections: panelWidth >= 560 && height - outerMargin * 2 < 760
    readonly property var tabIcons: ["preferences-system-notifications-symbolic", WifiService.connectionType === "wifi" ? "network-wireless-symbolic" : "network-wired-symbolic", "bluetooth-symbolic"]
    readonly property var tabLabels: [qsTr("Notifications"), qsTr("Network"), qsTr("Bluetooth")]
    readonly property bool tailscaleEnabled: QuickSettingsService.tailscaleEnabled
    readonly property bool warpEnabled: QuickSettingsService.warpEnabled
    readonly property bool wifiEnabled: QuickSettingsService.wifiEnabled
    property bool wifiQrPopupOpen: false
    property string wifiQrSsid: ""

    signal dismissed
    signal statsUpdated

    function animatePopup(targetProgress, duration, easingType) {
        slideAnim.stop();
        slideAnim.duration = duration;
        slideAnim.easing.type = easingType;
        slideAnim.to = targetProgress;
        slideAnim.start();
    }
    function beginEdgeDrag() {
        if (active)
            return;
        slideAnim.stop();
        effectsResumeTimer.stop();
        effectsEnabled = false;
        edgeSnapAnimating = false;
        edgeDragProgress = 0;
        edgeDragging = true;
        active = true;
        popup.closedProgress = 1;
    }
    function closeWifiQrCode() {
        wifiQrPopupOpen = false;
        wifiQrSsid = "";
        WifiService.clearQrCode();
    }
    function finishEdgeDrag(shouldOpen) {
        if (!edgeDragging)
            return;

        var releasedProgress = edgeDragProgress;
        edgeSnapDuration = 300;
        edgeSnapAnimating = true;
        active = shouldOpen;
        edgeDragging = false;
        edgeDragProgress = 0;

        if (!shouldOpen && releasedProgress <= 0.001) {
            popup.closedProgress = 1;
            edgeSnapAnimating = false;
            effectsEnabled = false;
            effectsResumeTimer.stop();
            Qt.callLater(function () {
                if (!active && !edgeDragging && !slideAnim.running)
                    dismissed();
            });
            return;
        }
        animatePopup(shouldOpen ? 0 : 1, edgeSnapDuration, Easing.InOutSine);
    }
    function hideControl() {
        edgeSnapAnimating = true;
        effectsEnabled = false;
        effectsResumeTimer.stop();
        edgeDragging = false;
        edgeDragProgress = 0;
        active = false;
        animatePopup(1, 300, Easing.OutCubic);
    }
    function openWifiQrCode(network) {
        if (!network)
            return;

        wifiQrSsid = String(network.name || "");
        wifiQrPopupOpen = true;
        WifiService.requestQrCode(network);
    }
    function retryWifiQrCode() {
        var network = WifiService.findNetwork(wifiQrSsid);
        if (network)
            WifiService.requestQrCode(network);
        else
            WifiService.qrCodeError = qsTr("The Wi-Fi network is no longer available.");
    }
    function runAction(cmd) {
        QuickSettingsService.runAction(cmd);
    }
    function showControl() {
        edgeSnapAnimating = true;
        effectsEnabled = false;
        effectsResumeTimer.stop();
        edgeDragging = false;
        edgeDragProgress = 0;
        active = true;
        animatePopup(0, 300, Easing.OutCubic);
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
        if (active)
            hideControl();
        else
            showControl();
    }
    function updateEdgeDrag(progress) {
        if (!edgeDragging)
            return;
        edgeDragProgress = Math.max(0, Math.min(1, progress));
        popup.closedProgress = 1 - edgeDragProgress;
    }
    function updateStatsPolling() {
        SysStats.rightPanelActive = active;
    }

    WlrLayershell.namespace: "sownteeshell-control-right"
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Fill screen to allow clicking outside to close
    anchors.top: true
    color: "transparent"
    focusable: true
    visible: active || edgeDragging || slideAnim.running || popup.closedProgress < 0.999

    BackgroundEffect.blurRegion: Region {
        item: Config.shellBlurControlRightEnabled && controlRightWindow.visible ? popup : null
        radius: popup.radius
    }

    Component.onCompleted: {
        if (activeBottomTab >= bottomPages.length)
            activeBottomTab = 0;
        StateManager.controlPanel = controlRightWindow;
        updateStatsPolling();
        QuickSettingsService.active = active;
    }
    Component.onDestruction: {
        effectsResumeTimer.stop();
        SysStats.rightPanelActive = false;
        QuickSettingsService.active = false;
        if (wifiQrPopupOpen)
            WifiService.clearQrCode();
        if (StateManager.controlPanel === controlRightWindow)
            StateManager.controlPanel = null;
    }
    onActiveChanged: {
        updateStatsPolling();
        QuickSettingsService.active = active;
        if (!active) {
            effectsEnabled = false;
            effectsResumeTimer.stop();
        }
        if (!active && wifiQrPopupOpen)
            closeWifiQrCode();
    }
    onActiveTabChanged: {
        if (activeTab !== 1 && wifiQrPopupOpen)
            closeWifiQrCode();
    }

    // Clicks on backdrop close the panel
    MouseArea {
        anchors.fill: parent

        onClicked: hideControl()
    }
    ShellShadow {
        active: controlRightWindow.visible
        cornerRadius: popup.radius
        target: popup
    }
    Timer {
        id: effectsResumeTimer

        interval: 56
        repeat: false

        onTriggered: {
            if (controlRightWindow.active && !controlRightWindow.edgeDragging && !controlRightWindow.edgeSnapAnimating)
                controlRightWindow.effectsEnabled = true;
        }
    }

    // ─── Sliding Sidebar Container ───────────────────────────────────────────────
    Rectangle {
        id: popup

        property real closedProgress: 1

        anchors.bottom: parent.bottom
        anchors.bottomMargin: controlRightWindow.outerMargin
        anchors.right: parent.right
        anchors.rightMargin: controlRightWindow.outerMargin - controlRightWindow.panelWidth * closedProgress
        anchors.top: parent.top
        anchors.topMargin: controlRightWindow.outerMargin
        border.color: Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.12 : 0.07)
        border.width: 1
        clip: true // Prevent bubbles from flying completely outside the panel bounds

        color: Config.shellBlurControlRightEnabled ? Config.alpha(Config.md3.background, Config.lightTheme ? Config.shellBlurPanelOpacityLight : Config.shellBlurPanelOpacityDark) : Config.md3.background
        radius: 20
        width: controlRightWindow.panelWidth

        NumberAnimation {
            id: slideAnim

            property: "closedProgress"
            target: popup

            onFinished: {
                controlRightWindow.edgeSnapAnimating = false;
                if (controlRightWindow.active)
                    effectsResumeTimer.restart();
                else
                    controlRightWindow.dismissed();
            }
        }
        AnimatedBubbles {
            anchors.fill: parent
            bubbleCount: 35
            color: Config.alpha(Config.md3.primary, 0.6)
            running: controlRightWindow.effectsRunning
        }
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: false
        }
        GridLayout {
            id: controlGrid

            anchors.fill: parent
            anchors.margins: controlRightWindow.contentMargin
            columnSpacing: controlRightWindow.compact ? 9 : 12
            columns: controlRightWindow.sideBySideSections ? 2 : 1
            rowSpacing: controlRightWindow.compact ? 9 : 12

            // ── 1. Top Control ────────────────────────────────────────────────
            TopControl {
                Layout.columnSpan: controlGrid.columns
                Layout.fillWidth: true
                Layout.preferredHeight: 42
            }

            // ── 2. Quick Toggle Buttons ───────────────────────────────────────
            Rectangle {
                id: quickToggleSurface

                Layout.columnSpan: controlGrid.columns
                Layout.fillWidth: true
                Layout.leftMargin: controlRightWindow.compact ? 8 : 50
                Layout.preferredHeight: controlRightWindow.compact ? 72 : 80
                Layout.rightMargin: controlRightWindow.compact ? 8 : 50
                border.color: controlRightWindow.sectionBorderColor
                border.width: 1
                color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.68 : 0.5)
                radius: height / 2

                ShellShadow {
                    active: controlRightWindow.visible
                    componentShadow: true
                    cornerRadius: parent.radius
                    target: parent
                    z: -1
                }
                Flickable {
                    id: quickToggleViewport

                    anchors.fill: parent
                    anchors.margins: 8
                    boundsBehavior: Flickable.StopAtBounds
                    clip: contentWidth > width
                    contentHeight: height
                    contentWidth: Math.max(width, quickToggleRow.implicitWidth)
                    flickableDirection: Flickable.HorizontalFlick
                    interactive: contentWidth > width

                    Row {
                        id: quickToggleRow

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: controlRightWindow.compact ? 8 : 15
                        x: quickToggleRow.implicitWidth <= quickToggleViewport.width ? (quickToggleViewport.width - quickToggleRow.implicitWidth) / 2 : 0

                        Button {
                            accessibleName: qsTr("Wi-Fi")
                            active: wifiEnabled
                            iconName: wifiEnabled ? "wifi" : "wifi_off"

                            onClicked: QuickSettingsService.setWifiEnabled(!wifiEnabled)
                        }
                        Button {
                            accessibleName: qsTr("Bluetooth")
                            active: bluetoothEnabled
                            iconName: "bluetooth-symbolic"

                            onClicked: QuickSettingsService.setBluetoothEnabled(!bluetoothEnabled)
                        }
                        Button {
                            accessibleName: qsTr("Airplane mode")
                            active: airplaneEnabled
                            iconName: "airplane-mode-symbolic"

                            onClicked: QuickSettingsService.setAirplaneEnabled(!airplaneEnabled)
                        }
                        Button {
                            accessibleName: qsTr("Do not disturb")
                            active: QuickSettingsService.effectiveDndActive
                            iconName: "notifications-disabled-symbolic"

                            onClicked: QuickSettingsService.toggleDnd()
                        }
                        Button {
                            accessibleName: qsTr("Keep awake")
                            active: caffeineEnabled
                            iconName: caffeineEnabled ? "caffeine-cup-full-symbolic" : "caffeine-cup-empty-symbolic"

                            onClicked: QuickSettingsService.setCaffeineEnabled(!caffeineEnabled)
                        }
                        Button {
                            accessibleName: qsTr("Tailscale")
                            active: tailscaleEnabled
                            activeColor: Config.md3.primary
                            iconName: "file://" + Config.sownteeshellDir + "/assets/icons/tailscale.svg"

                            onClicked: QuickSettingsService.setTailscaleEnabled(!tailscaleEnabled)
                        }
                        Button {
                            accessibleName: qsTr("Cloudflare WARP")
                            active: warpEnabled
                            iconName: warpEnabled ? "file://" + Config.sownteeshellDir + "/assets/icons/cloudflare-active.svg" : "file://" + Config.sownteeshellDir + "/assets/icons/cloudflare.svg"

                            onClicked: QuickSettingsService.setWarpEnabled(!warpEnabled)
                        }
                    }
                }
            }

            // ── 3. Tab Content Box ────────────────────────────────────────────
            Rectangle {
                id: topTabSection

                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 600
                border.color: controlRightWindow.sectionBorderColor
                border.width: 1
                clip: true
                color: controlRightWindow.sectionColor
                radius: 18

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: controlRightWindow.compact ? 12 : 20
                    spacing: controlRightWindow.compact ? 10 : 20

                    ControlTabBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        compact: controlRightWindow.compact
                        currentIndex: controlRightWindow.activeTab
                        enabled: controlRightWindow.active && !controlRightWindow.wifiQrPopupOpen && !controlRightWindow.edgeDragging
                        icons: controlRightWindow.tabIcons
                        labels: controlRightWindow.tabLabels
                        showWifiIconIndex: 1
                        wifiConnected: WifiService.connected
                        wifiIssue: WifiService.connectivityIssue
                        wifiSignal: WifiService.activeSignal

                        onRequested: index => controlRightWindow.switchTab(index)
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
                                        duration: Config.animationDuration(220)
                                        easing.type: index === activeTab ? Easing.OutQuad : Easing.InQuad
                                    }
                                }
                                Behavior on x {
                                    NumberAnimation {
                                        duration: Config.animationDuration(320)
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }  // end ColumnLayout (tab content ColumnLayout)

                Loader {
                    id: wifiQrOverlayLoader

                    active: controlRightWindow.wifiQrPopupOpen
                    anchors.fill: parent
                    z: 100

                    sourceComponent: Component {
                        WifiQrPopup {
                            backdropRadius: topTabSection.radius
                            busy: WifiService.qrCodeBusy
                            errorText: WifiService.qrCodeError
                            qrPath: WifiService.qrCodePath
                            ssid: WifiService.qrCodeSsid || controlRightWindow.wifiQrSsid

                            onDismissed: controlRightWindow.closeWifiQrCode()
                            onRetryRequested: controlRightWindow.retryWifiQrCode()
                        }
                    }
                }
            }  // end Rectangle (tab content box)

            // ── 4. Bottom Tab Content Box ────────────────────────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 600
                border.color: controlRightWindow.sectionBorderColor
                border.width: 1
                clip: true
                color: controlRightWindow.sectionColor
                radius: 18

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: controlRightWindow.compact ? 12 : 20
                    spacing: controlRightWindow.compact ? 10 : 20

                    ControlTabBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        compact: controlRightWindow.compact
                        currentIndex: controlRightWindow.activeBottomTab
                        enabled: controlRightWindow.active && !controlRightWindow.edgeDragging
                        icons: controlRightWindow.bottomTabIcons
                        labels: controlRightWindow.bottomTabLabels

                        onRequested: index => controlRightWindow.switchBottomTab(index)
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
                                        duration: Config.animationDuration(220)
                                        easing.type: index === activeBottomTab ? Easing.OutQuad : Easing.InQuad
                                    }
                                }
                                Behavior on x {
                                    NumberAnimation {
                                        duration: Config.animationDuration(320)
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
