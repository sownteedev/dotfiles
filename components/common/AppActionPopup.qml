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
    property bool confirmingUninstall: false
    property var entry: null
    readonly property string entryId: entry ? String(entry.id || "") : ""
    property bool openAboveAnchor: false
    readonly property bool packageMatches: ApplicationPackageService.inspectedAppId === entryId
    readonly property bool pinned: DockService.isPinned(entry)
    readonly property Item regionItem: popupBackground
    property string uninstallErrorMessage: ""
    property bool uninstallFailed: false

    signal appLaunched

    function blockerSummary(blockers) {
        if (!Array.isArray(blockers) || blockers.length === 0)
            return qsTr("another package");
        if (blockers.length <= 2)
            return blockers.join(", ");
        return qsTr("%1 +%2").arg(blockers.slice(0, 2).join(", ")).arg(blockers.length - 2);
    }
    function openFor(appEntry, name, anchorItem, pointX, pointY) {
        if (!appEntry || !anchorItem || !parent)
            return;
        entry = appEntry;
        appName = name;
        confirmingUninstall = false;
        uninstallErrorMessage = "";
        uninstallFailed = false;
        confirmUninstallTimer.stop();
        uninstallErrorTimer.stop();
        ApplicationPackageService.inspect(appEntry.id);
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
        } else if (action === "uninstall") {
            if (!packageMatches || !ApplicationPackageService.available || ApplicationPackageService.uninstalling)
                return;
            uninstallFailed = false;
            if (!confirmingUninstall) {
                confirmingUninstall = true;
                confirmUninstallTimer.restart();
                return;
            }
            confirmUninstallTimer.stop();
            ApplicationPackageService.uninstall(entryId);
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
            model: {
                var actions = [
                    {
                        "action": "open",
                        "danger": false,
                        "description": "",
                        "enabled": true,
                        "icon": "window-new-symbolic",
                        "label": qsTr("Open")
                    },
                    {
                        "action": "pin",
                        "danger": false,
                        "description": "",
                        "enabled": true,
                        "icon": root.pinned ? "non-starred-symbolic" : "starred-symbolic",
                        "label": root.pinned ? qsTr("Remove from Dock") : qsTr("Pin to Dock")
                    }
                ];
                if (root.packageMatches && ApplicationPackageService.inspecting) {
                    actions.push({
                        "action": "inspect",
                        "danger": false,
                        "description": "",
                        "enabled": false,
                        "icon": "system-search-symbolic",
                        "label": qsTr("Checking install source…")
                    });
                } else if (root.packageMatches && ApplicationPackageService.available) {
                    if (!ApplicationPackageService.removable) {
                        actions.push({
                            "action": "blocked",
                            "danger": true,
                            "description": ApplicationPackageService.blockers.length > 0 ? qsTr("Required by %1").arg(root.blockerSummary(ApplicationPackageService.blockers)) : ApplicationPackageService.errorMessage || qsTr("The package manager rejected removal"),
                            "enabled": false,
                            "icon": "changes-prevent-symbolic",
                            "label": qsTr("Can't uninstall")
                        });
                    } else {
                        var uninstalling = ApplicationPackageService.uninstalling && ApplicationPackageService.uninstallAppId === root.entryId;
                        actions.push({
                            "action": "uninstall",
                            "danger": true,
                            "description": root.uninstallFailed ? root.uninstallErrorMessage : "",
                            "enabled": !ApplicationPackageService.uninstalling,
                            "icon": root.confirmingUninstall || root.uninstallFailed ? "dialog-warning-symbolic" : "user-trash-symbolic",
                            "label": uninstalling ? qsTr("Uninstalling…") : root.uninstallFailed ? qsTr("Uninstall failed") : root.confirmingUninstall ? qsTr("Remove %1?").arg(ApplicationPackageService.packageName) : qsTr("Uninstall")
                        });
                    }
                }
                return actions;
            }

            delegate: Rectangle {
                id: actionButton

                readonly property bool dangerAction: modelData.danger === true
                readonly property bool dangerHighlighted: dangerAction && (modelData.action === "blocked" || root.confirmingUninstall || root.uninstallFailed)
                required property var modelData

                Accessible.name: modelData.description === "" ? modelData.label : modelData.label + ". " + modelData.description
                Accessible.role: Accessible.Button
                Layout.fillWidth: true
                Layout.preferredHeight: modelData.description === "" ? 44 : 58
                color: dangerAction ? (actionMouse.pressed ? Config.alpha(Config.md3.error_container, 0.92) : actionMouse.containsMouse || dangerHighlighted ? Config.alpha(Config.md3.error_container, 0.7) : "transparent") : actionMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.15) : actionMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                opacity: modelData.enabled || modelData.action === "blocked" ? 1 : 0.5
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
                            color: actionButton.dangerAction ? (actionButton.dangerHighlighted ? Config.md3.on_error_container : Config.md3.error) : actionButton.modelData.action === "pin" && !root.pinned ? Config.md3.primary : Config.md3.on_surface_variant
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            color: actionButton.dangerAction ? (actionButton.dangerHighlighted ? Config.md3.on_error_container : Config.md3.error) : actionButton.modelData.action === "pin" && !root.pinned ? Config.md3.primary : Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            text: actionButton.modelData.label
                        }
                        Text {
                            Layout.fillWidth: true
                            color: actionButton.dangerHighlighted ? Config.alpha(Config.md3.on_error_container, 0.78) : Config.alpha(Config.md3.on_surface_variant, 0.78)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            text: actionButton.modelData.description
                            visible: text !== ""
                        }
                    }
                }
                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: actionButton.modelData.enabled
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

    onClosed: {
        confirmingUninstall = false;
        uninstallErrorMessage = "";
        uninstallFailed = false;
        confirmUninstallTimer.stop();
        uninstallErrorTimer.stop();
    }

    Timer {
        id: confirmUninstallTimer

        interval: 5000
        repeat: false

        onTriggered: root.confirmingUninstall = false
    }
    Timer {
        id: uninstallErrorTimer

        interval: 3500
        repeat: false

        onTriggered: {
            root.uninstallErrorMessage = "";
            root.uninstallFailed = false;
        }
    }
    Connections {
        function onUninstallFinished(appId, success, message) {
            if (appId !== root.entryId)
                return;
            if (success) {
                root.close();
                return;
            }
            console.warn("[AppActionPopup]", message);
            root.confirmingUninstall = false;
            root.uninstallErrorMessage = String(message || qsTr("The package manager rejected the operation"));
            root.uninstallFailed = true;
            uninstallErrorTimer.restart();
        }

        target: ApplicationPackageService
    }
}
