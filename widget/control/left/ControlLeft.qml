import "../../../" // for Config and StateManager
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    property bool destroyed: false
    property int previousBottomTab: 0
    property int previousTopTab: 0
    readonly property var topPages: ["Calendar", "Todo", "Timers"]
    readonly property var topTabIcons: ["x-office-calendar-symbolic", "checkbox-checked-symbolic", "preferences-system-time-symbolic"]
    readonly property var topTabLabels: ["Calendar", "Todo", "Timer"]

    signal dismissed

    function hideControl() {
        active = false;
    }
    function showControl() {
        active = true;
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
        active = !active;
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

    // ─── Sliding Sidebar Container ───────────────────────────────────────────────
    Rectangle {
        id: popup

        property real xOffset: active ? 0 : -640

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.left: parent.left
        anchors.leftMargin: 10 + xOffset
        anchors.top: parent.top
        anchors.topMargin: 10
        color: Config.alpha(Config.md3.background, 0.97)
        layer.enabled: controlLeftWindow.visible
        radius: 20
        width: 650

        layer.effect: DropShadow {
            color: "#80000000"
            horizontalOffset: 0
            radius: 12
            samples: 17
            verticalOffset: 0
        }
        Behavior on xOffset {
            NumberAnimation {
                id: slideAnim

                duration: 300
                easing.type: Easing.OutCubic

                onFinished: {
                    if (!controlLeftWindow.active)
                        controlLeftWindow.dismissed();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: false
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            // ── 1. Top Tab Content Box ────────────────────────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                clip: true
                color: Config.md3.surface
                layer.enabled: controlLeftWindow.visible && !slideAnim.running
                radius: 15

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
                            model: topPages.length

                            delegate: Rectangle {
                                id: topTabBtn

                                property bool isActive: (index === activeTopTab)

                                Layout.preferredWidth: width
                                color: isActive ? Config.md3.primary : (topTabMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.06) : "transparent")
                                height: 40
                                layer.enabled: isActive
                                radius: 22
                                width: isActive ? (topTabInnerRow.implicitWidth + 36) : 44

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                layer.effect: DropShadow {
                                    color: Config.alpha(Config.md3.primary, 0.6)
                                    horizontalOffset: 0
                                    radius: 15
                                    samples: 31
                                    verticalOffset: 0
                                }
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
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
                    Item {
                        id: topPageContainer

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true

                        Loader {
                            id: topOutgoingPage

                            active: source !== ""
                            height: topPageContainer.height
                            opacity: 0
                            width: topPageContainer.width
                            x: 0
                            z: 0

                            NumberAnimation on opacity {
                                id: topFadeOutAnim

                                duration: 220
                                easing.type: Easing.InQuad
                                running: false
                                to: 0

                                onFinished: {
                                    if (topOutgoingPage.opacity === 0)
                                        topOutgoingPage.source = "";
                                }
                            }
                            NumberAnimation on x {
                                id: topSlideOutAnim

                                duration: 320
                                easing.type: Easing.OutCubic
                                running: false
                            }
                        }
                        Loader {
                            id: topCurrentPage

                            active: controlLeftWindow.visible
                            height: topPageContainer.height
                            opacity: 1
                            source: "Pages/" + topPages[activeTopTab] + ".qml"
                            width: topPageContainer.width
                            x: 0
                            z: 1

                            NumberAnimation on opacity {
                                id: topFadeInAnim

                                duration: 220
                                easing.type: Easing.OutQuad
                                from: 0.3
                                running: false
                                to: 1
                            }
                            NumberAnimation on x {
                                id: topSlideInAnim

                                duration: 320
                                easing.type: Easing.OutCubic
                                running: false
                                to: 0
                            }
                        }
                        Connections {
                            function onActiveTopTabChanged() {
                                if (!controlLeftWindow.visible)
                                    return;
                                var isNext = (activeTopTab > previousTopTab);
                                if (activeTopTab === previousTopTab)
                                    return;

                                topOutgoingPage.source = "Pages/" + topPages[previousTopTab] + ".qml";
                                topOutgoingPage.x = 0;
                                topOutgoingPage.opacity = 1;

                                topSlideOutAnim.to = isNext ? -topPageContainer.width : topPageContainer.width;
                                topSlideOutAnim.restart();
                                topFadeOutAnim.restart();

                                topCurrentPage.x = isNext ? topPageContainer.width : -topPageContainer.width;
                                topSlideInAnim.restart();
                                topFadeInAnim.restart();
                            }

                            target: controlLeftWindow
                        }
                    }
                }
            }

            // ── 2. Bottom Tab Content Box ─────────────────────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                clip: true
                color: Config.md3.surface
                layer.enabled: controlLeftWindow.visible && !slideAnim.running
                radius: 15

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
                    Item {
                        id: bottomPageContainer

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true

                        Loader {
                            id: bottomOutgoingPage

                            active: source !== ""
                            height: bottomPageContainer.height
                            opacity: 0
                            width: bottomPageContainer.width
                            x: 0
                            z: 0

                            NumberAnimation on opacity {
                                id: bottomFadeOutAnim

                                duration: 220
                                easing.type: Easing.InQuad
                                running: false
                                to: 0

                                onFinished: {
                                    if (bottomOutgoingPage.opacity === 0)
                                        bottomOutgoingPage.source = "";
                                }
                            }
                            NumberAnimation on x {
                                id: bottomSlideOutAnim

                                duration: 320
                                easing.type: Easing.OutCubic
                                running: false
                            }
                        }
                        Loader {
                            id: bottomCurrentPage

                            active: controlLeftWindow.visible
                            height: bottomPageContainer.height
                            opacity: 1
                            source: "Pages/" + bottomPages[activeBottomTab] + ".qml"
                            width: bottomPageContainer.width
                            x: 0
                            z: 1

                            NumberAnimation on opacity {
                                id: bottomFadeInAnim

                                duration: 220
                                easing.type: Easing.OutQuad
                                from: 0.3
                                running: false
                                to: 1
                            }
                            NumberAnimation on x {
                                id: bottomSlideInAnim

                                duration: 320
                                easing.type: Easing.OutCubic
                                running: false
                                to: 0
                            }
                        }
                        Connections {
                            function onActiveBottomTabChanged() {
                                if (!controlLeftWindow.visible)
                                    return;
                                var isNext = (activeBottomTab > previousBottomTab);
                                if (activeBottomTab === previousBottomTab)
                                    return;

                                bottomOutgoingPage.source = "Pages/" + bottomPages[previousBottomTab] + ".qml";
                                bottomOutgoingPage.x = 0;
                                bottomOutgoingPage.opacity = 1;

                                bottomSlideOutAnim.to = isNext ? -bottomPageContainer.width : bottomPageContainer.width;
                                bottomSlideOutAnim.restart();
                                bottomFadeOutAnim.restart();

                                bottomCurrentPage.x = isNext ? bottomPageContainer.width : -bottomPageContainer.width;
                                bottomSlideInAnim.restart();
                                bottomFadeInAnim.restart();
                            }

                            target: controlLeftWindow
                        }
                    }
                }
            }
        }
    }
}
