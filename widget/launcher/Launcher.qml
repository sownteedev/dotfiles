import QtQuick
import "."
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../../"
import "../../components"

PanelWindow {
    id: launcherWindow

    property bool active: false
    readonly property color activeModeColor: searchMode === "clipboard" ? Config.md3.secondary : searchMode === "files" ? Config.md3.primary : searchMode === "calculator" ? Config.md3.tertiary : Config.md3.tertiary
    readonly property string activeModeIcon: searchMode === "clipboard" ? "edit-paste-symbolic" : searchMode === "files" ? "system-file-manager-symbolic" : searchMode === "calculator" ? "accessories-calculator-symbolic" : "emojichooser-symbolic"
    readonly property string activeModeLabel: searchMode === "clipboard" ? "Clipboard" : searchMode === "files" ? "Files" : searchMode === "calculator" ? "Calculator" : searchMode === "emoji" ? "Emoji" : ""
    readonly property string activeModePlaceholder: searchMode === "clipboard" ? "Search clipboard" : searchMode === "files" ? "Find files" : searchMode === "calculator" ? "Enter expression" : searchMode === "emoji" ? "Search emoji" : "Search"
    property bool allAppsLoaderActive: false
    property bool allAppsReady: false
    property bool blurActive: false
    readonly property bool compact: Responsive.constrained(width, height, 720, 600)
    property string searchMode: ""
    property string searchQuery: ""
    property bool showAllApps: false

    signal dismissed

    function clearSearchMode() {
        searchMode = "";
        syncSearchQuery();
        searchEntry.forceActiveFocus();
    }
    function closeLauncher() {
        if (!active)
            return;
        active = false;
        blurReleaseTimer.restart();
        closeTimer.restart();
    }
    function handleAllAppsKey(event) {
        if (!showAllApps || allAppsLoader.status !== Loader.Ready || !allAppsLoader.item)
            return false;

        if (event.key === Qt.Key_Left)
            allAppsLoader.item["selectLeft"]();
        else if (event.key === Qt.Key_Right)
            allAppsLoader.item["selectRight"]();
        else if (event.key === Qt.Key_Up)
            allAppsLoader.item["selectUp"]();
        else if (event.key === Qt.Key_Down)
            allAppsLoader.item["selectDown"]();
        else if (event.key === Qt.Key_Home)
            allAppsLoader.item["selectFirst"]();
        else if (event.key === Qt.Key_End)
            allAppsLoader.item["selectLast"]();
        else if (event.key === Qt.Key_PageUp)
            allAppsLoader.item["selectPreviousPage"]();
        else if (event.key === Qt.Key_PageDown)
            allAppsLoader.item["selectNextPage"]();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            allAppsLoader.item["launchSelected"]();
        else
            return false;
        return true;
    }
    function modePrefix(mode) {
        if (mode === "clipboard")
            return Config.launcherClipboardPrefix + " ";
        if (mode === "files")
            return Config.launcherFilesPrefix + " ";
        if (mode === "calculator")
            return Config.launcherCalculatorPrefix + " ";
        if (mode === "emoji")
            return Config.launcherEmojiPrefix + " ";
        return "";
    }
    function openAllApps() {
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;
        blurReleaseTimer.stop();
        closeTimer.stop();
        blurActive = true;
        resetSearch();
        showAllApps = true;
        visible = true;
        active = true;
        searchEntry.forceActiveFocus();
    }
    function openLauncher() {
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;
        blurReleaseTimer.stop();
        closeTimer.stop();
        blurActive = true;
        resetSearch();
        showAllApps = false;
        visible = true;
        active = true;
        searchEntry.forceActiveFocus();
    }
    function resetSearch() {
        searchMode = "";
        searchEntry.text = "";
        searchQuery = "";
    }
    function syncSearchQuery() {
        searchQuery = modePrefix(searchMode) + searchEntry.text;
    }
    function tryActivateSearchMode() {
        if (searchMode !== "")
            return false;

        var input = searchEntry.text;
        var lower = input.toLowerCase();
        var mode = "";
        if (Config.launcherClipboardEnabled && lower.startsWith(Config.launcherClipboardPrefix.toLowerCase() + " "))
            mode = "clipboard";
        else if (Config.launcherFilesEnabled && lower.startsWith(Config.launcherFilesPrefix.toLowerCase() + " "))
            mode = "files";
        else if (Config.launcherEmojiEnabled && lower.startsWith(Config.launcherEmojiPrefix.toLowerCase() + " "))
            mode = "emoji";
        else if (Config.launcherCalculatorEnabled && lower.startsWith(Config.launcherCalculatorPrefix.toLowerCase() + " "))
            mode = "calculator";
        if (mode === "")
            return false;

        searchMode = mode;
        searchEntry.text = input.substring(modePrefix(mode).length);
        searchEntry.cursorPosition = searchEntry.text.length;
        syncSearchQuery();
        return true;
    }

    WlrLayershell.namespace: "quickshell-launcher"
    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Fill screen to allow centering and clicking outside to close
    anchors.top: true
    color: "transparent"
    exclusiveZone: 0
    focusable: true

    // Toggle visibility logic
    visible: false

    BackgroundEffect.blurRegion: Region {
        item: Config.shellBlurLauncherEnabled && launcherWindow.blurActive ? mainLayout : null
        radius: mainLayout.radius
    }

    onShowAllAppsChanged: {
        allAppsRevealTimer.stop();
        allAppsLoaderTimer.stop();
        allAppsReady = false;
        if (showAllApps) {
            allAppsLoaderTimer.start();
            allAppsRevealTimer.start();
        } else {
            allAppsLoaderActive = false;
        }
    }
    onVisibleChanged: {
        if (visible) {
            searchEntry.text = "";
            searchEntry.forceActiveFocus();
        }
    }

    // Let the 350ms container resize finish before starting delegate animations.
    Timer {
        id: allAppsRevealTimer

        interval: 370
        repeat: false

        onTriggered: {
            if (showAllApps)
                allAppsReady = true;
        }
    }
    Timer {
        id: allAppsLoaderTimer

        interval: 360
        repeat: false

        onTriggered: {
            if (showAllApps)
                allAppsLoaderActive = true;
        }
    }

    // Timer to delay visible=false until the fade-out/scale-down animation completes
    Timer {
        id: blurReleaseTimer

        interval: Math.max(1, Config.animationDuration(10))
        repeat: false

        onTriggered: launcherWindow.blurActive = false
    }

    // Timer to delay visible=false until the fade-out/scale-down animation completes
    Timer {
        id: closeTimer

        interval: Math.max(1, Config.animationDuration(250))
        repeat: false
        running: false

        onTriggered: {
            launcherWindow.blurActive = false;
            visible = false;
            resetSearch();
            launcherWindow.dismissed();
        }
    }

    // Dismiss launcher when clicking outside the container
    MouseArea {
        anchors.fill: parent

        onClicked: closeLauncher()
    }
    ShellShadow {
        active: launcherWindow.visible && !launcherWindow.showAllApps && mainLayout.opacity > 0
        cornerRadius: mainLayout.radius
        opacity: mainLayout.opacity
        scale: mainLayout.scale
        target: mainLayout
    }

    // Main Container
    Rectangle {
        id: mainLayout

        readonly property real desiredHeight: searchQuery.trim() !== "" && hasContent ? (97 + (calcView.hasResult ? 92 : 0) + searchView.implicitHeight) : (launcherWindow.compact ? 76 : 82)
        readonly property real desiredWidth: searchQuery.trim() !== "" && hasContent ? 500 : (searchQuery.trim() !== "" ? 440 : 380)
        readonly property bool hasContent: calcView.hasResult || searchView.combinedResults.length > 0
        readonly property real targetHeight: showAllApps ? launcherWindow.height : Responsive.fitWithMargins(desiredHeight, launcherWindow.height, launcherWindow.compact ? 10 : 20, 82)
        readonly property real targetWidth: showAllApps ? launcherWindow.width : Responsive.fitWithMargins(desiredWidth, launcherWindow.width, launcherWindow.compact ? 10 : 20, 300)

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.outline_variant, 0.38)
        border.width: showAllApps ? 0 : 1
        clip: true
        color: Config.shellBlurLauncherEnabled ? Config.alpha(Config.md3.background, Config.lightTheme ? Config.shellBlurPanelOpacityLight : Config.shellBlurPanelOpacityDark) : Config.md3.background
        focus: true
        height: targetHeight
        opacity: launcherWindow.active ? 1.0 : 0.0
        radius: showAllApps ? 0 : Math.min(40, height / 2, width / 2)
        scale: launcherWindow.active ? 1.0 : 0.92
        width: targetWidth

        Behavior on height {
            NumberAnimation {
                duration: Config.animationDuration(350)
                easing.type: Easing.OutCubic
            }
        }
        // Unified transition behaviors
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(250)
                easing.type: Easing.OutQuad
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Config.animationDuration(300)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: launcherWindow.active ? 400 : 250
                easing.type: launcherWindow.active ? Easing.OutBack : Easing.OutQuad
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Config.animationDuration(350)
                easing.type: Easing.OutCubic
            }
        }

        // PanelWindow is not an Item, so keyboard handlers belong on the popup.
        // Unhandled events from the focused search field propagate here.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                closeLauncher();
                event.accepted = true;
            } else if (launcherWindow.handleAllAppsKey(event)) {
                event.accepted = true;
            } else if (searchQuery.trim() !== "" && !showAllApps) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (calcView.hasResult && searchView.combinedResults.length === 0)
                        calcView.copyResult();
                    else
                        searchView.launchSelected();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    searchView.selectNext();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    searchView.selectPrev();
                    event.accepted = true;
                }
            }
        }

        // Prevent click propagation to parent backdrop MouseArea
        MouseArea {
            anchors.fill: parent
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: launcherWindow.showAllApps ? Responsive.clamp(Math.min(mainLayout.width, mainLayout.height) * 0.045, 24, 64) : (launcherWindow.compact ? 12 : 15)
            spacing: launcherWindow.showAllApps ? 24 : (launcherWindow.compact ? 10 : 15)

            // Search & Navigation Row
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: !launcherWindow.showAllApps
                Layout.preferredHeight: launcherWindow.showAllApps ? 58 : 52
                Layout.preferredWidth: launcherWindow.showAllApps ? Math.min(720, mainLayout.width - 96) : 0
                border.color: launcherWindow.showAllApps ? Config.alpha(Config.md3.outline_variant, 0.42) : "transparent"
                border.width: launcherWindow.showAllApps ? 1 : 0
                color: launcherWindow.showAllApps ? Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.88 : 0.76) : "transparent"
                radius: height / 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: launcherWindow.showAllApps ? 18 : 0
                    anchors.rightMargin: launcherWindow.showAllApps ? 8 : 0
                    spacing: launcherWindow.compact ? 10 : 15

                    Item {
                        id: leadingIcon

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 28

                        IconImage {
                            anchors.centerIn: parent
                            height: launcherWindow.searchMode !== "" ? 22 : 28
                            layer.enabled: true
                            source: Quickshell.iconPath(launcherWindow.searchMode !== "" ? launcherWindow.activeModeIcon : "system-search-symbolic")
                            width: height

                            layer.effect: ColorOverlay {
                                color: launcherWindow.searchMode !== "" ? launcherWindow.activeModeColor : (searchEntry.activeFocus ? Config.md3.primary : Config.md3.on_surface_variant)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: launcherWindow.searchMode !== ""

                            onClicked: launcherWindow.clearSearchMode()
                        }
                    }
                    TextInput {
                        id: searchEntry

                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        clip: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: launcherWindow.showAllApps ? 17 : 16
                        font.weight: Font.Medium
                        selectByMouse: true

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Backspace && launcherWindow.searchMode !== "" && text === "") {
                                launcherWindow.clearSearchMode();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                closeLauncher();
                                event.accepted = true;
                            } else if (launcherWindow.handleAllAppsKey(event)) {
                                event.accepted = true;
                            } else if (searchQuery.trim() !== "" && !showAllApps) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (calcView.hasResult && searchView.combinedResults.length === 0) {
                                        calcView.copyResult();
                                    } else {
                                        searchView.launchSelected();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                    searchView.selectPrev();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    searchView.selectNext();
                                    event.accepted = true;
                                }
                            }
                        }
                        onTextChanged: {
                            if (!launcherWindow.tryActivateSearchMode())
                                launcherWindow.syncSearchQuery();
                        }

                        Text {
                            color: Config.alpha(Config.md3.on_surface_variant, 0.62)
                            font: parent.font
                            text: launcherWindow.activeModePlaceholder
                            visible: parent.text === ""
                        }
                    }
                    Item {
                        id: toggleRect

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: 40
                        scale: toggleMouse.containsMouse ? 1.05 : 1
                        visible: launcherWindow.searchMode === ""

                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animationDuration(220)
                                easing.type: Easing.OutBack
                            }
                        }

                        Grid {
                            anchors.centerIn: parent
                            columns: 2
                            spacing: 4

                            Repeater {
                                model: 4

                                Rectangle {
                                    color: launcherWindow.showAllApps || toggleMouse.containsMouse ? Config.md3.primary : Config.md3.on_surface_variant
                                    height: 6
                                    radius: 2
                                    width: 6

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Config.animationDuration(120)
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: toggleMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                showAllApps = !showAllApps;
                                if (showAllApps)
                                    launcherWindow.resetSearch();
                            }
                        }
                    }
                }
            }

            // Content Area Stack
            Item {
                id: contentStack

                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.maximumWidth: launcherWindow.showAllApps ? 2200 : mainLayout.width
                clip: true
                visible: launcherWindow.showAllApps || (launcherWindow.searchQuery.trim() !== "" && mainLayout.hasContent)

                // Search mode: calculator card + search results (stacked)
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    visible: searchQuery !== "" && !showAllApps

                    // Calculator (shown only for expressions prefixed with "=")
                    LauncherCalc {
                        id: calcView

                        Layout.fillWidth: true
                        query: searchQuery
                        visible: Config.launcherCalculatorEnabled && hasResult

                        onResultCopied: closeLauncher()
                    }

                    // Unified search results (apps + files)
                    LauncherSearch {
                        id: searchView

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.minimumHeight: 0
                        query: searchQuery

                        onResultLaunched: closeLauncher()
                    }
                }

                // All Apps is comparatively expensive (model sorting + animated delegates),
                // so do not instantiate it during the launcher's normal search path.
                Loader {
                    id: allAppsLoader

                    active: launcherWindow.allAppsLoaderActive
                    anchors.fill: parent

                    sourceComponent: LauncherApps {
                        entranceReady: launcherWindow.allAppsReady
                        query: searchQuery

                        onAppLaunched: closeLauncher()
                    }
                }
            }
        }
    }
}
