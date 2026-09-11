import "../../../" // for Config and StateManager
import "../../../components"
import "../../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: controlLeftWindow

    property bool active: false

    // Tab navigation - Bottom
    property int activeBottomTab: 0

    // Tab navigation - Top
    property int activeTopTab: 0
    readonly property var bottomPages: ["Weather", "Music"]
    readonly property var bottomTabIcons: ["weather-few-clouds-symbolic", "multimedia-audio-player-symbolic"]
    readonly property var bottomTabLabels: ["Weather", "Music"]
    readonly property bool compact: Responsive.constrained(panelWidth, height - outerMargin * 2, 560, 760)
    readonly property real contentMargin: compact ? 14 : 20
    property bool destroyed: false
    property real edgeDragProgress: 0
    property bool edgeDragging: false
    property bool edgeSnapAnimating: false
    property int edgeSnapDuration: 300
    readonly property real outerMargin: 10
    readonly property real panelWidth: Responsive.sidePanelWidth(width)
    property int previousBottomTab: 0
    property int previousTopTab: 0
    readonly property color sectionBorderColor: Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.12 : 0.09)
    readonly property color sectionColor: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.66 : 0.46)
    readonly property bool sideBySideSections: panelWidth >= 560 && height - outerMargin * 2 < 760
    readonly property var topPages: ["Calendar", "Todo", "Timers"]
    readonly property Item topPopupBackdropHost: topSection
    readonly property real topPopupBackdropRadius: topSection.radius
    readonly property var topTabIcons: ["x-office-calendar-symbolic", "checkbox-checked-symbolic", "preferences-system-time-symbolic"]
    readonly property var topTabLabels: ["Calendar", "Todo", "Timer"]

    signal dismissed

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
        edgeSnapAnimating = false;
        edgeDragProgress = 0;
        edgeDragging = true;
        active = true;
        popup.closedProgress = 1;
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
            Qt.callLater(function () {
                if (!active && !edgeDragging && !slideAnim.running)
                    dismissed();
            });
            return;
        }
        animatePopup(shouldOpen ? 0 : 1, edgeSnapDuration, Easing.InOutSine);
    }
    function hideControl() {
        edgeSnapAnimating = false;
        edgeDragging = false;
        edgeDragProgress = 0;
        active = false;
        animatePopup(1, 300, Easing.OutCubic);
    }
    function showControl() {
        edgeSnapAnimating = false;
        edgeDragging = false;
        edgeDragProgress = 0;
        active = true;
        animatePopup(0, 300, Easing.OutCubic);
    }
    function switchBottomTab(newTab) {
        previousBottomTab = activeBottomTab;
        activeBottomTab = newTab;
    }
    function switchTopTab(newTab) {
        previousTopTab = activeTopTab;
        activeTopTab = newTab;
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

    WlrLayershell.namespace: "sownteeshell-control-left"
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Fill screen to allow clicking outside to close
    anchors.top: true
    color: "transparent"
    focusable: true
    visible: active || edgeDragging || slideAnim.running || popup.closedProgress < 0.999

    BackgroundEffect.blurRegion: Region {
        item: Config.shellBlurControlLeftEnabled ? popup : null
        radius: popup.radius
    }

    Component.onCompleted: {
        StateManager.controlLeftPanel = controlLeftWindow;
    }
    Component.onDestruction: {
        destroyed = true;
        if (StateManager.controlLeftPanel === controlLeftWindow)
            StateManager.controlLeftPanel = null;
    }

    // Clicks on backdrop close the panel
    MouseArea {
        anchors.fill: parent

        onClicked: hideControl()
    }
    ShellShadow {
        cornerRadius: popup.radius
        target: popup
    }

    // ─── Sliding Sidebar Container ───────────────────────────────────────────────
    Rectangle {
        id: popup

        property real closedProgress: 1

        anchors.bottom: parent.bottom
        anchors.bottomMargin: controlLeftWindow.outerMargin
        anchors.left: parent.left
        anchors.leftMargin: controlLeftWindow.outerMargin - controlLeftWindow.panelWidth * closedProgress
        anchors.top: parent.top
        anchors.topMargin: controlLeftWindow.outerMargin
        border.color: Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.12 : 0.07)
        border.width: 1
        clip: true
        color: Config.shellBlurControlLeftEnabled ? Config.alpha(Config.md3.background, Config.lightTheme ? Config.shellBlurPanelOpacityLight : Config.shellBlurPanelOpacityDark) : Config.md3.background
        radius: 20
        width: controlLeftWindow.panelWidth

        NumberAnimation {
            id: slideAnim

            property: "closedProgress"
            target: popup

            onFinished: {
                controlLeftWindow.edgeSnapAnimating = false;
                if (!controlLeftWindow.active)
                    controlLeftWindow.dismissed();
            }
        }
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: false
        }
        GridLayout {
            id: sectionGrid

            anchors.fill: parent
            anchors.margins: controlLeftWindow.contentMargin
            columnSpacing: controlLeftWindow.compact ? 9 : 12
            columns: controlLeftWindow.sideBySideSections ? 2 : 1
            rowSpacing: controlLeftWindow.compact ? 9 : 12

            // ── 1. Top Tab Content Box ────────────────────────────────────────────
            ClippingRectangle {
                id: topSection

                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                border.color: controlLeftWindow.sectionBorderColor
                border.width: 1
                clip: true
                color: controlLeftWindow.sectionColor
                radius: 18

                AnimatedFireflies {
                    anchors.fill: parent
                    color: Config.md3.tertiary
                    running: controlLeftWindow.active && activeTopTab === 0
                    visible: activeTopTab === 0
                }
                AnimatedStars {
                    anchors.fill: parent
                    color: Config.md3.primary
                    running: controlLeftWindow.active && activeTopTab === 1
                    visible: activeTopTab === 1
                }
                AnimatedPulse {
                    readonly property bool hasTimerGeometry: activeTopTab === 2 && timerLoader && timerLoader.status === Loader.Ready && timerLoader.item && typeof timerLoader.item.dialCenter !== "undefined" && typeof timerLoader.item.dialSize !== "undefined"
                    readonly property point timerCenter: {
                        if (!hasTimerGeometry)
                            return Qt.point(width / 2, height / 2);
                        timerLoader.x;
                        timerLoader.y;
                        return timerLoader.item.mapToItem(topSection, timerLoader.item.dialCenter.x, timerLoader.item.dialCenter.y);
                    }
                    readonly property var timerLoader: topPagesRepeater && topPagesRepeater.count > 2 ? topPagesRepeater.itemAt(2) : null

                    anchors.fill: parent
                    centerX: timerCenter.x
                    centerY: timerCenter.y
                    color: CountdownService.completed ? Config.md3.secondary : Config.md3.primary
                    endRadius: Math.hypot(Math.max(centerX, width - centerX), Math.max(centerY, height - centerY)) + 12
                    running: controlLeftWindow.active && activeTopTab === 2 && CountdownService.running
                    startRadius: hasTimerGeometry ? timerLoader.item.dialSize / 2 - 20 : Math.min(width, height) * 0.3
                    visible: activeTopTab === 2
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: controlLeftWindow.compact ? 14 : 20
                    spacing: controlLeftWindow.compact ? 12 : 20
                    z: 1

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: controlLeftWindow.compact ? 10 : 20

                        Item {
                            Layout.fillWidth: true
                        }
                        Repeater {
                            model: topPages.length

                            delegate: Rectangle {
                                id: topTabBtn

                                property bool isActive: (index === activeTopTab)

                                Layout.preferredWidth: width
                                color: isActive ? Config.md3.primary : (topTabMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.06) : "transparent")
                                height: 40
                                radius: 22
                                width: isActive ? (topTabInnerRow.implicitWidth + 36) : 44

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                ShellShadow {
                                    active: topTabBtn.isActive
                                    componentShadow: true
                                    cornerRadius: parent.radius
                                    target: parent
                                    z: -1
                                }
                                Row {
                                    id: topTabInnerRow

                                    anchors.centerIn: parent
                                    spacing: 10

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 26
                                        layer.enabled: true
                                        source: Quickshell.iconPath(topTabIcons[index])
                                        width: 26

                                        layer.effect: ColorOverlay {
                                            color: topTabBtn.isActive ? Config.md3.on_primary : Config.md3.on_surface

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
                                        text: topTabLabels[index]
                                        visible: topTabBtn.isActive
                                    }
                                }
                                MouseArea {
                                    id: topTabMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: switchTopTab(index)
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }
                    // Content page with slide animation
                    Item {
                        id: topPageContainer

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true

                        Repeater {
                            id: topPagesRepeater

                            model: topPages.length

                            delegate: Loader {
                                active: controlLeftWindow.visible && (index === activeTopTab || (index === previousTopTab && opacity > 0))
                                asynchronous: true
                                height: topPageContainer.height
                                opacity: index === activeTopTab ? 1 : 0
                                source: "Pages/" + topPages[index] + ".qml"
                                visible: opacity > 0
                                width: topPageContainer.width
                                x: (index === activeTopTab) ? 0 : (index < activeTopTab ? -width * 0.35 : width)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: index === activeTopTab ? Easing.OutQuad : Easing.InQuad
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

            // ── 2. Bottom Tab Content Box ─────────────────────────────────────────
            ClippingRectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                border.color: controlLeftWindow.sectionBorderColor
                border.width: 1
                clip: true
                color: controlLeftWindow.sectionColor
                radius: 18

                AnimatedWeather {
                    anchors.fill: parent
                    running: controlLeftWindow.active && activeBottomTab === 0 && WeatherService.icon !== ""
                    visible: activeBottomTab === 0
                    weatherIcon: WeatherService.icon
                }
                AnimatedWaves {
                    anchors.fill: parent
                    color: Config.md3.primary
                    running: controlLeftWindow.active && activeBottomTab === 1
                    visible: activeBottomTab === 1
                }
                AnimatedBubbles {
                    anchors.fill: parent
                    color: Config.md3.primary
                    running: controlLeftWindow.active && activeBottomTab === 1
                    visible: activeBottomTab === 1
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: controlLeftWindow.compact ? 14 : 20
                    spacing: controlLeftWindow.compact ? 12 : 20
                    z: 1

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        spacing: controlLeftWindow.compact ? 10 : 20

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
                                radius: 22
                                width: isActive ? (bottomTabInnerRow.implicitWidth + 36) : 44

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                ShellShadow {
                                    active: bottomTabBtn.isActive
                                    componentShadow: true
                                    cornerRadius: parent.radius
                                    target: parent
                                    z: -1
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
                                active: controlLeftWindow.visible && (index === activeBottomTab || (index === previousBottomTab && opacity > 0))
                                asynchronous: true
                                height: bottomPageContainer.height
                                opacity: index === activeBottomTab ? 1 : 0
                                source: "Pages/" + bottomPages[index] + ".qml"
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
