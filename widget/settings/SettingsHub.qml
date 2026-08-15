import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool active: false
    property int activeNiriSection: 0
    property int activePage: 0
    property int activeQuickshellSection: 0
    property int activeSecuritySection: 0
    readonly property string activeSubtitle: activePage === 0 ? "Inspect and tune your Niri configuration" : activePage === 1 ? quickshellSectionSubtitles[activeQuickshellSection] : securitySectionSubtitles[activeSecuritySection]
    readonly property string activeTitle: activePage === 0 ? niriSectionNames[activeNiriSection] : activePage === 1 ? quickshellSectionNames[activeQuickshellSection] : securitySectionNames[activeSecuritySection]
    readonly property bool compactViewport: Responsive.constrained(width, height, 1916, 1148)
    property bool niriExpanded: true
    readonly property var niriSectionColors: [Config.md3.primary, Config.md3.secondary, Config.md3.primary, Config.md3.secondary, Config.md3.tertiary, Config.md3.error, Config.md3.primary]
    readonly property var niriSectionIcons: ["input-keyboard-symbolic", "view-grid-symbolic", "input-mouse-symbolic", "media-playback-start-symbolic", "emblem-system-symbolic", "view-list-symbolic", "text-x-generic-symbolic"]
    readonly property var niriSectionNames: ["Keybinds", "Layout", "Input", "Animations", "Behavior", "Rules", "Config files"]
    property int pendingPage: 0
    property int pendingSection: 0
    property bool quickshellExpanded: true
    readonly property var quickshellSectionColors: [Config.md3.secondary, Config.md3.primary, Config.md3.tertiary, Config.md3.primary, Config.md3.tertiary, Config.md3.primary, Config.md3.error, Config.md3.secondary]
    readonly property var quickshellSectionIcons: ["preferences-desktop-theme-symbolic", "view-grid-symbolic", "system-search-symbolic", "preferences-system-notifications-symbolic", "preferences-desktop-wallpaper-symbolic", "camera-photo-symbolic", "network-workgroup-symbolic", "applications-engineering-symbolic"]
    readonly property var quickshellSectionNames: ["General", "Bar & Panels", "Launcher", "Notifications", "Wallpaper", "Capture", "Integrations", "Advanced"]
    readonly property var quickshellSectionSubtitles: ["Configure shell appearance and localization", "Choose bar density and visible modules", "Tune providers, prefixes, and clipboard behavior", "Control popups, history, rules, and Do Not Disturb", "Configure wallpaper playback and colors", "Configure screenshots and screen recording", "Configure external services and integrations", "Tune performance, OSD, audio, and diagnostics"]
    readonly property var searchItems: [
        {
            "title": "Keybinds",
            "group": "Niri",
            "keywords": "keyboard shortcuts binds",
            "page": 0,
            "section": 0
        },
        {
            "title": "Layout",
            "group": "Niri",
            "keywords": "gaps border shadow columns overview",
            "page": 0,
            "section": 1
        },
        {
            "title": "Input",
            "group": "Niri",
            "keywords": "mouse touchpad keyboard trackpoint tablet",
            "page": 0,
            "section": 2
        },
        {
            "title": "Animations",
            "group": "Niri",
            "keywords": "motion easing slowdown",
            "page": 0,
            "section": 3
        },
        {
            "title": "Behavior",
            "group": "Niri",
            "keywords": "focus workspace cursor screenshot",
            "page": 0,
            "section": 4
        },
        {
            "title": "Rules",
            "group": "Niri",
            "keywords": "window layer app rules",
            "page": 0,
            "section": 5
        },
        {
            "title": "Config files",
            "group": "Niri",
            "keywords": "advanced kdl autostart environment",
            "page": 0,
            "section": 6
        },
        {
            "title": "General",
            "group": "Quickshell",
            "keywords": "font clock appearance localization",
            "page": 1,
            "section": 0
        },
        {
            "title": "Bar & Panels",
            "group": "Quickshell",
            "keywords": "height density widgets systray battery clock workspace media",
            "page": 1,
            "section": 1
        },
        {
            "title": "Launcher",
            "group": "Quickshell",
            "keywords": "apps files clipboard emoji calculator prefix fuzzy paste",
            "page": 1,
            "section": 2
        },
        {
            "title": "Notifications",
            "group": "Quickshell",
            "keywords": "popup history dnd fullscreen lock application rules",
            "page": 1,
            "section": 3
        },
        {
            "title": "Wallpaper",
            "group": "Quickshell",
            "keywords": "matugen theme colors video engine wallhaven",
            "page": 1,
            "section": 4
        },
        {
            "title": "Capture",
            "group": "Quickshell",
            "keywords": "screenshot recording codec fps microphone",
            "page": 1,
            "section": 5
        },
        {
            "title": "Integrations",
            "group": "Quickshell",
            "keywords": "weather google steam wallhaven api",
            "page": 1,
            "section": 6
        },
        {
            "title": "Advanced",
            "group": "Quickshell",
            "keywords": "performance animation reduced motion osd audio diagnostics cache dependencies",
            "page": 1,
            "section": 7
        },
        {
            "title": "Lock & Face",
            "group": "Security",
            "keywords": "howdy camera authentication password",
            "page": 2,
            "section": 0
        },
        {
            "title": "Idle & Power",
            "group": "Security",
            "keywords": "swayidle lock suspend screen display caffeine timeout",
            "page": 2,
            "section": 1
        }
    ]
    property bool securityExpanded: true
    readonly property var securitySectionColors: [Config.md3.primary, Config.md3.tertiary]
    readonly property var securitySectionIcons: ["avatar-default-symbolic", "preferences-system-power-symbolic"]
    readonly property var securitySectionNames: ["Lock & Face", "Idle & Power"]
    readonly property var securitySectionSubtitles: ["Manage lock screen authentication and face models", "Configure idle, display-off, suspend, and Caffeine behavior"]
    property bool sidebarExpanded: true
    property real sidebarWidth: sidebarExpanded ? (compactViewport ? 240 : 264) : (compactViewport ? 78 : 84)

    signal dismissed

    function closeSettings() {
        active = false;
        closeTimer.restart();
    }
    function legacyQuickshellSection() {
        if (activeQuickshellSection === 4)
            return 1;
        if (activeQuickshellSection === 5)
            return 2;
        if (activeQuickshellSection === 6)
            return 3;
        return 0;
    }
    function openSettings() {
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;
        closeTimer.stop();
        sectionTransition.stop();
        pageFrame.opacity = 1;
        pageFrame.x = 0;
        visible = true;
        active = true;
        panel.forceActiveFocus();
        SettingsHubService.refresh();
    }
    function pageSource() {
        if (activePage === 0)
            return "NiriSettingsPage.qml";
        if (activePage === 2)
            return activeSecuritySection === 0 ? "SecuritySettingsPage.qml" : "IdlePowerSettingsPage.qml";
        if (activeQuickshellSection === 1)
            return "BarSettingsPage.qml";
        if (activeQuickshellSection === 2)
            return "LauncherSettingsPage.qml";
        if (activeQuickshellSection === 3)
            return "NotificationSettingsPage.qml";
        if (activeQuickshellSection === 7)
            return "AdvancedSettingsPage.qml";
        return "QuickshellSettingsPage.qml";
    }
    function switchSection(page, section) {
        var currentSection = page === 0 ? activeNiriSection : page === 1 ? activeQuickshellSection : activeSecuritySection;
        if (activePage === page && currentSection === section)
            return;

        pendingPage = page;
        pendingSection = section;
        sectionTransition.stop();
        sectionTransition.restart();
    }

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    exclusiveZone: 0
    focusable: true
    visible: false

    Behavior on sidebarWidth {
        NumberAnimation {
            duration: Config.animationDuration(220)
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: closeTimer

        interval: 230
        repeat: false

        onTriggered: {
            root.visible = false;
            root.dismissed();
        }
    }
    SequentialAnimation {
        id: sectionTransition

        ParallelAnimation {
            NumberAnimation {
                duration: Config.animationDuration(85)
                easing.type: Easing.InQuad
                property: "opacity"
                target: pageFrame
                to: 0
            }
            NumberAnimation {
                duration: Config.animationDuration(85)
                easing.type: Easing.InQuad
                property: "x"
                target: pageFrame
                to: 10
            }
        }
        ScriptAction {
            script: {
                root.activePage = root.pendingPage;
                if (root.pendingPage === 0)
                    root.activeNiriSection = root.pendingSection;
                else if (root.pendingPage === 1)
                    root.activeQuickshellSection = root.pendingSection;
                else
                    root.activeSecuritySection = root.pendingSection;
                pageFrame.x = -10;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                duration: Config.animationDuration(175)
                easing.type: Easing.OutCubic
                property: "opacity"
                target: pageFrame
                to: 1
            }
            NumberAnimation {
                duration: Config.animationDuration(175)
                easing.type: Easing.OutCubic
                property: "x"
                target: pageFrame
                to: 0
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: !SettingsHubService.filePickerActive

        onClicked: root.closeSettings()
    }
    Rectangle {
        id: panel

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.08)
        border.width: 1
        clip: true
        color: Config.alpha(Config.md3.background, 0.985)
        focus: true
        height: Responsive.fitWithMargins(1120, root.height, root.compactViewport ? 8 : 14, 480)
        opacity: root.active ? 1 : 0
        radius: root.compactViewport ? 22 : 30
        scale: root.active ? 1 : 0.96
        width: Responsive.fitWithMargins(1880, root.width, root.compactViewport ? 10 : 18, 640)

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(190)
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(230)
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeSettings();
                event.accepted = true;
            }
        }

        AnimatedStars {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            color: Config.md3.primary
            height: Math.min(panel.height, root.compactViewport ? 180 : 260)
            running: root.active && !Config.shellLowPowerMode
            starCount: root.compactViewport ? 40 : 64
        }
        MouseArea {
            anchors.fill: parent

            onClicked: panel.forceActiveFocus(Qt.MouseFocusReason)
        }
        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: root.sidebarWidth
                color: Config.alpha(Config.md3.on_surface, 0.025)

                Flickable {
                    id: sidebarFlickable

                    readonly property real contentInset: root.sidebarExpanded ? (root.compactViewport ? 16 : 22) : 12

                    anchors.fill: parent
                    boundsBehavior: Flickable.StopAtBounds
                    clip: contentHeight > height
                    contentHeight: Math.max(height, sidebarContent.implicitHeight + contentInset * 2)
                    contentWidth: width
                    flickableDirection: Flickable.VerticalFlick
                    interactive: contentHeight > height

                    ColumnLayout {
                        id: sidebarContent

                        height: Math.max(implicitHeight, sidebarFlickable.height - sidebarFlickable.contentInset * 2)
                        spacing: root.compactViewport ? 7 : 10
                        width: Math.max(0, sidebarFlickable.width - sidebarFlickable.contentInset * 2)
                        x: sidebarFlickable.contentInset
                        y: sidebarFlickable.contentInset

                        Item {
                            Layout.bottomMargin: 16
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: expandButton.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                visible: root.sidebarExpanded

                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 22
                                    font.weight: Font.Bold
                                    text: "Settings"
                                }
                                Text {
                                    color: Config.alpha(Config.md3.on_surface, 0.48)
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    text: "Niri & Quickshell"
                                }
                            }
                            Rectangle {
                                id: expandButton

                                Layout.preferredHeight: 42
                                Layout.preferredWidth: 42
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: expandMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : Config.alpha(Config.md3.on_surface, 0.045)
                                height: 42
                                radius: 13
                                width: 42

                                Text {
                                    anchors.centerIn: parent
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 24
                                    text: root.sidebarExpanded ? "‹" : "›"
                                }
                                MouseArea {
                                    id: expandMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: root.sidebarExpanded = !root.sidebarExpanded
                                }
                            }
                        }
                        SettingsSearch {
                            Layout.bottomMargin: 6
                            Layout.fillWidth: true
                            items: root.searchItems
                            visible: root.sidebarExpanded

                            onSelected: (page, section) => root.switchSection(page, section)
                        }
                        SettingsNavButton {
                            Layout.fillWidth: true
                            active: root.activePage === 0 && (!root.sidebarExpanded || !root.niriExpanded)
                            compact: !root.sidebarExpanded
                            expandable: true
                            expanded: root.niriExpanded
                            iconColor: Config.md3.primary
                            iconName: "emblem-system-symbolic"
                            text: "Niri"

                            onClicked: {
                                const wasActive = root.activePage === 0;
                                if (!root.sidebarExpanded) {
                                    root.sidebarExpanded = true;
                                    root.niriExpanded = true;
                                } else if (!wasActive) {
                                    root.niriExpanded = true;
                                } else {
                                    root.niriExpanded = !root.niriExpanded;
                                }
                                if (!wasActive)
                                    root.switchSection(0, root.activeNiriSection);
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: root.sidebarExpanded && root.niriExpanded

                            Repeater {
                                model: root.niriSectionNames.length

                                delegate: SettingsNavButton {
                                    required property int index

                                    Layout.fillWidth: true
                                    active: root.activePage === 0 && root.activeNiriSection === index
                                    dense: true
                                    iconColor: root.niriSectionColors[index]
                                    iconName: root.niriSectionIcons[index]
                                    indented: true
                                    text: root.niriSectionNames[index]

                                    onClicked: {
                                        root.switchSection(0, index);
                                    }
                                }
                            }
                        }
                        SettingsNavButton {
                            Layout.fillWidth: true
                            active: root.activePage === 1 && (!root.sidebarExpanded || !root.quickshellExpanded)
                            compact: !root.sidebarExpanded
                            expandable: true
                            expanded: root.quickshellExpanded
                            iconColor: Config.md3.secondary
                            iconName: "applications-system-symbolic"
                            text: "Quickshell"

                            onClicked: {
                                const wasActive = root.activePage === 1;
                                if (!root.sidebarExpanded) {
                                    root.sidebarExpanded = true;
                                    root.quickshellExpanded = true;
                                } else if (!wasActive) {
                                    root.quickshellExpanded = true;
                                } else {
                                    root.quickshellExpanded = !root.quickshellExpanded;
                                }
                                if (!wasActive)
                                    root.switchSection(1, root.activeQuickshellSection);
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: root.sidebarExpanded && root.quickshellExpanded

                            Repeater {
                                model: root.quickshellSectionNames.length

                                delegate: SettingsNavButton {
                                    required property int index

                                    Layout.fillWidth: true
                                    active: root.activePage === 1 && root.activeQuickshellSection === index
                                    dense: true
                                    iconColor: root.quickshellSectionColors[index]
                                    iconName: root.quickshellSectionIcons[index]
                                    indented: true
                                    text: root.quickshellSectionNames[index]

                                    onClicked: {
                                        root.switchSection(1, index);
                                    }
                                }
                            }
                        }
                        SettingsNavButton {
                            Layout.fillWidth: true
                            active: root.activePage === 2 && (!root.sidebarExpanded || !root.securityExpanded)
                            compact: !root.sidebarExpanded
                            expandable: true
                            expanded: root.securityExpanded
                            iconColor: Config.md3.primary
                            iconName: "system-lock-screen-symbolic"
                            text: "Security"

                            onClicked: {
                                const wasActive = root.activePage === 2;
                                if (!root.sidebarExpanded) {
                                    root.sidebarExpanded = true;
                                    root.securityExpanded = true;
                                } else if (!wasActive) {
                                    root.securityExpanded = true;
                                } else {
                                    root.securityExpanded = !root.securityExpanded;
                                }
                                if (!wasActive)
                                    root.switchSection(2, root.activeSecuritySection);
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: root.sidebarExpanded && root.securityExpanded

                            Repeater {
                                model: root.securitySectionNames.length

                                delegate: SettingsNavButton {
                                    required property int index

                                    Layout.fillWidth: true
                                    active: root.activePage === 2 && root.activeSecuritySection === index
                                    dense: true
                                    iconColor: root.securitySectionColors[index]
                                    iconName: root.securitySectionIcons[index]
                                    indented: true
                                    text: root.securitySectionNames[index]

                                    onClicked: root.switchSection(2, index)
                                }
                            }
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(SettingsHubService.statusSuccess ? Config.md3.on_surface : Config.md3.error, 0.055)
                            implicitHeight: statusColumn.implicitHeight + 26
                            radius: 14
                            visible: root.sidebarExpanded && SettingsHubService.statusMessage !== ""

                            ColumnLayout {
                                id: statusColumn

                                anchors.fill: parent
                                anchors.margins: 13
                                spacing: 5

                                Text {
                                    Layout.fillWidth: true
                                    color: SettingsHubService.statusSuccess ? Config.md3.on_surface : Config.md3.error
                                    font.family: Config.fontName
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    text: SettingsHubService.statusSuccess ? "Saved" : "Needs attention"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.alpha(Config.md3.on_surface, 0.58)
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    text: SettingsHubService.statusMessage
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.35)
                            font.family: Config.fontName
                            font.pixelSize: 12
                            text: "Reads config only while opened"
                            visible: root.sidebarExpanded
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Config.alpha(Config.md3.on_surface, 0.065)
            }
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.margins: root.compactViewport ? 18 : 32
                Layout.minimumWidth: 0
                spacing: root.compactViewport ? 12 : 20

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.compactViewport ? 112 : 62

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: root.compactViewport ? parent.right : headerActions.left
                        anchors.rightMargin: root.compactViewport ? 0 : 18
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: root.compactViewport ? -25 : 0
                        spacing: 3

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: root.compactViewport ? 26 : 30
                            font.weight: Font.Bold
                            text: root.activeTitle
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.5)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 15
                            maximumLineCount: 1
                            text: root.activeSubtitle
                        }
                    }
                    RowLayout {
                        id: headerActions

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: root.compactViewport ? 32 : 0
                        spacing: 10

                        SettingsActionButton {
                            enabled: !SettingsHubService.busy
                            iconName: "edit-undo-symbolic"
                            text: "Reset"
                            visible: Boolean(pageLoader.item && pageLoader.item.headerResetVisible === true)

                            onClicked: {
                                if (pageLoader.item && pageLoader.item.resetPage)
                                    pageLoader.item.resetPage();
                            }
                        }
                        SettingsActionButton {
                            enabled: Boolean(pageLoader.item && pageLoader.item.headerActionEnabled !== false && !SettingsHubService.busy)
                            iconName: pageLoader.item ? pageLoader.item.headerActionIcon || "document-save-symbolic" : "document-save-symbolic"
                            primary: true
                            text: pageLoader.item ? pageLoader.item.headerActionText || "Apply" : "Apply"
                            visible: Boolean(pageLoader.item && pageLoader.item.headerActionVisible === true)

                            onClicked: {
                                if (pageLoader.item && pageLoader.item.triggerHeaderAction)
                                    pageLoader.item.triggerHeaderAction();
                            }
                        }
                        Rectangle {
                            id: closeButton

                            Layout.preferredHeight: 44
                            Layout.preferredWidth: 44
                            color: closeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.1) : Config.alpha(Config.md3.on_surface, 0.05)
                            radius: 14

                            Text {
                                anchors.centerIn: parent
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 23
                                text: "×"
                            }
                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: root.closeSettings()
                            }
                        }
                    }
                }
                Item {
                    id: pageFrame

                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    Loader {
                        id: pageLoader

                        active: root.visible
                        anchors.fill: parent
                        asynchronous: false
                        source: root.pageSource()

                        onLoaded: {
                            if (root.activePage === 0 && item)
                                item.activeSection = Qt.binding(() => root.activeNiriSection);
                            else if (root.activePage === 1 && item && root.pageSource() === "QuickshellSettingsPage.qml")
                                item.activeSection = Qt.binding(() => root.legacyQuickshellSection());
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: SettingsHubService.busy && !SettingsHubService.ready

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Config.alpha(Config.md3.primary, 0.18)
                            height: 42
                            radius: 21
                            width: 42

                            Text {
                                anchors.centerIn: parent
                                color: Config.md3.primary
                                font.family: Config.fontName
                                font.pixelSize: 19
                                text: "…"
                            }
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.58)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            text: "Reading configuration"
                        }
                    }
                }
            }
        }
    }
}
