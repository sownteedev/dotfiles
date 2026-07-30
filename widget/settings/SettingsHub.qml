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
    readonly property string activeSubtitle: activePage === 0 ? "Inspect and tune your Niri configuration" : activeQuickshellSection === 0 ? "Configure shell appearance" : activeQuickshellSection === 1 ? "Configure wallpaper playback and colors" : activeQuickshellSection === 2 ? "Configure screenshots and screen recording" : "Configure external services and dependencies"
    readonly property string activeTitle: activePage === 0 ? niriSectionNames[activeNiriSection] : quickshellSectionNames[activeQuickshellSection]
    property bool niriExpanded: true
    readonly property var niriSectionColors: [Config.md3.primary, Config.md3.secondary, Config.md3.primary, Config.md3.secondary, Config.md3.tertiary, Config.md3.error, Config.md3.primary]
    readonly property var niriSectionIcons: ["input-keyboard-symbolic", "view-grid-symbolic", "input-mouse-symbolic", "media-playback-start-symbolic", "emblem-system-symbolic", "view-list-symbolic", "text-x-generic-symbolic"]
    readonly property var niriSectionNames: ["Keybinds", "Layout", "Input", "Animations", "Behavior", "Rules", "Config files"]
    property bool quickshellExpanded: true
    readonly property var quickshellSectionColors: [Config.md3.secondary, Config.md3.tertiary, Config.md3.primary, Config.md3.error]
    readonly property var quickshellSectionIcons: ["preferences-desktop-theme-symbolic", "preferences-desktop-wallpaper-symbolic", "camera-photo-symbolic", "network-workgroup-symbolic"]
    readonly property var quickshellSectionNames: ["General", "Wallpaper", "Capture", "Integrations"]
    property bool sidebarExpanded: true
    property real sidebarWidth: sidebarExpanded ? 264 : 84
    property int pendingPage: 0
    property int pendingSection: 0

    signal dismissed

    function closeSettings() {
        active = false;
        closeTimer.restart();
    }
    function openSettings() {
        closeTimer.stop();
        sectionTransition.stop();
        pageFrame.opacity = 1;
        pageFrame.x = 0;
        visible = true;
        active = true;
        panel.forceActiveFocus();
        SettingsHubService.refresh();
    }
    function switchSection(page, section) {
        if (activePage === page && (page === 0 ? activeNiriSection : activeQuickshellSection) === section)
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
            duration: 220
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
                target: pageFrame
                property: "opacity"
                to: 0
                duration: 85
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: pageFrame
                property: "x"
                to: 10
                duration: 85
                easing.type: Easing.InQuad
            }
        }
        ScriptAction {
            script: {
                root.activePage = root.pendingPage;
                if (root.pendingPage === 0)
                    root.activeNiriSection = root.pendingSection;
                else
                    root.activeQuickshellSection = root.pendingSection;
                pageFrame.x = -10;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: pageFrame
                property: "opacity"
                to: 1
                duration: 175
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pageFrame
                property: "x"
                to: 0
                duration: 175
                easing.type: Easing.OutCubic
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
        height: Math.min(root.height - 28, 1120)
        opacity: root.active ? 1 : 0
        radius: 30
        scale: root.active ? 1 : 0.96
        width: Math.min(root.width - 36, 1880)

        Behavior on opacity {
            NumberAnimation {
                duration: 190
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 230
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
            anchors.fill: parent
            color: Config.md3.primary
            running: root.active
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

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.sidebarExpanded ? 22 : 16
                    spacing: 10

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
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Config.alpha(Config.md3.on_surface, 0.065)
            }
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.margins: 32
                Layout.minimumWidth: 0
                spacing: 20

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: headerActions.left
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 30
                            font.weight: Font.Bold
                            text: root.activeTitle
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.5)
                            font.family: Config.fontName
                            font.pixelSize: 15
                            text: root.activeSubtitle
                        }
                    }
                    RowLayout {
                        id: headerActions

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

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
                        source: root.activePage === 0 ? "NiriSettingsPage.qml" : "QuickshellSettingsPage.qml"

                        onLoaded: {
                            if (root.activePage === 0 && item)
                                item.activeSection = Qt.binding(() => root.activeNiriSection);
                            else if (root.activePage === 1 && item)
                                item.activeSection = Qt.binding(() => root.activeQuickshellSection);
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
