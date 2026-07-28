import QtQuick
import "."
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"

PanelWindow {
    id: powerWindow

    // Command array corresponding to each button index (0 to 5)
    property var commands: [
        ["poweroff"],
        ["reboot"],
        ["env", "QML2_IMPORT_PATH=" + Config.dotfilesRoot, "quickshell", "-p", Config.quickshellDir + "/widget/lockscreen/Lockscreen.qml"],
        ["systemctl", "hibernate"],
        ["systemctl", "suspend"],
        ["niri", "msg", "action", "quit"]
    ]
    property bool menuOpen: false
    readonly property real s: 1.0

    signal dismissed

    function closeMenu() {
        menuOpen = false;
        contentRoot.opacity = 0.0;
    }
    function executeAction(index) {
        if (index >= 0 && index < commands.length) {
            Quickshell.execDetached(commands[index]);
            closeMenu();
        }
    }

    // Show/hide helper functions
    function openMenu() {
        visible = true;
        menuOpen = true;
        contentRoot.opacity = 1.0;
        contentRoot.activeIndex = 0; // Default to first button (Shutdown)
        contentRoot.forceActiveFocus();
    }

    // Above standard windows, focusable to grab escape key / keyboard inputs
    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Cover the entire screen
    anchors.top: true

    // Transparent window frame (blending is handled by QML components inside)
    color: "transparent"
    focusable: true
    visible: false

    // Root item for content animation and focus handling
    Item {
        id: contentRoot

        property int activeIndex: 0

        anchors.fill: parent
        focus: true
        opacity: 0.0

        // Smooth transition on opacity for fade-in/fade-out effect
        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Keys.onEscapePressed: {
            closeMenu();
        }
        Keys.onLeftPressed: {
            activeIndex = (activeIndex - 1 + 6) % 6;
        }
        Keys.onReturnPressed: {
            executeAction(activeIndex);
        }
        Keys.onRightPressed: {
            activeIndex = (activeIndex + 1) % 6;
        }
        Keys.onSpacePressed: {
            executeAction(activeIndex);
        }
        Keys.onTabPressed: {
            activeIndex = (activeIndex + 1) % 6;
        }

        // When opacity reaches 0 after fade out, hide the window
        onOpacityChanged: {
            if (opacity === 0.0) {
                powerWindow.visible = false;
                powerWindow.dismissed();
            }
        }

        // Transparent background overlay to capture click outside
        Rectangle {
            anchors.fill: parent
            color: "transparent"

            MouseArea {
                anchors.fill: parent

                onClicked: {
                    closeMenu();
                }
            }
        }

        // Centered popup panel containing the power actions
        Rectangle {
            id: popup

            anchors.centerIn: parent
            border.color: Config.md3.surface_container
            border.width: 1

            // Styling matches SCSS exactly
            color: Config.md3.background
            height: layout.implicitHeight + 30
            radius: 50
            scale: powerWindow.menuOpen ? 1.0 : 0.85
            width: layout.implicitWidth + 30

            Behavior on scale {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutBack
                }
            }

            // Prevent click-through to the background overlay
            MouseArea {
                anchors.fill: parent

                onClicked: {}
            }
            RowLayout {
                id: layout

                anchors.centerIn: parent
                spacing: 16

                PowerButton {
                    iconName: "system-shutdown-symbolic"
                    index: 0
                }
                PowerButton {
                    iconName: "system-reboot-symbolic"
                    index: 1
                }
                PowerButton {
                    iconName: "system-lock-screen-symbolic"
                    index: 2
                }
                PowerButton {
                    iconName: "system-hibernate-symbolic"
                    index: 3
                }
                PowerButton {
                    iconName: "system-suspend-symbolic"
                    index: 4
                }
                PowerButton {
                    iconName: "system-log-out-symbolic"
                    index: 5
                }
            }
        }
    }
}
