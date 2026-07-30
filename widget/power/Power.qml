import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../../"

PanelWindow {
    id: powerWindow

    property var actions: [
        {
            "actionIndex": 0,
            "label": "Shut down",
            "description": "Power off",
            "icon": "system-shutdown-symbolic",
            "accent": Config.md3.error
        },
        {
            "actionIndex": 1,
            "label": "Restart",
            "description": "Restart the system",
            "icon": "system-reboot-symbolic",
            "accent": Config.md3.primary
        },
        {
            "actionIndex": 2,
            "label": "Lock",
            "description": "Lock the screen",
            "icon": "system-lock-screen-symbolic",
            "accent": Config.md3.secondary
        },
        {
            "actionIndex": 3,
            "label": "Hibernate",
            "description": "Save session to disk",
            "icon": "system-hibernate-symbolic",
            "accent": Config.md3.tertiary
        },
        {
            "actionIndex": 4,
            "label": "Suspend",
            "description": "Sleep until resumed",
            "icon": "system-suspend-symbolic",
            "accent": Config.md3.secondary
        },
        {
            "actionIndex": 5,
            "label": "Log out",
            "description": "Exit the Niri session",
            "icon": "system-log-out-symbolic",
            "accent": Config.md3.primary
        }
    ]
    property var commands: [["poweroff"], ["reboot"], [], ["systemctl", "hibernate"], ["systemctl", "suspend"], ["niri", "msg", "action", "quit"]]
    property bool menuOpen: false
    readonly property var selectedAction: actions[contentRoot.activeIndex]

    signal dismissed

    function closeMenu() {
        if (!visible || !menuOpen)
            return;
        menuOpen = false;
        closeTimer.restart();
    }
    function executeAction(index) {
        if (index < 0 || index >= commands.length)
            return;

        closeMenu();
        if (index === 2)
            StateManager.lockScreen();
        else
            Quickshell.execDetached(commands[index]);
    }
    function openMenu() {
        closeTimer.stop();
        contentRoot.activeIndex = 0;
        visible = true;
        menuOpen = true;
        contentRoot.forceActiveFocus();
    }

    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    focusable: true
    visible: false

    Timer {
        id: closeTimer

        interval: 220

        onTriggered: {
            powerWindow.visible = false;
            powerWindow.dismissed();
        }
    }
    Item {
        id: contentRoot

        property int activeIndex: 0

        anchors.fill: parent
        focus: true
        opacity: powerWindow.menuOpen ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: powerWindow.menuOpen ? 190 : 150
                easing.type: Easing.OutCubic
            }
        }

        Keys.onEscapePressed: powerWindow.closeMenu()
        Keys.onLeftPressed: activeIndex = (activeIndex - 1 + powerWindow.actions.length) % powerWindow.actions.length
        Keys.onReturnPressed: powerWindow.executeAction(activeIndex)
        Keys.onRightPressed: activeIndex = (activeIndex + 1) % powerWindow.actions.length
        Keys.onSpacePressed: powerWindow.executeAction(activeIndex)
        Keys.onTabPressed: activeIndex = (activeIndex + 1) % powerWindow.actions.length

        Rectangle {
            anchors.fill: parent
            color: Config.alpha(Config.md3.scrim, powerWindow.menuOpen ? 0.16 : 0)

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }

            MouseArea {
                anchors.fill: parent

                onClicked: powerWindow.closeMenu()
            }
        }
        Item {
            id: popupGroup

            anchors.centerIn: parent
            height: popup.height
            scale: powerWindow.menuOpen ? 1 : 0.94
            width: popup.width

            Behavior on scale {
                NumberAnimation {
                    duration: powerWindow.menuOpen ? 240 : 140
                    easing.type: powerWindow.menuOpen ? Easing.OutCubic : Easing.InCubic
                }
            }
            transform: Translate {
                y: powerWindow.menuOpen ? 0 : 8

                Behavior on y {
                    NumberAnimation {
                        duration: powerWindow.menuOpen ? 240 : 140
                        easing.type: powerWindow.menuOpen ? Easing.OutCubic : Easing.InCubic
                    }
                }
            }

            Rectangle {
                id: popup

                anchors.horizontalCenter: parent.horizontalCenter
                border.color: Config.alpha(Config.md3.outline_variant, 0.48)
                border.width: 1
                color: Config.alpha(Config.md3.background, 0.97)
                height: 104
                layer.enabled: powerWindow.visible
                radius: height / 2
                width: 572

                layer.effect: DropShadow {
                    color: Config.alpha(Config.md3.shadow, 0.55)
                    horizontalOffset: 0
                    radius: 22
                    samples: 29
                    transparentBorder: true
                    verticalOffset: 8
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    border.color: Config.alpha(Config.md3.on_surface, 0.075)
                    border.width: 1
                    color: Config.alpha(Config.md3.background, 0.38)
                    radius: height / 2
                }
                Row {
                    id: actionsRow

                    anchors.centerIn: parent
                    spacing: 10

                    Repeater {
                        model: powerWindow.actions

                        delegate: PowerButton {
                            required property var modelData

                            accent: modelData.accent
                            actionIndex: modelData.actionIndex
                            active: contentRoot.activeIndex === modelData.actionIndex
                            iconName: modelData.icon
                            label: modelData.label
                            menuOpen: powerWindow.menuOpen

                            onContainsMouseChanged: {
                                if (containsMouse)
                                    contentRoot.activeIndex = modelData.actionIndex;
                            }
                            onTriggered: powerWindow.executeAction(modelData.actionIndex)
                        }
                    }
                }
            }
        }
    }
}
