import QtQuick
import "."
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

PanelWindow {
    id: launcherWindow

    property bool active: false
    property bool allAppsReady: false
    property string searchQuery: ""
    property bool showAllApps: false

    signal dismissed

    function closeLauncher() {
        active = false;
        closeTimer.start();
    }
    function openLauncher() {
        closeTimer.stop();
        searchQuery = "";
        showAllApps = false;
        visible = true;
        active = true;
        searchEntry.forceActiveFocus();
    }

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
        allAppsReady = false;
        if (showAllApps)
            allAppsRevealTimer.start();
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

    // Timer to delay visible=false until the fade-out/scale-down animation completes
    Timer {
        id: closeTimer

        interval: 250
        repeat: false
        running: false

        onTriggered: {
            visible = false;
            searchQuery = "";
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

        readonly property bool hasContent: calcView.hasResult || searchView.combinedResults.length > 0

        // Dynamic height calculation: 97px (margins/spacings/header) + calc (if any) + search results list
        readonly property real targetHeight: showAllApps ? 680 : (searchQuery.trim() !== "" && hasContent ? (97 + (calcView.hasResult ? 92 : 0) + searchView.implicitHeight) : 82)

        // Accurate width calculation: 380px when empty, expanding to 500px when active/searching, and 900px for All Apps
        readonly property real targetWidth: showAllApps ? 900 : (searchQuery.trim() !== "" ? 500 : 380)

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.outline_variant, 0.38)
        border.width: 1
        clip: true
        color: Config.alpha(Config.md3.background, 0.98)
        focus: true
        height: targetHeight
        layer.enabled: launcherWindow.visible
        opacity: launcherWindow.active ? 1.0 : 0.0
        radius: 40
        scale: launcherWindow.active ? 1.0 : 0.92
        width: targetWidth

        Behavior on height {
            NumberAnimation {
                duration: 350
                easing.type: Easing.OutBack
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
                duration: 250
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
                duration: 350
                easing.type: Easing.OutBack
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
            anchors.margins: 15
            spacing: 15

            // Search & Navigation Row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                spacing: 15

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
                        if (event.key === Qt.Key_Escape) {
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
                    onTextChanged: searchQuery = text

                    Text {
                        color: Config.alpha(Config.md3.on_surface_variant, 0.62)
                        font: parent.font
                        text: "Search"
                        visible: parent.text === ""
                    }
                }
                Rectangle {
                    id: toggleRect

                    Layout.alignment: Qt.AlignVCenter
                    color: toggleMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                    height: 40
                    radius: 20
                    scale: toggleMouse.containsMouse ? 1.06 : 1
                    width: 40

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        height: 23
                        layer.enabled: true
                        rotation: showAllApps ? 90 : 0
                        source: Quickshell.iconPath(showAllApps ? "view-list-symbolic" : "view-grid-symbolic")
                        width: 23

                        layer.effect: ColorOverlay {
                            color: showAllApps ? Config.md3.primary : Config.md3.on_surface_variant
                        }
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 350
                                easing.type: Easing.OutBack
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
                                searchEntry.text = "";
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
                visible: mainLayout.height > 82

                // Search mode: calculator card + search results (stacked)
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 12
                    visible: searchQuery !== "" && !showAllApps

                    // Calculator (shown only for expressions prefixed with "=")
                    LauncherCalc {
                        id: calcView

                        Layout.fillWidth: true
                        query: searchQuery
                        visible: hasResult

                        onResultCopied: closeLauncher()
                    }

                    // Unified search results (apps + files)
                    LauncherSearch {
                        id: searchView

                        Layout.fillWidth: true
                        query: searchQuery

                        onResultLaunched: closeLauncher()
                    }
                }

                // All Apps is comparatively expensive (model sorting + animated delegates),
                // so do not instantiate it during the launcher's normal search path.
                Loader {
                    id: allAppsLoader

                    active: showAllApps
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
