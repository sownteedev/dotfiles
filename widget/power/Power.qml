import QtQuick
import Quickshell
import "../../"
import "../../components"

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
    property int pendingActionIndex: -1
    readonly property var selectedAction: actions[contentRoot.activeIndex]

    signal dismissed

    function closeMenu() {
        if (!visible || !menuOpen)
            return;
        menuOpen = false;
        closeTimer.restart();
    }
    function executeAction(index) {
        if (!menuOpen || pendingActionIndex >= 0 || index < 0 || index >= commands.length)
            return;

        pendingActionIndex = index;
        closeMenu();
    }
    function openMenu() {
        if (pendingActionIndex >= 0)
            return;
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;
        closeTimer.stop();
        contentRoot.animateSelectionMove = false;
        contentRoot.activeIndex = 0;
        actionsViewport.contentX = 0;
        visible = true;
        menuOpen = true;
        contentRoot.forceActiveFocus();
    }
    function revealActiveAction() {
        Qt.callLater(function () {
            const activeButton = actionsRepeater.itemAt(contentRoot.activeIndex);
            if (!activeButton || actionsViewport.width <= 0 || actionsViewport.contentWidth <= actionsViewport.width)
                return;

            const margin = 6;
            const left = actionsRow.x + activeButton.x;
            const right = left + activeButton.width;
            let targetX = actionsViewport.contentX;
            if (left < targetX + margin)
                targetX = left - margin;
            else if (right > targetX + actionsViewport.width - margin)
                targetX = right - actionsViewport.width + margin;

            actionsViewport.contentX = Responsive.clamp(targetX, 0, Math.max(0, actionsViewport.contentWidth - actionsViewport.width));
        });
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
            var actionIndex = powerWindow.pendingActionIndex;
            powerWindow.pendingActionIndex = -1;
            powerWindow.dismissed();
            if (actionIndex === 2)
                StateManager.lockScreen();
            else if (actionIndex >= 0 && actionIndex < powerWindow.commands.length)
                Quickshell.execDetached(powerWindow.commands[actionIndex]);
        }
    }
    Timer {
        id: revealActiveActionTimer

        interval: 280
        repeat: false

        onTriggered: powerWindow.revealActiveAction()
    }
    Item {
        id: contentRoot

        property int activeIndex: 0
        property bool animateSelectionMove: false

        function selectAction(index) {
            const nextIndex = Math.max(0, Math.min(powerWindow.actions.length - 1, index));
            if (nextIndex === activeIndex)
                return;

            animateSelectionMove = Math.abs(nextIndex - activeIndex) === 1;
            activeIndex = nextIndex;
        }

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
        Keys.onLeftPressed: selectAction((activeIndex - 1 + powerWindow.actions.length) % powerWindow.actions.length)
        Keys.onReturnPressed: powerWindow.executeAction(activeIndex)
        Keys.onRightPressed: selectAction((activeIndex + 1) % powerWindow.actions.length)
        Keys.onSpacePressed: powerWindow.executeAction(activeIndex)
        Keys.onTabPressed: selectAction((activeIndex + 1) % powerWindow.actions.length)
        onActiveIndexChanged: {
            powerWindow.revealActiveAction();
            revealActiveActionTimer.restart();
        }

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

            ShellShadow {
                active: powerWindow.visible
                cornerRadius: popup.radius
                target: popup
            }
            Rectangle {
                id: popup

                anchors.horizontalCenter: parent.horizontalCenter
                border.color: Config.alpha(Config.md3.outline_variant, 0.48)
                border.width: 1
                color: Config.alpha(Config.md3.background, 0.97)
                height: 116
                radius: height / 2
                width: Responsive.fitWithMargins(516, powerWindow.width, 16, 340)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    border.color: Config.alpha(Config.md3.on_surface, 0.075)
                    border.width: 1
                    color: Config.alpha(Config.md3.background, 0.38)
                    radius: height / 2
                }
                Flickable {
                    id: actionsViewport

                    anchors.fill: parent
                    anchors.margins: 10
                    boundsBehavior: Flickable.StopAtBounds
                    clip: contentWidth > width
                    contentHeight: height
                    contentWidth: Math.max(width, actionsRow.implicitWidth)
                    flickableDirection: Flickable.HorizontalFlick
                    interactive: contentWidth > width

                    ShellShadow {
                        active: powerWindow.menuOpen
                        componentShadow: true
                        cornerRadius: selectionIndicator.radius
                        target: selectionIndicator
                    }
                    Rectangle {
                        id: selectionIndicator

                        readonly property Item activeButton: actionsRepeater.itemAt(contentRoot.activeIndex)

                        anchors.verticalCenter: parent.verticalCenter
                        border.color: Config.alpha(powerWindow.selectedAction.accent, 0.62)
                        border.width: 1
                        color: Config.alpha(powerWindow.selectedAction.accent, 0.24)
                        height: 70
                        radius: height / 2
                        width: height
                        x: actionsRow.x + (activeButton ? activeButton.x : 0)

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animationDuration(180)
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(180)
                            }
                        }
                        Behavior on x {
                            enabled: powerWindow.menuOpen && contentRoot.animateSelectionMove && !Config.shellReducedMotion

                            SmoothedAnimation {
                                maximumEasingTime: Config.animationDuration(90)
                                reversingMode: SmoothedAnimation.Sync
                                velocity: 760
                            }
                        }
                    }
                    Row {
                        id: actionsRow

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        x: actionsRow.implicitWidth <= actionsViewport.width ? (actionsViewport.width - actionsRow.implicitWidth) / 2 : 0

                        Repeater {
                            id: actionsRepeater

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
                                        contentRoot.selectAction(modelData.actionIndex);
                                }
                                onTriggered: powerWindow.executeAction(modelData.actionIndex)
                            }
                        }
                    }
                }
            }
        }
    }
}
