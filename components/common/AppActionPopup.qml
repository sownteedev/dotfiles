pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import ".."
import "../../"
import "../../service"

Popup {
    id: root

    property real anchorGap: 8
    property string appName: ""
    property var entry: null
    property bool openAboveAnchor: false
    readonly property bool pinned: DockService.isPinned(entry)
    readonly property Item regionItem: popupBackground

    signal appLaunched

    function openFor(appEntry, name, anchorItem, pointX, pointY) {
        if (!appEntry || !anchorItem || !parent)
            return;
        entry = appEntry;
        appName = name;
        var point = anchorItem.mapToItem(parent, pointX, pointY);
        x = Math.max(10, Math.min(point.x + 8, parent.width - width - 10));
        if (openAboveAnchor) {
            var anchorTop = anchorItem.mapToItem(parent, 0, 0);
            y = Math.max(10, anchorTop.y - height - anchorGap);
            open();
            return;
        }
        var below = point.y + 8;
        y = below + height <= parent.height - 10 ? below : Math.max(10, point.y - height - 8);
        open();
    }
    function triggerAction(action) {
        if (action === "open") {
            DockService.launch(entry);
            close();
            appLaunched();
        } else if (action === "pin") {
            DockService.togglePinned(entry);
            close();
        }
    }

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    focus: true
    height: actionLayout.implicitHeight + topPadding + bottomPadding
    modal: false
    padding: 8
    parent: Overlay.overlay
    width: 236

    background: Item {
        id: popupBackground

        ShellShadow {
            cornerRadius: popupSurface.radius
            target: popupSurface
        }
        Rectangle {
            id: popupSurface

            anchors.fill: parent
            border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.46 : 0.32)
            border.width: 1
            color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.98 : 0.96)
            radius: 18
        }
    }
    contentItem: ColumnLayout {
        id: actionLayout

        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.preferredHeight: 46
            Layout.rightMargin: 8
            spacing: 11

            IconImage {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                mipmap: true
                smooth: true
                source: root.entry ? Quickshell.iconPath(root.entry.icon || "application-x-executable") : ""
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                text: root.appName
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.preferredHeight: 1
            Layout.rightMargin: 8
            color: Config.alpha(Config.md3.outline_variant, 0.34)
        }
        Repeater {
            model: [
                {
                    "action": "open",
                    "icon": "window-new-symbolic",
                    "label": qsTr("Open")
                },
                {
                    "action": "pin",
                    "icon": root.pinned ? "non-starred-symbolic" : "starred-symbolic",
                    "label": root.pinned ? qsTr("Remove from Dock") : qsTr("Pin to Dock")
                }
            ]

            delegate: Rectangle {
                id: actionButton

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: actionMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.15) : actionMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                radius: 12

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(100)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    IconImage {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: 18
                        layer.enabled: true
                        source: Quickshell.iconPath(actionButton.modelData.icon)

                        layer.effect: ColorOverlay {
                            color: actionButton.modelData.action === "pin" && !root.pinned ? Config.md3.primary : Config.md3.on_surface_variant
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: actionButton.modelData.action === "pin" && !root.pinned ? Config.md3.primary : Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        text: actionButton.modelData.label
                    }
                }
                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.triggerAction(actionButton.modelData.action)
                }
            }
        }
    }
    enter: Transition {
        NumberAnimation {
            duration: Config.animationDuration(150)
            easing.type: Easing.OutCubic
            from: 0
            property: "opacity"
            to: 1
        }
    }
    exit: Transition {
        NumberAnimation {
            duration: Config.animationDuration(100)
            easing.type: Easing.InCubic
            from: 1
            property: "opacity"
            to: 0
        }
    }
}
