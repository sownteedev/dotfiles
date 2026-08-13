import "../../"
import "../../components"
import "../../components/settings" as SettingsComponents
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root

    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Validating…" : "Apply behavior"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: true

    function apply() {
        SettingsHubService.saveBehavior({
            "showHotkeyOverlayAtStartup": showHotkeyOverlay.checked,
            "hideUnboundHotkeys": hideUnbound.checked,
            "preferNoCsd": preferNoCsd.checked,
            "disablePrimaryClipboard": disablePrimary.checked,
            "disableConfigError": disableConfigError.checked,
            "screenshotSavingEnabled": screenshotCard.checked,
            "screenshotPath": screenshotPath.text,
            "xwaylandEnabled": xwaylandCard.checked,
            "xwaylandPath": xwaylandPath.text,
            "hideCursorWhileTyping": hideCursor.checked,
            "cursorTimeoutEnabled": cursorTimeoutCard.checked,
            "cursorTimeoutMs": Number(cursorTimeout.text),
            "cursorTheme": cursorTheme.text,
            "cursorSize": Number(cursorSize.text),
            "disablePowerKeyHandling": disablePowerKey.checked,
            "warpMouseToFocus": warpMouseCard.checked,
            "warpMouseMode": warpMode.value,
            "focusFollowsMouse": focusFollowsCard.checked,
            "focusFollowsMaxScrollAmount": focusMaxScroll.text,
            "workspaceAutoBackAndForth": workspaceBackForth.checked,
            "modKey": modKey.value,
            "modKeyNested": modKeyNested.value,
            "dndViewTriggerWidth": Number(dndViewTriggerWidth.text),
            "dndViewDelayMs": Number(dndViewDelay.text),
            "dndViewMaxSpeed": Number(dndViewMaxSpeed.text),
            "dndWorkspaceTriggerHeight": Number(dndWorkspaceTriggerHeight.text),
            "dndWorkspaceDelayMs": Number(dndWorkspaceDelay.text),
            "dndWorkspaceMaxSpeed": Number(dndWorkspaceMaxSpeed.text),
            "hotCornersEnabled": hotCornersCard.checked,
            "hotCornerTopLeft": hotCornerTopLeft.checked,
            "hotCornerTopRight": hotCornerTopRight.checked,
            "hotCornerBottomLeft": hotCornerBottomLeft.checked,
            "hotCornerBottomRight": hotCornerBottomRight.checked,
            "switchEvents": switchEventsCard.checked,
            "lidCloseAction": lidCloseAction.text,
            "lidOpenAction": lidOpenAction.text,
            "tabletModeOnAction": tabletOnAction.text,
            "tabletModeOffAction": tabletOffAction.text
        });
    }
    function resetPage() {
        syncFields();
    }
    function syncFields() {
        const value = SettingsHubService.behaviorSettings || {};
        showHotkeyOverlay.checked = value.showHotkeyOverlayAtStartup === true;
        hideUnbound.checked = value.hideUnboundHotkeys === true;
        preferNoCsd.checked = value.preferNoCsd === true;
        disablePrimary.checked = value.disablePrimaryClipboard === true;
        disableConfigError.checked = value.disableConfigError === true;
        screenshotCard.checked = value.screenshotSavingEnabled !== false;
        screenshotPath.text = value.screenshotPath || "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
        xwaylandCard.checked = value.xwaylandEnabled === true;
        xwaylandPath.text = value.xwaylandPath || "xwayland-satellite";
        cursorTheme.text = value.cursorTheme || "";
        cursorSize.text = String(value.cursorSize === undefined ? 24 : value.cursorSize);
        hideCursor.checked = value.hideCursorWhileTyping === true;
        cursorTimeoutCard.checked = value.cursorTimeoutEnabled === true;
        cursorTimeout.text = String(value.cursorTimeoutMs === undefined ? 1000 : value.cursorTimeoutMs);
        disablePowerKey.checked = value.disablePowerKeyHandling === true;
        warpMouseCard.checked = value.warpMouseToFocus === true;
        warpMode.value = value.warpMouseMode || "separate";
        focusFollowsCard.checked = value.focusFollowsMouse === true;
        focusMaxScroll.text = value.focusFollowsMaxScrollAmount || "0%";
        workspaceBackForth.checked = value.workspaceAutoBackAndForth === true;
        modKey.value = value.modKey || "";
        modKeyNested.value = value.modKeyNested || "";
        dndViewTriggerWidth.text = String(value.dndViewTriggerWidth === undefined ? 30 : value.dndViewTriggerWidth);
        dndViewDelay.text = String(value.dndViewDelayMs === undefined ? 100 : value.dndViewDelayMs);
        dndViewMaxSpeed.text = String(value.dndViewMaxSpeed === undefined ? 1500 : value.dndViewMaxSpeed);
        dndWorkspaceTriggerHeight.text = String(value.dndWorkspaceTriggerHeight === undefined ? 50 : value.dndWorkspaceTriggerHeight);
        dndWorkspaceDelay.text = String(value.dndWorkspaceDelayMs === undefined ? 100 : value.dndWorkspaceDelayMs);
        dndWorkspaceMaxSpeed.text = String(value.dndWorkspaceMaxSpeed === undefined ? 1500 : value.dndWorkspaceMaxSpeed);
        hotCornersCard.checked = value.hotCornersEnabled !== false;
        hotCornerTopLeft.checked = value.hotCornerTopLeft !== false;
        hotCornerTopRight.checked = value.hotCornerTopRight === true;
        hotCornerBottomLeft.checked = value.hotCornerBottomLeft === true;
        hotCornerBottomRight.checked = value.hotCornerBottomRight === true;
        switchEventsCard.checked = value.switchEvents === true;
        lidCloseAction.text = value.lidCloseAction || "";
        lidOpenAction.text = value.lidOpenAction || "";
        tabletOnAction.text = value.tabletModeOnAction || "";
        tabletOffAction.text = value.tabletModeOffAction || "";
    }
    function triggerHeaderAction() {
        apply();
    }

    clip: true
    contentHeight: behaviorContent.implicitHeight + 28
    contentWidth: Math.max(availableWidth, 760)

    ScrollBar.horizontal: SlimScrollBar {
        accentColor: Config.md3.tertiary
    }
    ScrollBar.vertical: SlimScrollBar {
        accentColor: Config.md3.tertiary
    }

    Component.onCompleted: syncFields()

    Connections {
        function onBehaviorSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    RowLayout {
        id: behaviorContent

        spacing: 16
        width: Math.max(0, root.contentWidth - 24)
        x: 12
        y: 8

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 16

            SettingsExpandableCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                note: "Control Niri's built-in shortcut guide"
                title: "Hotkey overlay"
                toggleVisible: false

                SettingsComponents.SettingsToggleRow {
                    id: showHotkeyOverlay

                    label: "Show important hotkeys at startup"
                    note: "Disable this to keep the startup overlay hidden"

                    onToggled: checked => {
                        return showHotkeyOverlay.checked = checked;
                    }
                }
                SettingsComponents.SettingsToggleRow {
                    id: hideUnbound

                    label: "Hide unavailable shortcuts"
                    note: "Remove actions that have no key assigned"

                    onToggled: checked => {
                        return hideUnbound.checked = checked;
                    }
                }
            }
            SettingsExpandableCard {
                id: screenshotCard

                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                checked: true
                note: "Write Niri screenshots to disk as well as the clipboard"
                title: "Save screenshots"

                onToggled: checked => {
                    return screenshotCard.checked = checked;
                }

                SettingsTextField {
                    id: screenshotPath

                    Layout.fillWidth: true
                    label: "File path"
                    placeholder: "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
                }
            }
            SettingsExpandableCard {
                Layout.fillWidth: true
                accentColor: Config.md3.error
                note: "Pointer focus behavior configured in input.kdl"
                title: "Pointer focus"
                toggleVisible: false

                SettingsExpandableCard {
                    id: warpMouseCard

                    Layout.fillWidth: true
                    accentColor: Config.md3.error
                    contentPadding: 15
                    note: "Move the pointer when keyboard focus changes"
                    title: "Warp pointer to focus"

                    onToggled: checked => {
                        return warpMouseCard.checked = checked;
                    }

                    SettingsComponents.SettingsChoiceRow {
                        id: warpMode

                        Layout.fillWidth: true
                        label: "Warp mode"
                        note: "Separate preserves an axis that is already inside the window"
                        options: [
                            {
                                "label": "Separate axes",
                                "value": "separate"
                            },
                            {
                                "label": "Center X/Y",
                                "value": "center-xy"
                            },
                            {
                                "label": "Always center",
                                "value": "center-xy-always"
                            }
                        ]
                    }
                }
                SettingsExpandableCard {
                    id: focusFollowsCard

                    Layout.fillWidth: true
                    accentColor: Config.md3.error
                    contentPadding: 15
                    note: "Focus windows and outputs when the pointer enters"
                    title: "Focus follows pointer"

                    onToggled: checked => {
                        return focusFollowsCard.checked = checked;
                    }

                    SettingsTextField {
                        id: focusMaxScroll

                        Layout.fillWidth: true
                        label: "Maximum view scroll"
                        placeholder: "0%"
                    }
                }
            }
            SettingsExpandableCard {
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                note: "Global keyboard and workspace behavior"
                title: "Modifier & workspace"
                toggleVisible: false

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    SettingsComponents.SettingsChoiceRow {
                        id: modKey

                        Layout.fillWidth: true
                        label: "Mod key"
                        options: [
                            {
                                "label": "Default",
                                "value": ""
                            },
                            {
                                "label": "Super",
                                "value": "Super"
                            },
                            {
                                "label": "Alt",
                                "value": "Alt"
                            },
                            {
                                "label": "Mod3",
                                "value": "Mod3"
                            },
                            {
                                "label": "Mod5",
                                "value": "Mod5"
                            },
                            {
                                "label": "Ctrl",
                                "value": "Ctrl"
                            },
                            {
                                "label": "Shift",
                                "value": "Shift"
                            }
                        ]
                    }
                    SettingsComponents.SettingsChoiceRow {
                        id: modKeyNested

                        Layout.fillWidth: true
                        label: "Nested Mod key"
                        options: [
                            {
                                "label": "Default",
                                "value": ""
                            },
                            {
                                "label": "Super",
                                "value": "Super"
                            },
                            {
                                "label": "Alt",
                                "value": "Alt"
                            },
                            {
                                "label": "Mod3",
                                "value": "Mod3"
                            },
                            {
                                "label": "Mod5",
                                "value": "Mod5"
                            },
                            {
                                "label": "Ctrl",
                                "value": "Ctrl"
                            },
                            {
                                "label": "Shift",
                                "value": "Shift"
                            }
                        ]
                    }
                }
                SettingsComponents.SettingsToggleRow {
                    id: disablePowerKey

                    label: "Let another service handle the power key"
                    note: "Stops Niri from taking over the physical power button"

                    onToggled: checked => {
                        return disablePowerKey.checked = checked;
                    }
                }
                SettingsComponents.SettingsToggleRow {
                    id: workspaceBackForth

                    label: "Workspace back and forth"
                    note: "Selecting the active workspace returns to the previous one"

                    onToggled: checked => {
                        return workspaceBackForth.checked = checked;
                    }
                }
            }
            SettingsExpandableCard {
                id: xwaylandCard

                Layout.fillWidth: true
                accentColor: Config.md3.error
                note: "Enable only after removing the manual xwayland-satellite autostart entry"
                title: "Xwayland satellite"

                onToggled: checked => {
                    return xwaylandCard.checked = checked;
                }

                SettingsTextField {
                    id: xwaylandPath

                    Layout.fillWidth: true
                    label: "Executable path"
                    placeholder: "xwayland-satellite"
                }
            }
            SettingsExpandableCard {
                id: switchEventsCard

                Layout.fillWidth: true
                accentColor: Config.md3.primary
                note: "Commands run for laptop lid and convertible-tablet events"
                title: "Laptop & tablet switch events"

                onToggled: checked => {
                    return switchEventsCard.checked = checked;
                }

                SettingsTextField {
                    id: lidCloseAction

                    Layout.fillWidth: true
                    label: "Lid close action (KDL)"
                    placeholder: "spawn \"notify-send\" \"Laptop lid closed\""
                }
                SettingsTextField {
                    id: lidOpenAction

                    Layout.fillWidth: true
                    label: "Lid open action (KDL)"
                    placeholder: "spawn \"notify-send\" \"Laptop lid opened\""
                }
                SettingsTextField {
                    id: tabletOnAction

                    Layout.fillWidth: true
                    label: "Tablet mode on action (KDL)"
                    placeholder: "spawn-sh \"command\""
                }
                SettingsTextField {
                    id: tabletOffAction

                    Layout.fillWidth: true
                    label: "Tablet mode off action (KDL)"
                    placeholder: "spawn-sh \"command\""
                }
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 16

            SettingsExpandableCard {
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                note: "Window decorations, clipboard and error reporting"
                title: "Windows & system behavior"
                toggleVisible: false

                SettingsComponents.SettingsToggleRow {
                    id: preferNoCsd

                    label: "Prefer server-side decorations"
                    note: "Restart applications to fully remove their title bars"

                    onToggled: checked => {
                        return preferNoCsd.checked = checked;
                    }
                }
                SettingsComponents.SettingsToggleRow {
                    id: disablePrimary

                    label: "Disable primary selection"
                    note: "Do not copy selected text to the middle-click clipboard"

                    onToggled: checked => {
                        return disablePrimary.checked = checked;
                    }
                }
                SettingsComponents.SettingsToggleRow {
                    id: disableConfigError

                    label: "Hide failed-config overlay"
                    note: "Useful only when another tool reports Niri validation errors"

                    onToggled: checked => {
                        return disableConfigError.checked = checked;
                    }
                }
            }
            SettingsExpandableCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                note: "Drag behavior at screen edges and configurable hot corners"
                title: "Gestures"
                toggleVisible: false

                SettingsExpandableCard {
                    Layout.fillWidth: true
                    accentColor: Config.md3.primary
                    contentPadding: 15
                    note: "Scroll the overview while dragging near a horizontal edge"
                    title: "Drag edge view scroll"
                    toggleVisible: false

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingsTextField {
                            id: dndViewTriggerWidth

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            label: "Trigger width"
                            placeholder: "30"

                            inputItem.validator: IntValidator {
                                bottom: 1
                                top: 1000
                            }
                        }
                        SettingsTextField {
                            id: dndViewDelay

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            label: "Delay (ms)"
                            placeholder: "100"

                            inputItem.validator: IntValidator {
                                bottom: 0
                                top: 60000
                            }
                        }
                        SettingsTextField {
                            id: dndViewMaxSpeed

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            label: "Maximum speed"
                            placeholder: "1500"

                            inputItem.validator: IntValidator {
                                bottom: 1
                                top: 100000
                            }
                        }
                    }
                }
                SettingsExpandableCard {
                    Layout.fillWidth: true
                    accentColor: Config.md3.secondary
                    contentPadding: 15
                    note: "Switch workspaces while dragging near the top or bottom edge"
                    title: "Drag edge workspace switch"
                    toggleVisible: false

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingsTextField {
                            id: dndWorkspaceTriggerHeight

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            label: "Trigger height"
                            placeholder: "50"

                            inputItem.validator: IntValidator {
                                bottom: 1
                                top: 1000
                            }
                        }
                        SettingsTextField {
                            id: dndWorkspaceDelay

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            label: "Delay (ms)"
                            placeholder: "100"

                            inputItem.validator: IntValidator {
                                bottom: 0
                                top: 60000
                            }
                        }
                        SettingsTextField {
                            id: dndWorkspaceMaxSpeed

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            label: "Maximum speed"
                            placeholder: "1500"

                            inputItem.validator: IntValidator {
                                bottom: 1
                                top: 100000
                            }
                        }
                    }
                }
                SettingsExpandableCard {
                    id: hotCornersCard

                    Layout.fillWidth: true
                    accentColor: Config.md3.tertiary
                    contentPadding: 15
                    note: "Open the overview when the pointer reaches a selected corner"
                    title: "Hot corners"

                    onToggled: checked => {
                        hotCornersCard.checked = checked;
                        if (checked && !hotCornerTopLeft.checked && !hotCornerTopRight.checked && !hotCornerBottomLeft.checked && !hotCornerBottomRight.checked)
                            hotCornerTopLeft.checked = true;
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columnSpacing: 18
                        columns: 2
                        rowSpacing: 14

                        SettingsComponents.SettingsToggleRow {
                            id: hotCornerTopLeft

                            Layout.fillWidth: true
                            label: "Top left"

                            onToggled: checked => hotCornerTopLeft.checked = checked
                        }
                        SettingsComponents.SettingsToggleRow {
                            id: hotCornerTopRight

                            Layout.fillWidth: true
                            label: "Top right"

                            onToggled: checked => hotCornerTopRight.checked = checked
                        }
                        SettingsComponents.SettingsToggleRow {
                            id: hotCornerBottomLeft

                            Layout.fillWidth: true
                            label: "Bottom left"

                            onToggled: checked => hotCornerBottomLeft.checked = checked
                        }
                        SettingsComponents.SettingsToggleRow {
                            id: hotCornerBottomRight

                            Layout.fillWidth: true
                            label: "Bottom right"

                            onToggled: checked => hotCornerBottomRight.checked = checked
                        }
                    }
                }
            }
            SettingsExpandableCard {
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                note: "Theme, size and automatic cursor hiding"
                title: "Cursor"
                toggleVisible: false

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    SettingsTextField {
                        id: cursorTheme

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: "Theme"
                        placeholder: "Dark_Cursor"
                    }
                    SettingsTextField {
                        id: cursorSize

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: "Size"
                        placeholder: "24"

                        inputItem.validator: IntValidator {
                            bottom: 8
                            top: 128
                        }
                    }
                }
                SettingsComponents.SettingsToggleRow {
                    id: hideCursor

                    label: "Hide while typing"
                    note: "The cursor returns as soon as the pointer moves"

                    onToggled: checked => {
                        return hideCursor.checked = checked;
                    }
                }
                SettingsExpandableCard {
                    id: cursorTimeoutCard

                    Layout.fillWidth: true
                    accentColor: Config.md3.tertiary
                    contentPadding: 15
                    note: "Hide the pointer after it remains idle"
                    title: "Idle cursor timeout"

                    onToggled: checked => {
                        return cursorTimeoutCard.checked = checked;
                    }

                    SettingsTextField {
                        id: cursorTimeout

                        Layout.fillWidth: true
                        label: "Delay (ms)"
                        placeholder: "1000"

                        inputItem.validator: IntValidator {
                            bottom: 100
                            top: 600000
                        }
                    }
                }
            }
        }
    }
}
