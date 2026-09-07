import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

ScrollView {
    id: root

    readonly property bool compactLayout: width < Responsive.settingsCompactContentWidth
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Applying…" : "Apply layout"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: layoutBaselineState !== "" && JSON.stringify(currentLayoutState()) !== layoutBaselineState
    property string layoutBaselineState: ""
    property var recentBindValues: []

    function currentLayoutState() {
        return {
            "gaps": Number(gapsField.text),
            "borderWidth": Number(borderField.text),
            "shadow": shadowCard.checked,
            "centerFocused": centerFocusedChoice.value,
            "blurEnabled": blurCard.checked,
            "blurPasses": Number(blurPasses.text),
            "blurOffset": Number(blurOffset.text),
            "blurNoise": Number(blurNoise.text),
            "blurSaturation": Number(blurSaturation.text),
            "alwaysCenterSingle": alwaysCenterToggle.checked,
            "emptyWorkspaceAboveFirst": emptyWorkspaceToggle.checked,
            "defaultColumnDisplay": defaultDisplayChoice.value,
            "backgroundColor": layoutBackgroundField.text,
            "defaultColumnWidthMode": defaultWidthMode.value,
            "defaultColumnWidth": defaultWidthMode.value === "fixed" ? Math.round(Number(defaultWidthField.text)) : Number(defaultWidthField.text),
            "presetColumnWidthsEnabled": presetWidthsCard.checked,
            "presetColumnWidths": presetWidthsField.text,
            "presetWindowHeightsEnabled": presetHeightsCard.checked,
            "presetWindowHeights": presetHeightsField.text,
            "strutsEnabled": strutsCard.checked,
            "strutLeft": Number(strutLeft.text),
            "strutRight": Number(strutRight.text),
            "strutTop": Number(strutTop.text),
            "strutBottom": Number(strutBottom.text),
            "overviewZoom": Number(overviewZoomField.text),
            "overviewBackdropColor": overviewBackdropField.text,
            "workspaceShadowEnabled": workspaceShadowCard.checked,
            "workspaceShadowSoftness": Number(workspaceShadowSoftness.text),
            "workspaceShadowSpread": Number(workspaceShadowSpread.text),
            "workspaceShadowOffsetX": Number(workspaceShadowOffsetX.text),
            "workspaceShadowOffsetY": Number(workspaceShadowOffsetY.text),
            "workspaceShadowColor": workspaceShadowColor.text,
            "borderEnabled": borderCard.checked,
            "borderActiveColor": borderActiveColor.text,
            "borderInactiveColor": borderInactiveColor.text,
            "borderUrgentColor": borderUrgentColor.text,
            "borderGradientEnabled": borderGradientCard.checked,
            "borderActiveGradient": borderActiveGradient.text,
            "borderInactiveGradient": borderInactiveGradient.text,
            "borderUrgentGradient": borderUrgentGradient.text,
            "focusRingEnabled": focusRingCard.checked,
            "focusRingWidth": Number(focusRingWidth.text),
            "focusRingActiveColor": focusRingActiveColor.text,
            "focusRingInactiveColor": focusRingInactiveColor.text,
            "focusRingUrgentColor": focusRingUrgentColor.text,
            "focusRingGradientEnabled": focusGradientCard.checked,
            "focusRingActiveGradient": focusActiveGradient.text,
            "focusRingInactiveGradient": focusInactiveGradient.text,
            "focusRingUrgentGradient": focusUrgentGradient.text,
            "tabIndicatorEnabled": tabIndicatorCard.checked,
            "tabHideSingle": tabHideSingle.checked,
            "tabPlaceWithinColumn": tabPlaceWithin.checked,
            "tabGap": Number(tabGap.text),
            "tabWidth": Number(tabWidth.text),
            "tabLength": Number(tabLength.text),
            "tabPosition": tabPosition.value,
            "tabGapsBetween": Number(tabGapsBetween.text),
            "tabCornerRadius": Number(tabCornerRadius.text),
            "tabActiveColor": tabActiveColor.text,
            "tabInactiveColor": tabInactiveColor.text,
            "tabUrgentColor": tabUrgentColor.text,
            "tabGradientEnabled": tabGradientCard.checked,
            "tabActiveGradient": tabActiveGradient.text,
            "tabInactiveGradient": tabInactiveGradient.text,
            "tabUrgentGradient": tabUrgentGradient.text,
            "insertHintEnabled": insertHintCard.checked,
            "insertHintColor": insertHintColor.text,
            "insertHintGradientEnabled": insertGradientCard.checked,
            "insertHintGradient": insertHintGradient.text,
            "shadowSoftness": Number(shadowSoftness.text),
            "shadowSpread": Number(shadowSpread.text),
            "shadowOffsetX": Number(shadowOffsetX.text),
            "shadowOffsetY": Number(shadowOffsetY.text),
            "shadowDrawBehind": shadowDrawBehind.checked,
            "shadowColor": shadowColor.text,
            "shadowInactiveColor": shadowInactiveColor.text,
            "recentWindows": recentWindowsCard.checked,
            "recentDebounceMs": Number(recentDebounce.text),
            "recentOpenDelayMs": Number(recentDelay.text),
            "recentHighlightActiveColor": recentHighlightActiveColor.text,
            "recentHighlightUrgentColor": recentHighlightUrgentColor.text,
            "recentHighlightPadding": Number(recentHighlightPadding.text),
            "recentHighlightCornerRadius": Number(recentHighlightCornerRadius.text),
            "recentPreviewHeight": Number(recentPreviewHeight.text),
            "recentPreviewScale": Number(recentPreviewScale.text),
            "recentBinds": root.recentBindValues
        };
    }
    function resetPage() {
        syncLayoutFields();
    }
    function syncLayoutFields() {
        var settings = SettingsHubService.layoutSettings || {};
        gapsField.text = String(settings.gaps === undefined ? 10 : settings.gaps);
        borderField.text = String(settings.borderWidth === undefined ? 1 : settings.borderWidth);
        shadowCard.checked = settings.shadow !== false;
        centerFocusedChoice.value = settings.centerFocused || "on-overflow";
        defaultDisplayChoice.value = settings.defaultColumnDisplay || "normal";
        layoutBackgroundField.text = settings.backgroundColor || "transparent";
        defaultWidthMode.value = settings.defaultColumnWidthMode || "proportion";
        defaultWidthField.text = String(settings.defaultColumnWidth === undefined ? 1 : settings.defaultColumnWidth);
        presetWidthsCard.checked = settings.presetColumnWidthsEnabled === true;
        presetWidthsField.text = settings.presetColumnWidths || "proportion 0.33333, proportion 0.5, proportion 0.66667";
        presetHeightsCard.checked = settings.presetWindowHeightsEnabled === true;
        presetHeightsField.text = settings.presetWindowHeights || "proportion 0.33333, proportion 0.5, proportion 0.66667";
        strutsCard.checked = settings.strutsEnabled === true;
        strutLeft.text = String(settings.strutLeft === undefined ? 0 : settings.strutLeft);
        strutRight.text = String(settings.strutRight === undefined ? 0 : settings.strutRight);
        strutTop.text = String(settings.strutTop === undefined ? 0 : settings.strutTop);
        strutBottom.text = String(settings.strutBottom === undefined ? 0 : settings.strutBottom);
        overviewZoomField.text = String(settings.overviewZoom === undefined ? 0.4 : settings.overviewZoom);
        overviewBackdropField.text = settings.overviewBackdropColor || "#0a0a0a";
        workspaceShadowCard.checked = settings.workspaceShadowEnabled !== false;
        workspaceShadowSoftness.text = String(settings.workspaceShadowSoftness === undefined ? 30 : settings.workspaceShadowSoftness);
        workspaceShadowSpread.text = String(settings.workspaceShadowSpread === undefined ? 5 : settings.workspaceShadowSpread);
        workspaceShadowOffsetX.text = String(settings.workspaceShadowOffsetX === undefined ? 0 : settings.workspaceShadowOffsetX);
        workspaceShadowOffsetY.text = String(settings.workspaceShadowOffsetY === undefined ? 0 : settings.workspaceShadowOffsetY);
        workspaceShadowColor.text = settings.workspaceShadowColor || "#000000";
        blurCard.checked = settings.blurEnabled === true;
        blurPasses.text = String(settings.blurPasses === undefined ? 3 : settings.blurPasses);
        blurOffset.text = String(settings.blurOffset === undefined ? 3 : settings.blurOffset);
        blurNoise.text = String(settings.blurNoise === undefined ? 0.02 : settings.blurNoise);
        blurSaturation.text = String(settings.blurSaturation === undefined ? 1.5 : settings.blurSaturation);
        alwaysCenterToggle.checked = settings.alwaysCenterSingle === true;
        emptyWorkspaceToggle.checked = settings.emptyWorkspaceAboveFirst === true;
        borderCard.checked = settings.borderEnabled !== false;
        borderActiveColor.text = settings.borderActiveColor || "#222222";
        borderInactiveColor.text = settings.borderInactiveColor || "#222222";
        borderUrgentColor.text = settings.borderUrgentColor || "#9b0000";
        borderGradientCard.checked = settings.borderGradientEnabled === true;
        borderActiveGradient.text = settings.borderActiveGradient || "from=\"#80c8ff\" to=\"#c7ff7f\" angle=45";
        borderInactiveGradient.text = settings.borderInactiveGradient || "from=\"#505050\" to=\"#808080\" angle=45";
        borderUrgentGradient.text = settings.borderUrgentGradient || "from=\"#800\" to=\"#a33\" angle=45";
        focusRingCard.checked = settings.focusRingEnabled === true;
        focusRingWidth.text = String(settings.focusRingWidth === undefined ? 4 : settings.focusRingWidth);
        focusRingActiveColor.text = settings.focusRingActiveColor || "#7fc8ff";
        focusRingInactiveColor.text = settings.focusRingInactiveColor || "#505050";
        focusRingUrgentColor.text = settings.focusRingUrgentColor || "#9b0000";
        focusGradientCard.checked = settings.focusRingGradientEnabled === true;
        focusActiveGradient.text = settings.focusRingActiveGradient || "from=\"#80c8ff\" to=\"#bbddff\" angle=45";
        focusInactiveGradient.text = settings.focusRingInactiveGradient || "from=\"#505050\" to=\"#808080\" angle=45";
        focusUrgentGradient.text = settings.focusRingUrgentGradient || "from=\"#800\" to=\"#a33\" angle=45";
        tabIndicatorCard.checked = settings.tabIndicatorEnabled === true;
        tabHideSingle.checked = settings.tabHideSingle !== false;
        tabPlaceWithin.checked = settings.tabPlaceWithinColumn !== false;
        tabGap.text = String(settings.tabGap === undefined ? 5 : settings.tabGap);
        tabWidth.text = String(settings.tabWidth === undefined ? 4 : settings.tabWidth);
        tabLength.text = String(settings.tabLength === undefined ? 1 : settings.tabLength);
        tabPosition.value = settings.tabPosition || "right";
        tabGapsBetween.text = String(settings.tabGapsBetween === undefined ? 2 : settings.tabGapsBetween);
        tabCornerRadius.text = String(settings.tabCornerRadius === undefined ? 8 : settings.tabCornerRadius);
        tabActiveColor.text = settings.tabActiveColor || "#7fc8ff";
        tabInactiveColor.text = settings.tabInactiveColor || "#505050";
        tabUrgentColor.text = settings.tabUrgentColor || "#9b0000";
        tabGradientCard.checked = settings.tabGradientEnabled === true;
        tabActiveGradient.text = settings.tabActiveGradient || "from=\"#80c8ff\" to=\"#bbddff\" angle=45";
        tabInactiveGradient.text = settings.tabInactiveGradient || "from=\"#505050\" to=\"#808080\" angle=45";
        tabUrgentGradient.text = settings.tabUrgentGradient || "from=\"#800\" to=\"#a33\" angle=45";
        insertHintCard.checked = settings.insertHintEnabled === true;
        insertHintColor.text = settings.insertHintColor || "#7fc8ff80";
        insertGradientCard.checked = settings.insertHintGradientEnabled === true;
        insertHintGradient.text = settings.insertHintGradient || "from=\"#ffbb6680\" to=\"#ffc88080\" angle=45";
        shadowSoftness.text = String(settings.shadowSoftness === undefined ? 20 : settings.shadowSoftness);
        shadowSpread.text = String(settings.shadowSpread === undefined ? 5 : settings.shadowSpread);
        shadowOffsetX.text = String(settings.shadowOffsetX === undefined ? 0 : settings.shadowOffsetX);
        shadowOffsetY.text = String(settings.shadowOffsetY === undefined ? 0 : settings.shadowOffsetY);
        shadowDrawBehind.checked = settings.shadowDrawBehind !== false;
        shadowColor.text = settings.shadowColor || "#000000";
        shadowInactiveColor.text = settings.shadowInactiveColor || "#00000054";
        recentWindowsCard.checked = settings.recentWindows === true;
        recentDebounce.text = String(settings.recentDebounceMs === undefined ? 750 : settings.recentDebounceMs);
        recentDelay.text = String(settings.recentOpenDelayMs === undefined ? 150 : settings.recentOpenDelayMs);
        recentHighlightActiveColor.text = settings.recentHighlightActiveColor || "#999999ff";
        recentHighlightUrgentColor.text = settings.recentHighlightUrgentColor || "#ff9999ff";
        recentHighlightPadding.text = String(settings.recentHighlightPadding === undefined ? 30 : settings.recentHighlightPadding);
        recentHighlightCornerRadius.text = String(settings.recentHighlightCornerRadius === undefined ? 0 : settings.recentHighlightCornerRadius);
        recentPreviewHeight.text = String(settings.recentPreviewHeight === undefined ? 480 : settings.recentPreviewHeight);
        recentPreviewScale.text = String(settings.recentPreviewScale === undefined ? 0.5 : settings.recentPreviewScale);
        recentBindValues = (settings.recentBinds || []).map(binding => {
            return Object.assign({}, binding);
        });
        layoutBaselineState = JSON.stringify(currentLayoutState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveLayout(currentLayoutState());
    }
    function updateRecentBind(index, propertyName, value) {
        var updated = recentBindValues.slice();
        updated[index] = Object.assign({}, updated[index]);
        updated[index][propertyName] = value;
        recentBindValues = updated;
    }

    clip: true
    contentHeight: layoutContent.implicitHeight + 26
    contentWidth: availableWidth

    ScrollBar.horizontal: SlimScrollBar {
        accentColor: Config.md3.secondary
        policy: ScrollBar.AlwaysOff
    }
    ScrollBar.vertical: SlimScrollBar {
        accentColor: Config.md3.secondary
    }

    Component.onCompleted: syncLayoutFields()

    Connections {
        function onLayoutSettingsChanged() {
            root.syncLayoutFields();
        }

        target: SettingsHubService
    }
    ColumnLayout {
        id: layoutContent

        spacing: 18
        width: root.contentWidth
        y: 12

        SettingsExpandableCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            iconName: "view-column-symbolic"
            note: "Column sizing and centering behavior"
            title: "Window geometry"
            toggleVisible: false

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: root.compactLayout ? 1 : 2
                rowSpacing: 12
                uniformCellWidths: true

                SettingsTextField {
                    id: gapsField

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    label: "Gaps"
                    placeholder: "10"

                    inputItem.validator: DoubleValidator {
                        bottom: 0
                        top: 64
                    }
                }
                SettingsTextField {
                    id: layoutBackgroundField

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    label: "Background color"
                    placeholder: "transparent"
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: root.compactLayout ? 1 : 2
                rowSpacing: 12
                uniformCellWidths: true

                SettingsChoiceRow {
                    id: defaultWidthMode

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    label: "Default width mode"
                    options: [
                        {
                            "label": "Auto",
                            "value": "auto"
                        },
                        {
                            "label": "Proportion",
                            "value": "proportion"
                        },
                        {
                            "label": "Fixed",
                            "value": "fixed"
                        }
                    ]
                }
                SettingsTextField {
                    id: defaultWidthField

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    label: defaultWidthMode.value === "fixed" ? "Default width (px)" : "Default width proportion"
                    placeholder: defaultWidthMode.value === "fixed" ? "1280" : "1.0"
                    visible: defaultWidthMode.value !== "auto"

                    inputItem.validator: DoubleValidator {
                        bottom: defaultWidthMode.value === "fixed" ? 1 : 0.01
                        decimals: defaultWidthMode.value === "fixed" ? 0 : 6
                        top: defaultWidthMode.value === "fixed" ? 16384 : 1
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: root.compactLayout ? 1 : 2
                rowSpacing: 12
                uniformCellWidths: true

                SettingsChoiceRow {
                    id: centerFocusedChoice

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    label: "Center focused column"
                    options: [
                        {
                            "label": "Never",
                            "value": "never"
                        },
                        {
                            "label": "Overflow",
                            "value": "on-overflow"
                        },
                        {
                            "label": "Always",
                            "value": "always"
                        }
                    ]
                }
                SettingsChoiceRow {
                    id: defaultDisplayChoice

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    label: "Default column display"
                    options: [
                        {
                            "label": "Normal",
                            "value": "normal"
                        },
                        {
                            "label": "Tabbed",
                            "value": "tabbed"
                        }
                    ]
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: 1
                rowSpacing: 12
                uniformCellWidths: true

                SettingsToggleRow {
                    id: alwaysCenterToggle

                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    label: "Center a single column"
                    note: "Keep one visible column centered"

                    onToggled: checked => {
                        return alwaysCenterToggle.checked = checked;
                    }
                }
                SettingsToggleRow {
                    id: emptyWorkspaceToggle

                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    label: "Empty workspace above first"
                    note: "Allow an empty workspace before workspace one"

                    onToggled: checked => {
                        return emptyWorkspaceToggle.checked = checked;
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: root.compactLayout ? 1 : 2
                rowSpacing: 12
                uniformCellWidths: true

                SettingsExpandableCard {
                    id: presetWidthsCard

                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    accentColor: Config.md3.primary
                    iconName: "view-column-symbolic"
                    note: "Widths used by Niri's preset-column-width action"
                    title: "Preset column widths"

                    onToggled: checked => {
                        return presetWidthsCard.checked = checked;
                    }

                    SettingsTextField {
                        id: presetWidthsField

                        Layout.fillWidth: true
                        label: "Entries"
                        placeholder: "proportion 0.5, fixed 1280"
                    }
                }
                SettingsExpandableCard {
                    id: presetHeightsCard

                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    accentColor: Config.md3.secondary
                    iconName: "view-list-symbolic"
                    note: "Heights used by Niri's preset-window-height action"
                    title: "Preset window heights"

                    onToggled: checked => {
                        return presetHeightsCard.checked = checked;
                    }

                    SettingsTextField {
                        id: presetHeightsField

                        Layout.fillWidth: true
                        label: "Entries"
                        placeholder: "proportion 0.5, fixed 720"
                    }
                }
            }
            SettingsExpandableCard {
                id: strutsCard

                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "preferences-system-windows-symbolic"
                note: "Reserve space around the working area"
                title: "Struts"

                onToggled: checked => {
                    return strutsCard.checked = checked;
                }

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: root.compactLayout ? 2 : 4
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: strutLeft

                        Layout.fillWidth: true
                        label: "Left"
                    }
                    SettingsTextField {
                        id: strutRight

                        Layout.fillWidth: true
                        label: "Right"
                    }
                    SettingsTextField {
                        id: strutTop

                        Layout.fillWidth: true
                        label: "Top"
                    }
                    SettingsTextField {
                        id: strutBottom

                        Layout.fillWidth: true
                        label: "Bottom"
                    }
                }
            }
        }
        SettingsExpandableCard {
            Layout.fillWidth: true
            accentColor: Config.md3.error
            iconName: "view-grid-symbolic"
            note: "Zoom, backdrop and workspace preview shadow"
            title: "Overview"
            toggleVisible: false

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: root.compactLayout ? 1 : 2
                rowSpacing: 12
                uniformCellWidths: true

                SettingsTextField {
                    id: overviewZoomField

                    Layout.fillWidth: true
                    label: "Zoom"
                    placeholder: "0.4"

                    inputItem.validator: DoubleValidator {
                        bottom: 0.1
                        top: 1
                    }
                }
                SettingsTextField {
                    id: overviewBackdropField

                    Layout.fillWidth: true
                    label: "Backdrop color"
                    placeholder: "#0a0a0a"
                }
            }
            SettingsExpandableCard {
                id: workspaceShadowCard

                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "preferences-desktop-effects-symbolic"
                note: "Shadow behind each workspace preview"
                title: "Workspace shadow"

                onToggled: checked => {
                    return workspaceShadowCard.checked = checked;
                }

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: root.compactLayout ? 2 : 5
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: workspaceShadowSoftness

                        Layout.fillWidth: true
                        fieldHeight: 36
                        label: "Softness"
                    }
                    SettingsTextField {
                        id: workspaceShadowSpread

                        Layout.fillWidth: true
                        fieldHeight: 36
                        label: "Spread"
                    }
                    SettingsTextField {
                        id: workspaceShadowOffsetX

                        Layout.fillWidth: true
                        fieldHeight: 36
                        label: "Offset X"
                    }
                    SettingsTextField {
                        id: workspaceShadowOffsetY

                        Layout.fillWidth: true
                        fieldHeight: 36
                        label: "Offset Y"
                    }
                    SettingsTextField {
                        id: workspaceShadowColor

                        Layout.fillWidth: true
                        fieldHeight: 36
                        label: "Color"
                    }
                }
            }
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: root.compactLayout ? tabIndicatorCard.y + tabIndicatorCard.height : Math.max(blurCard.y + blurCard.height, tabIndicatorCard.y + tabIndicatorCard.height)

            SettingsExpandableCard {
                id: borderCard

                accentColor: Config.md3.primary
                anchors.left: parent.left
                anchors.top: parent.top
                iconName: "focus-windows-symbolic"
                note: "Draw a configurable border around windows"
                title: "Window border"
                width: root.compactLayout ? parent.width : (parent.width - 16) / 2

                onToggled: checked => {
                    return borderCard.checked = checked;
                }

                SettingsTextField {
                    id: borderField

                    Layout.fillWidth: true
                    label: "Width"
                    placeholder: "12"

                    inputItem.validator: DoubleValidator {
                        bottom: 0
                        top: 64
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: root.compactLayout ? 2 : 3
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: borderActiveColor

                        Layout.fillWidth: true
                        label: "Active"
                    }
                    SettingsTextField {
                        id: borderInactiveColor

                        Layout.fillWidth: true
                        label: "Inactive"
                    }
                    SettingsTextField {
                        id: borderUrgentColor

                        Layout.fillWidth: true
                        label: "Urgent"
                    }
                }
                SettingsExpandableCard {
                    id: borderGradientCard

                    Layout.fillWidth: true
                    accentColor: Config.md3.primary
                    iconName: "color-select-symbolic"
                    note: "Gradient overrides the solid colors above"
                    title: "Gradient colors"

                    onToggled: checked => {
                        return borderGradientCard.checked = checked;
                    }

                    SettingsTextField {
                        id: borderActiveGradient

                        Layout.fillWidth: true
                        label: "Active gradient"
                    }
                    SettingsTextField {
                        id: borderInactiveGradient

                        Layout.fillWidth: true
                        label: "Inactive gradient"
                    }
                    SettingsTextField {
                        id: borderUrgentGradient

                        Layout.fillWidth: true
                        label: "Urgent gradient"
                    }
                }
            }
            SettingsExpandableCard {
                id: focusRingCard

                accentColor: Config.md3.secondary
                anchors.left: root.compactLayout ? parent.left : undefined
                anchors.right: root.compactLayout ? undefined : parent.right
                anchors.top: root.compactLayout ? borderCard.bottom : parent.top
                anchors.topMargin: root.compactLayout ? 16 : 0
                iconName: "focus-windows-symbolic"
                note: "Highlight the currently focused window"
                title: "Focus ring"
                width: root.compactLayout ? parent.width : (parent.width - 16) / 2

                onToggled: checked => {
                    return focusRingCard.checked = checked;
                }

                SettingsTextField {
                    id: focusRingWidth

                    Layout.fillWidth: true
                    label: "Width"

                    inputItem.validator: DoubleValidator {
                        bottom: 0
                        top: 64
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: root.compactLayout ? 2 : 3
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: focusRingActiveColor

                        Layout.fillWidth: true
                        label: "Active"
                    }
                    SettingsTextField {
                        id: focusRingInactiveColor

                        Layout.fillWidth: true
                        label: "Inactive"
                    }
                    SettingsTextField {
                        id: focusRingUrgentColor

                        Layout.fillWidth: true
                        label: "Urgent"
                    }
                }
                SettingsExpandableCard {
                    id: focusGradientCard

                    Layout.fillWidth: true
                    accentColor: Config.md3.secondary
                    iconName: "color-select-symbolic"
                    note: "Gradient overrides the solid colors above"
                    title: "Gradient colors"

                    onToggled: checked => {
                        return focusGradientCard.checked = checked;
                    }

                    SettingsTextField {
                        id: focusActiveGradient

                        Layout.fillWidth: true
                        label: "Active gradient"
                    }
                    SettingsTextField {
                        id: focusInactiveGradient

                        Layout.fillWidth: true
                        label: "Inactive gradient"
                    }
                    SettingsTextField {
                        id: focusUrgentGradient

                        Layout.fillWidth: true
                        label: "Urgent gradient"
                    }
                }
            }
            SettingsExpandableCard {
                id: insertHintCard

                accentColor: Config.md3.tertiary
                anchors.left: parent.left
                anchors.top: root.compactLayout ? focusRingCard.bottom : borderCard.bottom
                anchors.topMargin: 16
                iconName: "insert-object-symbolic"
                note: "Show where a dragged window will be inserted"
                title: "Drag insert hint"
                width: root.compactLayout ? parent.width : (parent.width - 16) / 2

                onToggled: checked => {
                    return insertHintCard.checked = checked;
                }

                SettingsTextField {
                    id: insertHintColor

                    Layout.fillWidth: true
                    label: "Hint color"
                    placeholder: "#7fc8ff80"
                }
                SettingsExpandableCard {
                    id: insertGradientCard

                    Layout.fillWidth: true
                    accentColor: Config.md3.tertiary
                    iconName: "color-select-symbolic"
                    note: "Gradient overrides the solid hint color"
                    title: "Gradient"

                    onToggled: checked => {
                        return insertGradientCard.checked = checked;
                    }

                    SettingsTextField {
                        id: insertHintGradient

                        Layout.fillWidth: true
                        label: "Gradient specification"
                    }
                }
            }
            SettingsExpandableCard {
                id: blurCard

                accentColor: Config.md3.primary
                anchors.left: parent.left
                anchors.top: insertHintCard.bottom
                anchors.topMargin: 16
                iconName: "weather-fog-symbolic"
                note: "GPU blur quality and performance controls"
                title: "Experimental blur"
                width: root.compactLayout ? parent.width : (parent.width - 16) / 2

                onToggled: checked => {
                    return blurCard.checked = checked;
                }

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: root.compactLayout ? 2 : 4
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: blurPasses

                        Layout.fillWidth: true
                        label: "Passes"

                        inputItem.validator: IntValidator {
                            bottom: 1
                            top: 8
                        }
                    }
                    SettingsTextField {
                        id: blurOffset

                        Layout.fillWidth: true
                        label: "Offset"

                        inputItem.validator: DoubleValidator {
                            bottom: 0.1
                            top: 10
                        }
                    }
                    SettingsTextField {
                        id: blurNoise

                        Layout.fillWidth: true
                        label: "Noise"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: blurSaturation

                        Layout.fillWidth: true
                        label: "Saturation"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            top: 5
                        }
                    }
                }
            }
            SettingsExpandableCard {
                id: shadowCard

                accentColor: Config.md3.tertiary
                anchors.left: root.compactLayout ? parent.left : undefined
                anchors.right: root.compactLayout ? undefined : parent.right
                anchors.top: root.compactLayout ? blurCard.bottom : focusRingCard.bottom
                anchors.topMargin: 16
                iconName: "preferences-desktop-effects-symbolic"
                note: "Draw a configurable shadow behind windows"
                title: "Window shadow"
                width: root.compactLayout ? parent.width : (parent.width - 16) / 2

                onToggled: checked => {
                    return shadowCard.checked = checked;
                }

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: 2
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: shadowSoftness

                        Layout.fillWidth: true
                        label: "Softness"
                    }
                    SettingsTextField {
                        id: shadowSpread

                        Layout.fillWidth: true
                        label: "Spread"
                    }
                    SettingsTextField {
                        id: shadowOffsetX

                        Layout.fillWidth: true
                        label: "Offset X"
                    }
                    SettingsTextField {
                        id: shadowOffsetY

                        Layout.fillWidth: true
                        label: "Offset Y"
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: 2
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: shadowColor

                        Layout.fillWidth: true
                        label: "Color"
                    }
                    SettingsTextField {
                        id: shadowInactiveColor

                        Layout.fillWidth: true
                        label: "Inactive"
                    }
                }
                SettingsToggleRow {
                    id: shadowDrawBehind

                    label: "Draw behind window"
                    note: "Keep the shadow behind the complete window"

                    onToggled: checked => {
                        return shadowDrawBehind.checked = checked;
                    }
                }
            }
            SettingsExpandableCard {
                id: tabIndicatorCard

                accentColor: Config.md3.primary
                anchors.left: root.compactLayout ? parent.left : undefined
                anchors.right: root.compactLayout ? undefined : parent.right
                anchors.top: shadowCard.bottom
                anchors.topMargin: 16
                iconName: "view-list-symbolic"
                note: "Marker for tabs in a tabbed column"
                title: "Tabbed column indicator"
                width: root.compactLayout ? parent.width : (parent.width - 16) / 2

                onToggled: checked => {
                    return tabIndicatorCard.checked = checked;
                }

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: 2
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: tabGap

                        Layout.fillWidth: true
                        label: "Outer gap"
                    }
                    SettingsTextField {
                        id: tabWidth

                        Layout.fillWidth: true
                        label: "Width"
                    }
                    SettingsTextField {
                        id: tabGapsBetween

                        Layout.fillWidth: true
                        label: "Gap between tabs"
                    }
                    SettingsTextField {
                        id: tabCornerRadius

                        Layout.fillWidth: true
                        label: "Corner radius"
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: 2
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: tabLength

                        Layout.fillWidth: true
                        label: "Total length"

                        inputItem.validator: DoubleValidator {
                            bottom: 0.05
                            top: 1
                        }
                    }
                    SettingsChoiceRow {
                        id: tabPosition

                        Layout.fillWidth: true
                        label: "Position"
                        options: [
                            {
                                "label": "Left",
                                "value": "left"
                            },
                            {
                                "label": "Right",
                                "value": "right"
                            },
                            {
                                "label": "Top",
                                "value": "top"
                            },
                            {
                                "label": "Bottom",
                                "value": "bottom"
                            }
                        ]
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: root.compactLayout ? 2 : 3
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: tabActiveColor

                        Layout.fillWidth: true
                        label: "Active"
                    }
                    SettingsTextField {
                        id: tabInactiveColor

                        Layout.fillWidth: true
                        label: "Inactive"
                    }
                    SettingsTextField {
                        id: tabUrgentColor

                        Layout.fillWidth: true
                        label: "Urgent"
                    }
                }
                SettingsExpandableCard {
                    id: tabGradientCard

                    Layout.fillWidth: true
                    accentColor: Config.md3.primary
                    iconName: "color-select-symbolic"
                    note: "Gradient overrides the solid colors above"
                    title: "Gradient colors"

                    onToggled: checked => {
                        return tabGradientCard.checked = checked;
                    }

                    SettingsTextField {
                        id: tabActiveGradient

                        Layout.fillWidth: true
                        label: "Active gradient"
                    }
                    SettingsTextField {
                        id: tabInactiveGradient

                        Layout.fillWidth: true
                        label: "Inactive gradient"
                    }
                    SettingsTextField {
                        id: tabUrgentGradient

                        Layout.fillWidth: true
                        label: "Urgent gradient"
                    }
                }
                SettingsToggleRow {
                    id: tabHideSingle

                    label: "Hide with one tab"
                    note: "Do not draw the indicator for a single tab"

                    onToggled: checked => {
                        return tabHideSingle.checked = checked;
                    }
                }
                SettingsToggleRow {
                    id: tabPlaceWithin

                    label: "Place inside column"
                    note: "Keep the indicator within the column bounds"

                    onToggled: checked => {
                        return tabPlaceWithin.checked = checked;
                    }
                }
            }
        }
        SettingsExpandableCard {
            id: recentWindowsCard

            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            detailsSpacing: 16
            iconName: "view-restore-symbolic"
            note: "Timing, highlight, previews and four switcher shortcuts"
            title: "Recent windows"

            onToggled: checked => {
                return recentWindowsCard.checked = checked;
            }

            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                iconName: "preferences-system-time-symbolic"
                note: "Controls how quickly the switcher opens and reacts"
                title: "Timing"

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 16
                    columns: root.compactLayout ? 1 : 2
                    rowSpacing: 12
                    uniformCellWidths: true

                    SettingsTextField {
                        id: recentDebounce

                        Layout.fillWidth: true
                        label: "Debounce (ms)"

                        inputItem.validator: IntValidator {
                            bottom: 0
                            top: 5000
                        }
                    }
                    SettingsTextField {
                        id: recentDelay

                        Layout.fillWidth: true
                        label: "Open delay (ms)"

                        inputItem.validator: IntValidator {
                            bottom: 0
                            top: 5000
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                iconName: "color-select-symbolic"
                note: "Appearance of the currently selected preview"
                title: "Highlight"

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 16
                    columns: root.compactLayout ? 2 : 4
                    rowSpacing: 12
                    uniformCellWidths: true

                    SettingsTextField {
                        id: recentHighlightActiveColor

                        Layout.fillWidth: true
                        label: "Active color"
                        placeholder: "#999999ff"
                    }
                    SettingsTextField {
                        id: recentHighlightUrgentColor

                        Layout.fillWidth: true
                        label: "Urgent color"
                        placeholder: "#ff9999ff"
                    }
                    SettingsTextField {
                        id: recentHighlightPadding

                        Layout.fillWidth: true
                        label: "Padding"

                        inputItem.validator: IntValidator {
                            bottom: 0
                            top: 256
                        }
                    }
                    SettingsTextField {
                        id: recentHighlightCornerRadius

                        Layout.fillWidth: true
                        label: "Corner radius"

                        inputItem.validator: IntValidator {
                            bottom: 0
                            top: 256
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "video-display-symbolic"
                note: "Limits preview size to keep the switcher responsive"
                title: "Previews"

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 16
                    columns: root.compactLayout ? 1 : 2
                    rowSpacing: 12
                    uniformCellWidths: true

                    SettingsTextField {
                        id: recentPreviewHeight

                        Layout.fillWidth: true
                        label: "Maximum height"

                        inputItem.validator: IntValidator {
                            bottom: 64
                            top: 2160
                        }
                    }
                    SettingsTextField {
                        id: recentPreviewScale

                        Layout.fillWidth: true
                        label: "Maximum scale"

                        inputItem.validator: DoubleValidator {
                            bottom: 0.05
                            top: 1
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.error
                iconName: "preferences-desktop-keyboard-shortcuts-symbolic"
                note: "Click a shortcut and press a new combination; save it with Apply layout"
                title: "Shortcuts"

                Repeater {
                    model: root.recentBindValues

                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        readonly property bool previous: modelData.direction === "previous-window"
                        readonly property bool sameApp: modelData.filter === "app-id"

                        Layout.fillWidth: true
                        border.color: Config.alpha(Config.md3.on_surface, 0.055)
                        border.width: 1
                        color: Config.alpha(Config.md3.on_surface, 0.04)
                        implicitHeight: recentBindRow.implicitHeight + 24
                        radius: 12

                        RowLayout {
                            id: recentBindRow

                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 16

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    text: (sameApp ? "Same application · " : "All applications · ") + (previous ? "Previous window" : "Next window")
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.alpha(Config.md3.on_surface, 0.45)
                                    font.family: Config.fontName
                                    font.pixelSize: 11
                                    text: sameApp ? "Matches the app ID of the initially focused window" : "Uses Niri's remembered initial window set"
                                }
                            }
                            EditableKeybindPill {
                                id: recentBindKey

                                Layout.alignment: Qt.AlignVCenter
                                displayKey: recentBindKey.displayFromRaw(modelData.key)
                                interactive: !SettingsHubService.busy
                                oldHeader: modelData.key

                                onCommitted: (_oldKey, newKey) => {
                                    root.updateRecentBind(index, "key", newKey);
                                }
                            }
                        }
                    }
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
            }
        }
    }
}
