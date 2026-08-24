import "../../"
import "../../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

RowLayout {
    id: root

    property real itemSpacing: 32
    required property var parentWindow

    spacing: itemSpacing

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: itemArea

            readonly property bool hasCompactArtwork: itemIdentity.indexOf("chrome_status_icon") !== -1
            readonly property real iconExtent: hasCompactArtwork ? 30 : 24
            readonly property bool isSpotify: itemIdentity.indexOf("spotify") !== -1
            readonly property string itemIdentity: [trayItem ? trayItem.id : "", trayItem ? trayItem.title : "", trayItem ? trayItem.tooltipTitle : ""].join(" ").toLowerCase()
            readonly property var trayItem: modelData

            function closeMenuPopup() {
                if (menuPopupLoader.active)
                    menuPopupLoader.active = false;
                else if (menuPopupLoader.loading)
                    menuPopupLoader.loading = false;
            }
            function toggleMenuPopup() {
                if (menuPopupLoader.active)
                    menuPopupLoader.active = false;
                else if (menuPopupLoader.loading)
                    menuPopupLoader.loading = false;
                else
                    menuPopupLoader.loading = true;
            }

            Layout.alignment: Qt.AlignVCenter
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            implicitHeight: 30
            implicitWidth: 24

            onClicked: mouse => {
                if (!itemArea.trayItem)
                    return;

                if (mouse.button === Qt.MiddleButton) {
                    itemArea.closeMenuPopup();
                    itemArea.trayItem.secondaryActivate();
                    return;
                }

                if (mouse.button === Qt.RightButton) {
                    if (itemArea.trayItem.hasMenu)
                        itemArea.toggleMenuPopup();
                    return;
                }

                if (itemArea.trayItem.onlyMenu && itemArea.trayItem.hasMenu) {
                    itemArea.toggleMenuPopup();
                    return;
                }

                itemArea.closeMenuPopup();
                itemArea.trayItem.activate();
            }

            // PopupWindow is created only when the tray item is clicked.
            LazyLoader {
                id: menuPopupLoader

                active: false

                PopupWindow {
                    id: menuPopup

                    readonly property var activeMenu: menuStack.length > 0 ? menuStack[menuStack.length - 1] : rootMenu
                    readonly property string activeMenuTitle: menuStack.length > 0 ? String(menuStack[menuStack.length - 1].text || "Menu") : ""
                    readonly property real desiredHeight: layout.implicitHeight + 30 + shadowPadding * 2
                    property var menuStack: []
                    readonly property var rootMenu: itemArea.trayItem && itemArea.trayItem.hasMenu ? itemArea.trayItem.menu : null
                    readonly property real screenHeight: root.parentWindow && root.parentWindow.screen ? root.parentWindow.screen.height : 720
                    readonly property real shadowPadding: Math.min(24, Math.ceil(Math.max(8, Config.shellComponentShadowBlur + Math.max(Math.abs(Config.shellComponentShadowOffsetX), Math.abs(Config.shellComponentShadowOffsetY)) + Math.max(0, Config.shellComponentShadowSpread) + 2)))

                    function closeMenu() {
                        for (var i = 0; i < menuStack.length; i++) {
                            if (menuStack[i] && typeof menuStack[i].sendClosed === "function")
                                menuStack[i].sendClosed();
                        }
                        menuStack = [];
                        itemArea.closeMenuPopup();
                    }
                    function openSubmenu(entry) {
                        if (!entry || !entry.enabled || !entry.hasChildren)
                            return;
                        if (typeof entry.sendOpened === "function")
                            entry.sendOpened();
                        menuStack = menuStack.concat([entry]);
                    }
                    function returnToParentMenu() {
                        if (menuStack.length === 0)
                            return;
                        var leaving = menuStack[menuStack.length - 1];
                        if (leaving && typeof leaving.sendClosed === "function")
                            leaving.sendClosed();
                        menuStack = menuStack.slice(0, menuStack.length - 1);
                    }

                    anchor.edges: Edges.Bottom | Edges.Left
                    // ONLY set anchor.item (setting anchor.window unsets anchor.item, causing positioning/crash issues)
                    anchor.item: itemArea
                    anchor.margins.left: -24 - shadowPadding
                    anchor.margins.top: 36 - shadowPadding
                    color: "transparent"
                    grabFocus: true
                    implicitHeight: Responsive.fit(desiredHeight, screenHeight - 70, 120)
                    implicitWidth: Math.min(228 + shadowPadding * 2, Math.max(0, root.parentWindow && root.parentWindow.screen ? root.parentWindow.screen.width - 16 : 228 + shadowPadding * 2))
                    visible: true

                    onActiveMenuChanged: Qt.callLater(function () {
                        menuFlickable.contentY = 0;
                    })

                    // Auto-destroy the window when focus is lost (dismissOnOutsideClick via grabFocus)
                    onVisibleChanged: {
                        if (!visible)
                            menuPopup.closeMenu();
                    }

                    QsMenuOpener {
                        id: menuOpener

                        menu: menuPopup.activeMenu
                    }
                    ShellShadow {
                        componentShadow: true
                        cornerRadius: bgRect.radius
                        target: bgRect
                    }
                    Rectangle {
                        id: bgRect

                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: menuPopup.shadowPadding
                        anchors.left: parent.left
                        anchors.leftMargin: menuPopup.shadowPadding
                        anchors.right: parent.right
                        anchors.rightMargin: menuPopup.shadowPadding
                        anchors.top: parent.top
                        anchors.topMargin: menuPopup.shadowPadding + 10 // Room for the top arrow inside window boundaries
                        border.color: Config.alpha(Config.md3.on_surface, 0.08)
                        border.width: 1
                        color: Config.md3.surface_container
                        radius: 12

                        Flickable {
                            id: menuFlickable

                            anchors.fill: parent
                            anchors.margins: 10
                            boundsBehavior: Flickable.StopAtBounds
                            clip: contentHeight > height
                            contentHeight: layout.implicitHeight
                            contentWidth: width
                            flickableDirection: Flickable.VerticalFlick
                            interactive: contentHeight > height

                            ColumnLayout {
                                id: layout

                                spacing: 4
                                width: parent.width

                                Rectangle {
                                    Layout.fillWidth: true
                                    color: backMouse.containsMouse ? Config.md3.surface_container_high : "transparent"
                                    implicitHeight: 34
                                    radius: 8
                                    visible: menuPopup.menuStack.length > 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 9

                                        Text {
                                            color: Config.md3.on_surface
                                            font.family: Config.fontName
                                            font.pixelSize: 18
                                            font.weight: Font.Bold
                                            text: "‹"
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            color: Config.md3.on_surface
                                            elide: Text.ElideRight
                                            font.family: Config.fontName
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            text: menuPopup.activeMenuTitle
                                        }
                                    }
                                    MouseArea {
                                        id: backMouse

                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true

                                        onClicked: menuPopup.returnToParentMenu()
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    color: Config.alpha(Config.md3.on_surface, 0.08)
                                    height: 1
                                    visible: menuPopup.menuStack.length > 0
                                }
                                Repeater {
                                    model: menuOpener.children

                                    delegate: Rectangle {
                                        id: entryItem

                                        Layout.fillWidth: true
                                        color: modelData.isSeparator ? "transparent" : (entryMouse.containsMouse ? Config.md3.surface_container_high : "transparent")
                                        implicitHeight: modelData.isSeparator ? 8 : 34
                                        opacity: modelData.isSeparator || modelData.enabled ? 1 : 0.42
                                        radius: 8

                                        // Separator line
                                        Rectangle {
                                            anchors.centerIn: parent
                                            color: Config.alpha(Config.md3.on_surface, 0.08)
                                            height: 1
                                            visible: modelData.isSeparator
                                            width: parent.width
                                        }

                                        // Non-separator content
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10
                                            visible: !modelData.isSeparator

                                            // Checkbox/Radio indicator
                                            Rectangle {
                                                border.color: Config.alpha(Config.md3.on_surface, 0.3)
                                                border.width: 1
                                                color: "transparent"
                                                height: 14
                                                radius: modelData.buttonType === 2 ? 7 : 3 // 2 is Radio (circle), otherwise checkbox
                                                visible: modelData.buttonType === 1 || modelData.buttonType === 2
                                                width: 14

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    color: Config.md3.primary
                                                    height: 8
                                                    radius: modelData.buttonType === 2 ? 4 : 2
                                                    visible: modelData.checkState === 2 // Checked state in Qt
                                                    width: 8
                                                }
                                            }

                                            // Icon if exists
                                            IconImage {
                                                height: 16
                                                layer.enabled: true
                                                source: modelData.icon && modelData.icon.toString() !== "" ? modelData.icon : Quickshell.iconPath("application-x-executable")
                                                visible: modelData.icon !== ""
                                                width: 16

                                                layer.effect: ColorOverlay {
                                                    color: Config.md3.on_surface
                                                }
                                            }

                                            // Label text
                                            Text {
                                                Layout.fillWidth: true
                                                color: entryMouse.containsMouse ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.9)
                                                elide: Text.ElideRight
                                                font.family: Config.fontName
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                                text: modelData.text || ""
                                            }
                                            Text {
                                                color: Config.md3.on_surface_variant
                                                font.family: Config.fontName
                                                font.pixelSize: 17
                                                font.weight: Font.Bold
                                                text: "›"
                                                visible: modelData.hasChildren
                                            }
                                        }
                                        MouseArea {
                                            id: entryMouse

                                            anchors.fill: parent
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: !modelData.isSeparator && modelData.enabled
                                            hoverEnabled: true

                                            onClicked: {
                                                if (modelData.hasChildren) {
                                                    menuPopup.openSubmenu(modelData);
                                                    return;
                                                }

                                                modelData.triggered();
                                                menuPopup.closeMenu();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 1. The Arrow Triangle (rotated square) - placed outside bgRect to avoid layer clipping!
                    Rectangle {
                        id: arrowTriangle

                        border.color: Config.alpha(Config.md3.on_surface, 0.08)
                        border.width: 1
                        color: Config.md3.surface_container
                        height: 12
                        rotation: 45
                        width: 12
                        x: bgRect.x + 36 - width / 2
                        y: bgRect.y - height / 2
                    }

                    // 2. The Border Cover (hides the card's top border and the triangle's bottom half)
                    Rectangle {
                        color: Config.md3.surface_container
                        height: 6
                        width: 20
                        x: bgRect.x + 36 - width / 2
                        y: bgRect.y
                    }
                }
            }
            IconImage {
                anchors.centerIn: parent
                height: itemArea.iconExtent
                layer.enabled: itemArea.isSpotify
                opacity: itemArea.containsMouse ? 1 : (itemArea.isSpotify ? 0.95 : 0.75)
                source: itemArea.trayItem.icon && itemArea.trayItem.icon.toString() !== "" ? itemArea.trayItem.icon : Quickshell.iconPath("application-x-executable")
                width: itemArea.iconExtent

                layer.effect: ColorOverlay {
                    color: "#1db954"
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
