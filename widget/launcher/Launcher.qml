import QtQuick
import "."
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../../"

PanelWindow {
    id: launcherWindow

    property bool active: false
    readonly property color activeModeColor: searchMode === "clipboard" ? Config.md3.secondary : searchMode === "files" ? Config.md3.primary : searchMode === "calculator" ? Config.md3.tertiary : Config.md3.tertiary
    readonly property string activeModeIcon: searchMode === "clipboard" ? "edit-paste-symbolic" : searchMode === "files" ? "system-file-manager-symbolic" : searchMode === "calculator" ? "accessories-calculator-symbolic" : "emojichooser-symbolic"
    readonly property string activeModeLabel: searchMode === "clipboard" ? "Clipboard" : searchMode === "files" ? "Files" : searchMode === "calculator" ? "Calculator" : searchMode === "emoji" ? "Emoji" : ""
    readonly property string activeModePlaceholder: searchMode === "clipboard" ? "Search clipboard" : searchMode === "files" ? "Find files" : searchMode === "calculator" ? "Enter expression" : searchMode === "emoji" ? "Search emoji" : "Search"
    property bool allAppsLoaderActive: false
    property bool allAppsReady: false
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
        active = false;
        closeTimer.start();
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
    function openLauncher() {
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;
        closeTimer.stop();
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

    WlrLayershell.namespace: "launcher"
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
        id: closeTimer

        interval: 250
        repeat: false
        running: false

        onTriggered: {
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

    // Main Container
    Rectangle {
        id: mainLayout

        readonly property real desiredHeight: showAllApps ? 680 : (searchQuery.trim() !== "" && hasContent ? (97 + (calcView.hasResult ? 92 : 0) + searchView.implicitHeight) : (launcherWindow.compact ? 76 : 82))
        readonly property real desiredWidth: showAllApps ? 900 : (searchQuery.trim() !== "" && hasContent ? 500 : (searchQuery.trim() !== "" ? 440 : 380))
        readonly property bool hasContent: calcView.hasResult || searchView.combinedResults.length > 0
        readonly property real targetHeight: Responsive.fitWithMargins(desiredHeight, launcherWindow.height, launcherWindow.compact ? 10 : 20, 82)
        readonly property real targetWidth: Responsive.fitWithMargins(desiredWidth, launcherWindow.width, launcherWindow.compact ? 10 : 20, 300)

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.outline_variant, 0.38)
        border.width: 1
        clip: true
        color: Config.alpha(Config.md3.background, 0.98)
        focus: true
        height: targetHeight
        layer.enabled: launcherWindow.visible
        opacity: launcherWindow.active ? 1.0 : 0.0
        radius: Math.min(40, height / 2, width / 2)
        scale: launcherWindow.active ? 1.0 : 0.92
        width: targetWidth

        Behavior on height {
            NumberAnimation {
                duration: Config.animationDuration(350)
                easing.type: Easing.OutCubic
            }
        }
        layer.effect: DropShadow {
            color: Config.alpha(Config.md3.shadow, 0.58)
            horizontalOffset: 0
            radius: 14
            samples: 21
            transparentBorder: true
            verticalOffset: 2
        }

        // Unified transition behaviors
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(250)
                easing.type: Easing.OutQuad
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
            anchors.margins: launcherWindow.compact ? 12 : 15
            spacing: launcherWindow.compact ? 10 : 15

            // Search & Navigation Row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                spacing: launcherWindow.compact ? 10 : 15

                IconImage {
                    Layout.alignment: Qt.AlignVCenter
                    height: 28
                    layer.enabled: true
                    source: Quickshell.iconPath("system-search-symbolic")
                    width: 28

                    layer.effect: ColorOverlay {
                        color: searchEntry.activeFocus ? Config.md3.primary : Config.md3.on_surface_variant
                    }
                }
                TextInput {
                    id: searchEntry

                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    clip: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    selectByMouse: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Backspace && launcherWindow.searchMode !== "" && text === "") {
                            launcherWindow.clearSearchMode();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            closeLauncher();
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
                Rectangle {
                    id: modeChip

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 34
                    border.color: Config.alpha(launcherWindow.activeModeColor, 0.42)
                    border.width: 1
                    color: modeChipMouse.containsMouse ? Config.alpha(launcherWindow.activeModeColor, 0.22) : Config.alpha(launcherWindow.activeModeColor, 0.14)
                    opacity: visible ? 1 : 0
                    radius: 17
                    visible: launcherWindow.searchMode !== ""

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(140)
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        height: 18
                        layer.enabled: true
                        source: Quickshell.iconPath(launcherWindow.activeModeIcon)
                        width: 18

                        layer.effect: ColorOverlay {
                            color: launcherWindow.activeModeColor
                        }
                    }
                    MouseArea {
                        id: modeChipMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: launcherWindow.clearSearchMode()
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

            // Content Area Stack
            Item {
                id: contentStack

                Layout.fillHeight: true
                Layout.fillWidth: true
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
