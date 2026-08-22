import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string baselineState: ""
    property string confirmCacheScope: ""
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState

    function currentState() {
        return {
            "shellReducedMotion": reducedMotionToggle.checked,
            "shellAnimationScale": Number(animationScaleField.text),
            "shellLowPowerMode": lowPowerToggle.checked,
            "cavaEnabled": cavaToggle.checked,
            "osdEnabled": osdToggle.checked,
            "osdDuration": Number(osdDurationField.text),
            "osdPosition": osdPositionChoice.value,
            "osdShowVolume": volumeOsdToggle.checked,
            "osdShowMicrophone": microphoneOsdToggle.checked,
            "osdShowBrightness": brightnessOsdToggle.checked,
            "audioMaxVolume": Number(maxVolumeField.text) / 100
        };
    }
    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        reducedMotionToggle.checked = settings.shellReducedMotion ?? Config.shellReducedMotion;
        animationScaleField.text = String(settings.shellAnimationScale ?? Config.shellAnimationScale);
        lowPowerToggle.checked = settings.shellLowPowerMode ?? Config.shellLowPowerMode;
        cavaToggle.checked = settings.cavaEnabled ?? Config.cavaEnabled;
        osdToggle.checked = settings.osdEnabled ?? Config.osdEnabled;
        osdDurationField.text = String(settings.osdDuration ?? Config.osdDuration);
        osdPositionChoice.value = settings.osdPosition || Config.osdPosition;
        volumeOsdToggle.checked = settings.osdShowVolume ?? Config.osdShowVolume;
        microphoneOsdToggle.checked = settings.osdShowMicrophone ?? Config.osdShowMicrophone;
        brightnessOsdToggle.checked = settings.osdShowBrightness ?? Config.osdShowBrightness;
        maxVolumeField.text = String(Math.round(Number(settings.audioMaxVolume ?? Config.audioMaxVolume) * 100));
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: {
        syncFields();
        DiagnosticsService.refresh();
    }

    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    SettingsPageContent {
        id: pageContent

        anchors.fill: parent

        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            note: "Reduce rendering work without changing the visual hierarchy"
            title: "Motion and performance"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: 1
                rowSpacing: 10
                uniformCellWidths: true

                SettingsTextField {
                    id: animationScaleField

                    Layout.fillWidth: true
                    label: "Animation scale"
                    placeholder: "1.0"

                    inputItem.validator: DoubleValidator {
                        bottom: 0
                        decimals: 2
                        top: 2
                    }
                }
                SettingsToggleTile {
                    id: reducedMotionToggle

                    label: "Reduce motion"
                    note: "Prefer short fades over large movement"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: lowPowerToggle

                    label: "Low-power rendering"
                    note: "Reduce decorative rendering work"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: cavaToggle

                    label: "Audio spectrum"
                    note: "Cava visualization in media surfaces"

                    onToggled: value => checked = value
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.primary
            compact: true
            note: "On-screen feedback for hardware controls"
            title: "OSD and audio"

            SettingsToggleTile {
                id: osdToggle

                label: "Enable OSD"
                note: "Show feedback for volume, microphone and brightness"

                onToggled: value => checked = value
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: width >= 860 ? 3 : width >= 500 ? 2 : 1
                enabled: osdToggle.checked
                opacity: enabled ? 1 : 0.45
                rowSpacing: 12
                uniformCellWidths: true

                SettingsTextField {
                    id: osdDurationField

                    Layout.fillWidth: true
                    label: "Duration (ms)"
                    placeholder: "2000"

                    inputItem.validator: IntValidator {
                        bottom: 500
                        top: 10000
                    }
                }
                SettingsTextField {
                    id: maxVolumeField

                    Layout.fillWidth: true
                    label: "Maximum volume (%)"
                    placeholder: "100"

                    inputItem.validator: IntValidator {
                        bottom: 50
                        top: 150
                    }
                }
                SettingsChoiceRow {
                    id: osdPositionChoice

                    Layout.fillWidth: true
                    label: "Position"
                    options: [
                        {
                            "label": "Bottom",
                            "value": "bottom"
                        },
                        {
                            "label": "Top",
                            "value": "top"
                        }
                    ]

                    onSelected: value => osdPositionChoice.value = value
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: 1
                enabled: osdToggle.checked
                opacity: enabled ? 1 : 0.45
                rowSpacing: 10
                uniformCellWidths: true

                SettingsToggleTile {
                    id: volumeOsdToggle

                    label: "Volume"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: microphoneOsdToggle

                    label: "Microphone"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: brightnessOsdToggle

                    label: "Brightness"

                    onToggled: value => checked = value
                }
            }
        }
        SettingsSectionCard {
            Layout.columnSpan: pageContent.columnCount
            Layout.fillWidth: true
            accentColor: Config.md3.tertiary
            compact: true
            note: DiagnosticsService.busy ? "Checking the local system…" : "Required tools should be available; optional tools only affect their matching feature"
            title: "Dependencies"

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: DiagnosticsService.dependencies

                    delegate: Rectangle {
                        id: dependencyBadge

                        required property var modelData

                        border.color: Config.alpha(modelData.available ? Config.md3.secondary : modelData.required ? Config.md3.error : Config.md3.tertiary, 0.3)
                        border.width: 1
                        color: Config.alpha(modelData.available ? Config.md3.secondary : modelData.required ? Config.md3.error : Config.md3.tertiary, 0.1)
                        height: 34
                        radius: 11
                        width: dependencyText.implicitWidth + 24

                        Text {
                            id: dependencyText

                            anchors.centerIn: parent
                            color: dependencyBadge.modelData.available ? Config.md3.secondary : dependencyBadge.modelData.required ? Config.md3.error : Config.md3.tertiary
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: (dependencyBadge.modelData.available ? "✓ " : "! ") + dependencyBadge.modelData.name
                        }
                    }
                }
            }
            SettingsActionButton {
                enabled: !DiagnosticsService.busy
                iconName: "view-refresh-symbolic"
                iconOnly: true
                text: DiagnosticsService.busy ? "Checking…" : "Refresh"

                onClicked: DiagnosticsService.refresh()
            }
        }
        SettingsSectionCard {
            Layout.columnSpan: pageContent.columnCount
            Layout.fillWidth: true
            accentColor: Config.md3.error
            compact: true
            note: "Only generated previews and backdrops are removed; downloaded wallpapers stay installed"
            title: "Cache"

            Repeater {
                model: DiagnosticsService.caches

                delegate: Rectangle {
                    id: cacheRow

                    required property var modelData

                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.04)
                    implicitHeight: 58
                    radius: 13

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 8
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                text: cacheRow.modelData.label || cacheRow.modelData.scope
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.alpha(Config.md3.on_surface, 0.44)
                                elide: Text.ElideMiddle
                                font.family: Config.fontName
                                font.pixelSize: 11
                                text: DiagnosticsService.formatBytes(cacheRow.modelData.bytes) + "  ·  " + cacheRow.modelData.path
                            }
                        }
                        SettingsActionButton {
                            enabled: !DiagnosticsService.busy
                            iconName: root.confirmCacheScope === cacheRow.modelData.scope ? "dialog-warning-symbolic" : "user-trash-symbolic"
                            iconOnly: root.confirmCacheScope !== cacheRow.modelData.scope
                            text: root.confirmCacheScope === cacheRow.modelData.scope ? "Confirm clear" : "Clear"

                            onClicked: {
                                if (root.confirmCacheScope !== cacheRow.modelData.scope) {
                                    root.confirmCacheScope = cacheRow.modelData.scope;
                                    return;
                                }
                                root.confirmCacheScope = "";
                                DiagnosticsService.clearCache(cacheRow.modelData.scope);
                            }
                        }
                    }
                }
            }
        }
    }
}
