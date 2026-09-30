import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

FloatingWindow {
    id: root

    property bool active: false
    property int activeNiriSection: 0
    property int activePage: homePage
    property int activeQuickshellSection: 0
    property int activeSecuritySection: 0
    readonly property string activeSubtitle: activePage === homePage ? qsTr("Make your desktop feel like home") : activePage === 0 ? "Inspect and tune your Niri configuration" : activePage === 1 ? quickshellSectionSubtitles[activeQuickshellSection] : securitySectionSubtitles[activeSecuritySection]
    readonly property string activeTitle: activePage === homePage ? qsTr("Home") : activePage === 0 ? niriSectionNames[activeNiriSection] : activePage === 1 ? quickshellSectionNames[activeQuickshellSection] : securitySectionNames[activeSecuritySection]
    property bool blurActive: false
    readonly property bool compactHeader: settingsContentWidth < 740
    readonly property bool compactHeight: Responsive.isCompactHeight(height)
    readonly property var compactNavigationItems: {
        var items = [];
        var index = 0;

        for (index = 0; index < niriSectionNames.length; ++index) {
            items.push({
                "divider": false,
                "icon": niriSectionIcons[index],
                "page": 0,
                "section": index,
                "title": niriSectionNames[index]
            });
        }
        for (index = 0; index < quickshellSectionNames.length; ++index) {
            items.push({
                "divider": index === 0,
                "icon": quickshellSectionIcons[index],
                "page": 1,
                "section": index,
                "title": quickshellSectionNames[index]
            });
        }
        for (index = 0; index < securitySectionNames.length; ++index) {
            items.push({
                "divider": index === 0,
                "icon": securitySectionIcons[index],
                "page": 2,
                "section": index,
                "title": securitySectionNames[index]
            });
        }
        return items;
    }
    readonly property real compactSidebarWidth: compactViewport ? 80 : 84
    readonly property bool compactViewport: compactWidth || (Responsive.isMediumWidth(width) && compactHeight)
    readonly property bool compactWidth: Responsive.isCompactWidth(width)
    readonly property real expandedSidebarWidth: width < 1100 ? 280 : 320
    readonly property int homePage: 3
    property bool niriExpanded: true
    readonly property var niriSectionColors: [Config.md3.secondary, Config.md3.secondary, Config.md3.secondary, Config.md3.secondary, Config.md3.secondary, Config.md3.secondary, Config.md3.secondary]
    readonly property var niriSectionIcons: ["input-keyboard-symbolic", "view-grid-symbolic", "input-mouse-symbolic", "media-playback-start-symbolic", "emblem-system-symbolic", "view-list-symbolic", "text-x-generic-symbolic"]
    readonly property var niriSectionNames: [qsTr("Keybinds"), qsTr("Layout"), qsTr("Input"), qsTr("Animations"), qsTr("Behavior"), qsTr("Rules"), qsTr("Config files")]
    readonly property var niriSectionSummaries: [qsTr("Keyboard shortcuts"), qsTr("Gaps, borders and workspaces"), qsTr("Keyboard, mouse and touchpad"), qsTr("Motion and transitions"), qsTr("Focus and window behavior"), qsTr("Window and layer rules"), qsTr("Advanced Niri configuration")]
    property int pendingPage: homePage
    property int pendingSection: 0
    property bool quickshellExpanded: true
    readonly property var quickshellSectionColors: [Config.md3.primary, Config.md3.primary, Config.md3.primary, Config.md3.primary, Config.md3.primary, Config.md3.primary, Config.md3.primary, Config.md3.primary]
    readonly property var quickshellSectionIcons: ["preferences-desktop-theme-symbolic", "view-grid-symbolic", "system-search-symbolic", "preferences-system-notifications-symbolic", "preferences-desktop-wallpaper-symbolic", "camera-photo-symbolic", "network-workgroup-symbolic", "applications-engineering-symbolic"]
    readonly property var quickshellSectionNames: [qsTr("General"), qsTr("Bar & Panels"), qsTr("Launcher"), qsTr("Notifications"), qsTr("Wallpaper"), qsTr("Capture"), qsTr("Integrations"), qsTr("Advanced")]
    readonly property var quickshellSectionSubtitles: [qsTr("Configure shell appearance and localization"), qsTr("Choose bar density and visible modules"), qsTr("Tune providers, prefixes, and clipboard behavior"), qsTr("Control popups, history, rules, and Do Not Disturb"), qsTr("Configure wallpaper playback and colors"), qsTr("Configure screenshots and screen recording"), qsTr("Configure external services and integrations"), qsTr("Tune performance, OSD, audio, and diagnostics")]
    readonly property var quickshellSectionSummaries: [qsTr("Appearance, fonts and applications"), qsTr("Layout, position and widgets"), qsTr("Search, apps and clipboard"), qsTr("Popups, history and rules"), qsTr("Wallpapers, playback and colors"), qsTr("Screenshots and recording"), qsTr("Accounts and external services"), qsTr("Performance, audio and diagnostics")]
    property bool resizeActive: false
    readonly property var searchItems: [
        {
            "title": qsTr("Home"),
            "group": "Settings",
            "keywords": "overview appearance personalization desktop security",
            "page": homePage,
            "section": 0
        },
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
            "keywords": "font clock appearance localization blur shadow opacity spread offset transparency effects",
            "page": 1,
            "section": 0
        },
        {
            "title": "Bar & Panels",
            "group": "Quickshell",
            "keywords": "height density widgets systray battery clock workspace media weather temperature",
            "page": 1,
            "section": 1
        },
        {
            "title": "Launcher",
            "group": "Quickshell",
            "keywords": "apps files clipboard emoji unicode symbol math character calculator gif sticker prefix fuzzy paste",
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
            "keywords": "weather google steam wallhaven klipy gif sticker launcher media api key",
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
        },

        // Searchable controls inside each page. These entries intentionally
        // point to their owning tab so a lazy-loaded page is opened first.
        searchEntry("Shell font", "General · Fonts", "font typeface inter variable sf pro typography", 1, 0), searchEntry("Application font", "General · Fonts", "font gtk qt app application text", 1, 0), searchEntry("Application font size", "General · Fonts", "font size scale text", 1, 0), searchEntry("GTK theme", "General · Appearance", "gtk theme adw dark light application", 1, 0), searchEntry("Icon theme", "General · Appearance", "icons whitesur theme", 1, 0), searchEntry("Cursor theme", "General · Appearance", "cursor mouse pointer theme", 1, 0), searchEntry("Cursor size", "General · Appearance", "cursor mouse pointer size", 1, 0), searchEntry("Interactive terminal", "General · Default applications", "terminal blackbox black box update steamcmd", 1, 0), searchEntry("Folder editor", "General · Default applications", "editor neovide vscode code launcher folder", 1, 0), searchEntry("Qt widget style", "General · Qt integration", "qt qt5 qt6 widget style controls", 1, 0), searchEntry("Qt color scheme", "General · Qt integration", "qt dark light color scheme palette", 1, 0), searchEntry("Standard dialogs", "General · Qt integration", "qt file picker dialog native", 1, 0), searchEntry("Panel blur", "General · Surface blur", "blur transparency opacity panel bar launcher osd notification settings", 1, 0), searchEntry("Panel shadows", "General · Shadows", "shadow blur opacity spread offset panel", 1, 0), searchEntry("Component shadows", "General · Shadows", "shadow blur opacity spread offset component", 1, 0), searchEntry("24-hour time format", "General · Date & time", "clock time date 12 24 hour", 1, 0), searchEntry("Temperature unit", "General · Date & time", "weather temperature celsius fahrenheit c f", 1, 0), searchEntry("Bar height", "Bar & Panels · Layout", "bar panel height size px", 1, 1), searchEntry("Bar density", "Bar & Panels · Layout", "bar panel density compact spacing", 1, 1), searchEntry("Active application", "Bar & Panels · Left and center", "bar app window title active", 1, 1), searchEntry("Media module", "Bar & Panels · Left and center", "bar media music player mpris", 1, 1), searchEntry("Workspace module", "Bar & Panels · Left and center", "bar workspace niri", 1, 1), searchEntry("System tray", "Bar & Panels · Status area", "bar tray systray status icon", 1, 1), searchEntry("Weather module", "Bar & Panels · Status area", "bar weather temperature forecast", 1, 1), searchEntry("Clock and date", "Bar & Panels · Status area", "bar clock date time calendar", 1, 1), searchEntry("Maximum launcher results", "Launcher · Search", "launcher search results limit count", 1, 2), searchEntry("Fuzzy matching", "Launcher · Search", "launcher search fuzzy matching", 1, 2), searchEntry("Automatic clipboard paste", "Launcher · Search", "launcher clipboard paste enter", 1, 2), searchEntry("Emoji and Unicode provider", "Launcher · Providers", "launcher emoji unicode symbols characters", 1, 2), searchEntry("GIF search provider", "Launcher · Providers", "launcher gif klipy search", 1, 2), searchEntry("Sticker search provider", "Launcher · Providers", "launcher sticker klipy search", 1, 2), searchEntry("Clipboard prefix", "Launcher · Prefixes", "launcher clipboard prefix", 1, 2), searchEntry("Calculator prefix", "Launcher · Prefixes", "launcher calculator math prefix", 1, 2), searchEntry("Maximum visible notifications", "Notifications · Popups", "notification popup visible limit count", 1, 3), searchEntry("Notification position", "Notifications · Popups", "notification popup position top bottom left right", 1, 3), searchEntry("Fullscreen notifications", "Notifications · Popups", "notification fullscreen game application", 1, 3), searchEntry("Lock screen privacy", "Notifications · Popups", "notification lock screen privacy content", 1, 3), searchEntry("Notification timeout", "Notifications · Timeouts", "notification timeout low normal critical duration", 1, 3), searchEntry("Do Not Disturb schedule", "Notifications · Do Not Disturb", "notification dnd schedule start end", 1, 3), searchEntry("Notification history limit", "Notifications · History", "notification history limit storage", 1, 3), searchEntry("Image wallpaper folder", "Wallpaper · Library", "wallpaper image folder directory", 1, 4), searchEntry("Video wallpaper folder", "Wallpaper · Library", "wallpaper video live folder directory", 1, 4), searchEntry("Wallpaper scaling mode", "Wallpaper · Playback", "wallpaper scale fit crop stretch", 1, 4), searchEntry("Wallpaper engine FPS", "Wallpaper · Playback", "wallpaper engine fps performance battery", 1, 4), searchEntry("Wallpaper transition", "Wallpaper · Playback", "wallpaper animation transition duration", 1, 4), searchEntry("Pause wallpaper fullscreen", "Wallpaper · Playback", "wallpaper pause fullscreen", 1, 4), searchEntry("Generate dynamic colors", "Wallpaper · Matugen", "wallpaper matugen dynamic colors theme", 1, 4), searchEntry("Animate shell colors", "Wallpaper · Matugen", "wallpaper matugen animate colors transition", 1, 4), searchEntry("Screenshot folder", "Capture · Storage", "screenshot capture image folder path", 1, 5), searchEntry("Recording folder", "Capture · Storage", "screen recording video folder path", 1, 5), searchEntry("Default editor tool", "Capture · Screenshot", "screenshot editor tool select crop blur annotate", 1, 5), searchEntry("After capture", "Capture · Screenshot", "screenshot after capture copy edit save", 1, 5), searchEntry("Image format", "Capture · Screenshot", "screenshot png jpg webp format", 1, 5), searchEntry("Image quality", "Capture · Screenshot", "screenshot image quality compression", 1, 5), searchEntry("Capture area", "Capture · Recording", "recording capture area screen region", 1, 5), searchEntry("Frame rate", "Capture · Encoding", "recording fps frame rate", 1, 5), searchEntry("Recording codec", "Capture · Encoding", "recording codec h264 h265 vp9", 1, 5), searchEntry("Record microphone", "Capture · Behavior", "recording microphone audio source", 1, 5), searchEntry("Weather location", "Integrations · Weather", "weather location coordinates", 1, 6), searchEntry("OpenWeatherMap API key", "Integrations · Weather", "weather openweathermap api key", 1, 6), searchEntry("Google Tasks", "Integrations · Productivity", "google tasks todo calendar account sync", 1, 6), searchEntry("KLIPY API key", "Integrations · Launcher", "klipy gif sticker api key", 1, 6), searchEntry("Tailscale integration", "Integrations · Network", "tailscale vpn online peers bar", 1, 6), searchEntry("Animation scale", "Advanced · Motion", "advanced animation scale speed", 1, 7), searchEntry("Reduce motion", "Advanced · Motion", "advanced reduced motion animation accessibility", 1, 7), searchEntry("Low-power rendering", "Advanced · Motion", "advanced low power performance rendering", 1, 7), searchEntry("Enable OSD", "Advanced · OSD and audio", "advanced osd volume microphone brightness", 1, 7), searchEntry("OSD duration", "Advanced · OSD and audio", "advanced osd duration timeout", 1, 7), searchEntry("Maximum volume", "Advanced · OSD and audio", "advanced audio volume maximum", 1, 7), searchEntry("Cache", "Advanced · Diagnostics", "advanced cache diagnostics data cleanup", 1, 7), searchEntry("Keybind search", "Niri · Keybinds", "niri keybind shortcut keyboard action", 0, 0), searchEntry("Gaps", "Niri · Layout", "niri layout gaps spacing", 0, 1), searchEntry("Borders", "Niri · Layout", "niri layout border width radius color", 0, 1), searchEntry("Shadow", "Niri · Layout", "niri layout shadow blur spread", 0, 1), searchEntry("Keyboard layout", "Niri · Input", "niri input keyboard layout", 0, 2), searchEntry("Touchpad", "Niri · Input", "niri input touchpad tap scroll", 0, 2), searchEntry("Animation engine", "Niri · Animations", "niri animation speed transition", 0, 3), searchEntry("Focus follows pointer", "Niri · Behavior", "niri focus pointer mouse", 0, 4), searchEntry("Hot corners", "Niri · Behavior", "niri hot corner gesture", 0, 4), searchEntry("Cursor behavior", "Niri · Behavior", "niri cursor theme size hide typing", 0, 4), searchEntry("Face authentication", "Lock & Face · Unlock", "security lock face howdy authentication", 2, 0), searchEntry("Camera device", "Lock & Face · Camera", "security face camera device webcam", 2, 0), searchEntry("Face models", "Lock & Face · Models", "security face model enroll", 2, 0), searchEntry("Greeter session", "Lock & Face · Greeter", "security greetd greeter session", 2, 0), searchEntry("Lock screen privacy", "Lock & Face · Notifications", "security lock notification privacy", 2, 0), searchEntry("Idle management", "Idle & Power · Policy", "power idle swayidle timeout", 2, 1), searchEntry("Lock before sleep", "Idle & Power · Schedule", "power sleep lock suspend", 2, 1), searchEntry("Display off timeout", "Idle & Power · Schedule", "power display off screen timeout", 2, 1), searchEntry("Dim before display off", "Idle & Power · Dimming", "power dim brightness display", 2, 1), searchEntry("Caffeine", "Idle & Power · Caffeine", "power caffeine prevent sleep awake", 2, 1)]
    property bool securityExpanded: true
    readonly property var securitySectionColors: [Config.md3.tertiary, Config.md3.tertiary]
    readonly property var securitySectionIcons: ["avatar-default-symbolic", "preferences-system-power-symbolic"]
    readonly property var securitySectionNames: [qsTr("Lock & Face"), qsTr("Idle & Power")]
    readonly property var securitySectionSubtitles: [qsTr("Manage lock screen authentication and face models"), qsTr("Configure idle, display-off, suspend, and Caffeine behavior")]
    readonly property var securitySectionSummaries: [qsTr("Lock screen and authentication"), qsTr("Timeouts, suspend and Caffeine")]
    readonly property real settingsContentWidth: Math.max(0, width - sidebarWidth - 1 - (compactViewport ? 20 : 36))
    property bool sidebarExpanded: !compactWidth
    readonly property real sidebarProgress: {
        var range = expandedSidebarWidth - compactSidebarWidth;
        if (range <= 0)
            return sidebarExpanded ? 1 : 0;
        return Math.max(0, Math.min(1, (sidebarWidth - compactSidebarWidth) / range));
    }
    readonly property real sidebarTargetWidth: sidebarExpanded ? expandedSidebarWidth : compactSidebarWidth
    property real sidebarWidth: sidebarTargetWidth

    signal dismissed

    function beginSystemResize(edges) {
        resizeActive = true;
        resizeIdleTimer.restart();
        startSystemResize(edges);
    }
    function closeSettings() {
        if (!active)
            return;
        blurAcquireTimer.stop();
        resizeIdleTimer.stop();
        resizeActive = false;
        visible = false;
        active = false;
        SettingsHubService.endEditorSession();
        dismissed();
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
        blurAcquireTimer.stop();
        blurActive = false;
        resizeIdleTimer.stop();
        resizeActive = false;
        sectionTransition.stop();
        pageFrame.opacity = 1;
        pageFrame.x = 0;
        if (!active) {
            activePage = homePage;
            pendingPage = homePage;
            pendingSection = 0;
            sidebarFlickable.contentY = 0;
        }
        visible = true;
        active = true;
        SettingsHubService.beginEditorSession();
        blurAcquireTimer.restart();
        panel.forceActiveFocus();
        SettingsHubService.refresh();
    }
    function pageSource() {
        if (activePage === homePage)
            return "SettingsHomePage.qml";
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
    function searchEntry(title, group, keywords, page, section) {
        return {
            "group": group,
            "keywords": keywords,
            "page": page,
            "section": section,
            "title": title
        };
    }
    function sectionColor(page, section) {
        if (page === 0)
            return niriSectionColors[section];
        if (page === 1)
            return quickshellSectionColors[section];
        return securitySectionColors[section];
    }
    function switchSection(page, section) {
        var currentSection = page === homePage ? 0 : page === 0 ? activeNiriSection : page === 1 ? activeQuickshellSection : activeSecuritySection;
        if (activePage === page && currentSection === section)
            return;

        pendingPage = page;
        pendingSection = section;
        sectionTransition.stop();
        sectionTransition.restart();
    }

    color: "transparent"
    implicitHeight: 860
    implicitWidth: 1240
    minimumSize: Qt.size(720, 520)
    title: "SownteeShell Settings"
    visible: false

    BackgroundEffect.blurRegion: Region {
        item: Config.shellBlurSettingsEnabled && root.blurActive ? panelBlurRegion : null
        radius: panel.radius
    }
    Behavior on sidebarWidth {
        enabled: !root.resizeActive

        NumberAnimation {
            duration: Config.animationDuration(280)
            easing.type: root.sidebarExpanded ? Easing.OutCubic : Easing.InOutCubic
        }
    }

    Component.onDestruction: SettingsHubService.endEditorSession()
    onClosed: {
        if (!root.active)
            return;

        blurAcquireTimer.stop();
        resizeIdleTimer.stop();
        root.active = false;
        root.resizeActive = false;
        root.visible = false;
        SettingsHubService.endEditorSession();
        root.dismissed();
    }
    onHeightChanged: {
        if (resizeActive)
            resizeIdleTimer.restart();
    }
    onWidthChanged: {
        if (resizeActive)
            resizeIdleTimer.restart();
    }

    // Match Calendar's entrance; retain the acquired blur until the surface closes.
    Timer {
        id: blurAcquireTimer

        interval: Math.max(1, Config.animationDuration(40))
        repeat: false

        onTriggered: {
            if (root.active)
                root.blurActive = true;
        }
    }
    Timer {
        id: resizeIdleTimer

        interval: 140
        repeat: false

        onTriggered: root.resizeActive = false
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
                else if (root.pendingPage === 2)
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
    Item {
        id: panelBlurRegion

        anchors.fill: panel
    }
    Item {
        id: resizeHandles

        readonly property int cornerSize: 14
        readonly property int edgeSize: 7

        anchors.fill: parent
        enabled: root.active && !root.maximized
        z: 100

        MouseArea {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: resizeHandles.cornerSize
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: resizeHandles.cornerSize
            cursorShape: Qt.SizeHorCursor
            hoverEnabled: true
            width: resizeHandles.edgeSize

            onPressed: root.beginSystemResize(Qt.LeftEdge)
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: resizeHandles.cornerSize
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: resizeHandles.cornerSize
            cursorShape: Qt.SizeHorCursor
            hoverEnabled: true
            width: resizeHandles.edgeSize

            onPressed: root.beginSystemResize(Qt.RightEdge)
        }
        MouseArea {
            anchors.left: parent.left
            anchors.leftMargin: resizeHandles.cornerSize
            anchors.right: parent.right
            anchors.rightMargin: resizeHandles.cornerSize
            anchors.top: parent.top
            cursorShape: Qt.SizeVerCursor
            height: resizeHandles.edgeSize
            hoverEnabled: true

            onPressed: root.beginSystemResize(Qt.TopEdge)
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: resizeHandles.cornerSize
            anchors.right: parent.right
            anchors.rightMargin: resizeHandles.cornerSize
            cursorShape: Qt.SizeVerCursor
            height: resizeHandles.edgeSize
            hoverEnabled: true

            onPressed: root.beginSystemResize(Qt.BottomEdge)
        }
        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            cursorShape: Qt.SizeFDiagCursor
            height: resizeHandles.cornerSize
            hoverEnabled: true
            width: resizeHandles.cornerSize

            onPressed: root.beginSystemResize(Qt.LeftEdge | Qt.TopEdge)
        }
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            cursorShape: Qt.SizeBDiagCursor
            height: resizeHandles.cornerSize
            hoverEnabled: true
            width: resizeHandles.cornerSize

            onPressed: root.beginSystemResize(Qt.RightEdge | Qt.TopEdge)
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            cursorShape: Qt.SizeBDiagCursor
            height: resizeHandles.cornerSize
            hoverEnabled: true
            width: resizeHandles.cornerSize

            onPressed: root.beginSystemResize(Qt.LeftEdge | Qt.BottomEdge)
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            cursorShape: Qt.SizeFDiagCursor
            height: resizeHandles.cornerSize
            hoverEnabled: true
            width: resizeHandles.cornerSize

            onPressed: root.beginSystemResize(Qt.RightEdge | Qt.BottomEdge)
        }
    }
    Rectangle {
        id: panel

        anchors.fill: parent
        clip: true
        color: Config.shellBlurSettingsEnabled && !root.maximized ? Config.alpha(Config.md3.background, Config.lightTheme ? Config.shellBlurPanelOpacityLight : Config.shellBlurPanelOpacityDark) : Config.md3.background
        focus: true
        opacity: root.active ? 1 : 0
        radius: root.maximized ? 0 : root.compactViewport ? 22 : 26
        scale: root.active ? 1 : 0.975

        Behavior on opacity {
            Md3NumberAnimation {
                role: "state"
            }
        }
        Behavior on scale {
            Md3NumberAnimation {
                role: "spatial"
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeSettings();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: panel.forceActiveFocus(Qt.MouseFocusReason)
        }
        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: sidebarPanel

                readonly property real contentInset: 10 + 6 * root.sidebarProgress

                Layout.fillHeight: true
                Layout.maximumWidth: root.sidebarWidth
                Layout.minimumWidth: root.sidebarWidth
                Layout.preferredWidth: root.sidebarWidth
                bottomLeftRadius: panel.radius
                clip: true
                color: Config.alpha(Config.md3.surface_container_low, 0.72)
                topLeftRadius: panel.radius

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.bottomMargin: root.compactViewport ? 6 : 10
                        Layout.fillWidth: true
                        Layout.leftMargin: sidebarPanel.contentInset
                        Layout.preferredHeight: 52
                        Layout.rightMargin: sidebarPanel.contentInset
                        Layout.topMargin: sidebarPanel.contentInset

                        Column {
                            id: sidebarHeaderTitle

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: root.sidebarExpanded ? Math.max(0, Math.min(1, (root.sidebarProgress - 0.55) / 0.45)) : Math.max(0, Math.min(1, (root.sidebarProgress - 0.78) / 0.22))
                            spacing: 2
                            visible: opacity > 0

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                                text: "Settings"
                            }
                            Text {
                                color: Config.alpha(Config.md3.on_surface, 0.55)
                                font.family: Config.fontName
                                font.pixelSize: 11
                                text: "Niri & Quickshell"
                            }
                        }
                        ProfileAvatar {
                            id: profileButton

                            accentColor: Config.md3.primary
                            anchors.verticalCenter: parent.verticalCenter
                            height: 40
                            scale: profileMouse.pressed ? 0.94 : profileMouse.containsMouse ? 1.04 : 1
                            sourcePath: Config.profileImagePath
                            width: 40
                            x: Math.round((1 - root.sidebarProgress) * ((parent.width - width) / 2) + root.sidebarProgress * (parent.width - width))

                            Behavior on scale {
                                ScaleAnimator {
                                    duration: Config.animationDuration(140)
                                    easing.type: Easing.OutCubic
                                }
                            }

                            MouseArea {
                                id: profileMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: root.sidebarExpanded = !root.sidebarExpanded
                            }
                        }
                    }
                    Flickable {
                        id: sidebarFlickable

                        readonly property real contentInset: sidebarPanel.contentInset

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        contentHeight: Math.max(height, (expandedSectionsColumn.opacity > 0 ? expandedSectionsColumn.implicitHeight : compactRailColumn.implicitHeight) + contentInset * 2)
                        contentWidth: width
                        flickableDirection: Flickable.VerticalFlick
                        interactive: contentHeight > height

                        Item {
                            id: sidebarContentContainer

                            height: Math.max(sidebarFlickable.height, (expandedSectionsColumn.opacity > 0 ? expandedSectionsColumn.implicitHeight : compactRailColumn.implicitHeight) + 16)
                            width: Math.max(0, root.sidebarWidth - sidebarFlickable.contentInset * 2)
                            x: sidebarFlickable.contentInset
                            y: 0

                            ColumnLayout {
                                id: compactRailColumn

                                anchors.horizontalCenter: parent.horizontalCenter
                                opacity: root.sidebarExpanded ? Math.max(0, Math.min(1, (0.35 - root.sidebarProgress) / 0.35)) : Math.max(0, Math.min(1, (0.45 - root.sidebarProgress) / 0.45))
                                spacing: 4
                                visible: opacity > 0
                                width: Math.max(0, root.compactSidebarWidth - 20)

                                SettingsNavButton {
                                    Layout.fillWidth: true
                                    active: root.activePage === root.homePage
                                    compact: true
                                    iconColor: Config.md3.primary
                                    iconForegroundColor: Config.md3.on_primary
                                    iconName: "home"
                                    rail: true
                                    text: qsTr("Home")

                                    onClicked: root.switchSection(root.homePage, 0)
                                }
                                Repeater {
                                    model: root.compactNavigationItems

                                    delegate: ColumnLayout {
                                        required property int index
                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: 4

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.bottomMargin: 2
                                            Layout.preferredHeight: 1
                                            Layout.preferredWidth: 32
                                            Layout.topMargin: 2
                                            color: Config.alpha(Config.md3.on_surface, 0.12)
                                            visible: modelData.divider
                                        }
                                        SettingsNavButton {
                                            Layout.fillWidth: true
                                            active: root.activePage === modelData.page && (modelData.page === 0 ? root.activeNiriSection === modelData.section : modelData.page === 1 ? root.activeQuickshellSection === modelData.section : root.activeSecuritySection === modelData.section)
                                            compact: true
                                            dense: true
                                            iconColor: root.sectionColor(modelData.page, modelData.section)
                                            iconForegroundColor: modelData.page === 0 ? Config.md3.on_secondary : modelData.page === 1 ? Config.md3.on_primary : Config.md3.on_tertiary
                                            iconName: modelData.icon
                                            indented: false
                                            rail: true
                                            text: modelData.title

                                            onClicked: root.switchSection(modelData.page, modelData.section)
                                        }
                                    }
                                }
                            }
                            ColumnLayout {
                                id: expandedSectionsColumn

                                anchors.left: parent.left
                                opacity: root.sidebarExpanded ? Math.max(0, Math.min(1, (root.sidebarProgress - 0.45) / 0.55)) : Math.max(0, Math.min(1, (root.sidebarProgress - 0.78) / 0.22))
                                spacing: Md3.spacing.sm
                                visible: opacity > 0
                                width: Math.max(0, root.expandedSidebarWidth - 32)

                                SettingsSearch {
                                    Layout.bottomMargin: 6
                                    Layout.fillWidth: true
                                    items: root.searchItems

                                    onSelected: (page, section) => root.switchSection(page, section)
                                }
                                SettingsNavButton {
                                    Layout.fillWidth: true
                                    active: root.activePage === root.homePage
                                    compact: false
                                    iconColor: Config.md3.primary
                                    iconForegroundColor: Config.md3.on_primary
                                    iconName: "home"
                                    rail: false
                                    text: qsTr("Home")

                                    onClicked: root.switchSection(root.homePage, 0)
                                }
                                SettingsNavButton {
                                    Layout.fillWidth: true
                                    active: root.activePage === 0 && !root.niriExpanded
                                    compact: false
                                    expandable: true
                                    expanded: root.niriExpanded
                                    iconColor: Config.md3.secondary
                                    iconForegroundColor: Config.md3.on_secondary
                                    iconSource: Qt.resolvedUrl("../../assets/icons/niri.svg")
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
                                    spacing: 2
                                    visible: root.niriExpanded

                                    Repeater {
                                        model: root.niriSectionNames.length

                                        delegate: SettingsNavButton {
                                            required property int index

                                            Layout.fillWidth: true
                                            active: root.activePage === 0 && root.activeNiriSection === index
                                            dense: true
                                            firstInGroup: index === 0
                                            iconColor: root.niriSectionColors[index]
                                            iconForegroundColor: Config.md3.on_secondary
                                            iconName: root.niriSectionIcons[index]
                                            indented: true
                                            lastInGroup: index === root.niriSectionNames.length - 1
                                            subtitle: root.niriSectionSummaries[index]
                                            text: root.niriSectionNames[index]

                                            onClicked: {
                                                root.switchSection(0, index);
                                            }
                                        }
                                    }
                                }
                                SettingsNavButton {
                                    Layout.fillWidth: true
                                    active: root.activePage === 1 && !root.quickshellExpanded
                                    compact: false
                                    expandable: true
                                    expanded: root.quickshellExpanded
                                    iconColor: Config.md3.primary
                                    iconForegroundColor: Config.md3.on_primary
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
                                    spacing: 2
                                    visible: root.quickshellExpanded

                                    Repeater {
                                        model: root.quickshellSectionNames.length

                                        delegate: SettingsNavButton {
                                            required property int index

                                            Layout.fillWidth: true
                                            active: root.activePage === 1 && root.activeQuickshellSection === index
                                            dense: true
                                            firstInGroup: index === 0
                                            iconColor: root.quickshellSectionColors[index]
                                            iconForegroundColor: Config.md3.on_primary
                                            iconName: root.quickshellSectionIcons[index]
                                            indented: true
                                            lastInGroup: index === root.quickshellSectionNames.length - 1
                                            subtitle: root.quickshellSectionSummaries[index]
                                            text: root.quickshellSectionNames[index]

                                            onClicked: {
                                                root.switchSection(1, index);
                                            }
                                        }
                                    }
                                }
                                SettingsNavButton {
                                    Layout.fillWidth: true
                                    active: root.activePage === 2 && !root.securityExpanded
                                    compact: false
                                    expandable: true
                                    expanded: root.securityExpanded
                                    iconColor: Config.md3.tertiary
                                    iconForegroundColor: Config.md3.on_tertiary
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
                                    spacing: 2
                                    visible: root.securityExpanded

                                    Repeater {
                                        model: root.securitySectionNames.length

                                        delegate: SettingsNavButton {
                                            required property int index

                                            Layout.fillWidth: true
                                            active: root.activePage === 2 && root.activeSecuritySection === index
                                            dense: true
                                            firstInGroup: index === 0
                                            iconColor: root.securitySectionColors[index]
                                            iconForegroundColor: Config.md3.on_tertiary
                                            iconName: root.securitySectionIcons[index]
                                            indented: true
                                            lastInGroup: index === root.securitySectionNames.length - 1
                                            subtitle: root.securitySectionSummaries[index]
                                            text: root.securitySectionNames[index]

                                            onClicked: root.switchSection(2, index)
                                        }
                                    }
                                }
                                Item {
                                    Layout.fillHeight: true
                                }
                            }
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
                id: settingsMainColumn

                Layout.bottomMargin: 10
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.leftMargin: root.compactViewport ? 10 : 18
                Layout.minimumWidth: 0
                Layout.preferredWidth: root.settingsContentWidth
                Layout.rightMargin: root.compactViewport ? 10 : 18
                Layout.topMargin: 0
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68

                    MouseArea {
                        acceptedButtons: Qt.LeftButton
                        anchors.fill: parent

                        onDoubleClicked: root.maximized = !root.maximized
                        onPressed: root.startSystemMove()
                    }
                    SettingsLabelBlock {
                        anchors.left: parent.left
                        anchors.right: headerActions.left
                        anchors.rightMargin: root.compactHeader ? 12 : 18
                        anchors.verticalCenter: parent.verticalCenter
                        emphasized: true
                        headline: root.activeTitle
                        headlineRole: "headlineSmall"
                        supportingMaximumLineCount: 1
                        supportingText: root.activeSubtitle
                    }
                    RowLayout {
                        id: headerActions

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.compactHeader ? 8 : 10

                        Rectangle {
                            id: statusChip

                            readonly property color accentColor: SettingsHubService.statusSuccess ? Config.md3.primary : Config.md3.error

                            Accessible.name: SettingsHubService.statusMessage
                            Accessible.role: Accessible.StaticText
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: root.compactHeader ? 38 : 260
                            border.color: Config.alpha(accentColor, 0.24)
                            border.width: 1
                            color: Config.alpha(accentColor, SettingsHubService.statusSuccess ? 0.09 : 0.12)
                            radius: 13
                            visible: SettingsHubService.statusMessage !== ""
                            z: statusHover.containsMouse ? 20 : 0

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 180
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 180
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.compactHeader ? 7 : 8
                                anchors.rightMargin: root.compactHeader ? 7 : 11
                                spacing: 8

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: 24
                                    color: Config.alpha(statusChip.accentColor, 0.17)
                                    radius: 8

                                    Md3Icon {
                                        anchors.centerIn: parent
                                        color: statusChip.accentColor
                                        name: SettingsHubService.statusSuccess ? "check" : "warning"
                                        size: 18
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    maximumLineCount: 1
                                    text: SettingsHubService.statusMessage
                                    visible: !root.compactHeader
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.bottom
                                anchors.topMargin: 7
                                color: Config.md3.surface_container_high
                                height: 34
                                radius: 10
                                visible: root.compactHeader && statusHover.containsMouse
                                width: Math.min(320, statusTooltipText.implicitWidth + 20)
                                z: 20

                                Text {
                                    id: statusTooltipText

                                    anchors.fill: parent
                                    anchors.margins: 10
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 11
                                    text: SettingsHubService.statusMessage
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            MouseArea {
                                id: statusHover

                                acceptedButtons: Qt.NoButton
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                        SettingsActionButton {
                            enabled: !SettingsHubService.busy
                            iconName: "edit-undo-symbolic"
                            iconOnly: true
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
                            iconOnly: true
                            primary: true
                            text: pageLoader.item ? pageLoader.item.headerActionText || "Apply" : "Apply"
                            visible: Boolean(pageLoader.item && pageLoader.item.headerActionVisible === true)

                            onClicked: {
                                if (pageLoader.item && pageLoader.item.triggerHeaderAction)
                                    pageLoader.item.triggerHeaderAction();
                            }
                        }
                        SettingsActionButton {
                            iconName: root.maximized ? "window-restore-symbolic" : "window-maximize-symbolic"
                            iconOnly: true
                            text: root.maximized ? "Restore" : "Maximize"

                            onClicked: root.maximized = !root.maximized
                        }
                        SettingsActionButton {
                            iconName: "window-close-symbolic"
                            iconOnly: true
                            text: "Close"

                            onClicked: root.closeSettings()
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        color: Config.alpha(Config.md3.on_surface, 0.07)
                        height: 1
                        width: parent.width
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
                            else if (root.activePage === 1 && item)
                                item.activeSection = Qt.binding(() => root.legacyQuickshellSection());
                            else if (root.activePage === 2 && item)
                                item.activeSection = Qt.binding(() => root.activeSecuritySection);
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: root.activePage !== root.homePage && SettingsHubService.busy && !SettingsHubService.ready

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
                                font.pixelSize: 20
                                text: "…"
                            }
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.58)
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            text: "Reading configuration"
                        }
                    }
                    Connections {
                        function onNavigateRequested(page, section) {
                            root.switchSection(page, section);
                        }

                        ignoreUnknownSignals: true
                        target: pageLoader.status === Loader.Ready ? pageLoader.item : null
                    }
                }
            }
        }
    }
}
