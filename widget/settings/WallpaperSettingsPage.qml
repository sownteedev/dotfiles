import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string baselineState: ""
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState

    function currentState() {
        return {
            "wallFolderPath": wallFolderField.text,
            "liveWallFolderPath": liveWallFolderField.text,
            "wallpaperBatteryFps": Number(batteryFpsField.text),
            "wallpaperEngineFps": Number(engineFpsField.text),
            "wallpaperPauseOnFullscreen": pauseFullscreenToggle.checked,
            "wallpaperPauseOnLock": pauseLockToggle.checked,
            "wallpaperScalingMode": wallpaperScalingChoice.value,
            "wallpaperTransitionDuration": Number(wallpaperTransitionField.text),
            "matugenEnabled": matugenToggle.checked,
            "matugenAnimateColors": matugenAnimationToggle.checked,
            "matugenTransitionDuration": Number(matugenTransitionField.text)
        };
    }
    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        wallFolderField.text = settings.wallFolderPath || Config.wallFolderPath;
        liveWallFolderField.text = settings.liveWallFolderPath || Config.liveWallFolderPath;
        batteryFpsField.text = String(settings.wallpaperBatteryFps ?? Config.wallpaperBatteryFps);
        engineFpsField.text = String(settings.wallpaperEngineFps ?? Config.wallpaperEngineFps);
        pauseFullscreenToggle.checked = settings.wallpaperPauseOnFullscreen ?? Config.wallpaperPauseOnFullscreen;
        pauseLockToggle.checked = settings.wallpaperPauseOnLock ?? Config.wallpaperPauseOnLock;
        wallpaperScalingChoice.value = settings.wallpaperScalingMode || Config.wallpaperScalingMode;
        wallpaperTransitionField.text = String(settings.wallpaperTransitionDuration ?? Config.wallpaperTransitionDuration);
        matugenToggle.checked = settings.matugenEnabled ?? Config.matugenEnabled;
        matugenAnimationToggle.checked = settings.matugenAnimateColors ?? Config.matugenAnimateColors;
        matugenTransitionField.text = String(settings.matugenTransitionDuration ?? Config.matugenTransitionDuration);
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: {
        syncFields();
    }

    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    ScrollView {
        id: scroll

        anchors.fill: parent
        contentHeight: content.implicitHeight
        contentWidth: availableWidth

        ScrollBar.horizontal: SlimScrollBar {
            accentColor: Config.md3.tertiary
        }
        ScrollBar.vertical: SlimScrollBar {
            accentColor: Config.md3.tertiary
        }

        GridLayout {
            id: content

            columnSpacing: 12
            columns: 1
            rowSpacing: 12
            uniformCellWidths: true
            width: scroll.availableWidth
            x: (scroll.availableWidth - width) / 2

            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "preferences-desktop-wallpaper-symbolic"
                note: "Folders scanned by the static and live wallpaper selectors"
                title: "Wallpaper library"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SettingsTextField {
                        id: wallFolderField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: "Image folder"
                        placeholder: "~/Dotfiles/dotf/.walls"

                        onActionClicked: {
                            SettingsHubService.filePickerDialog.open(wallFolderField, "file://" + Config.expandHomePath("~"), true);
                        }
                    }
                    SettingsTextField {
                        id: liveWallFolderField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: "Video folder"
                        placeholder: "~/Dotfiles/dotf/.walls/live"

                        onActionClicked: {
                            SettingsHubService.filePickerDialog.open(liveWallFolderField, "file://" + Config.expandHomePath("~"), true);
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "media-playback-start-symbolic"
                note: "Playback policy and transition timing"
                title: "Playback"

                SettingsChoiceRow {
                    id: wallpaperScalingChoice

                    Layout.fillWidth: true
                    label: qsTr("Scaling mode")
                    note: qsTr("Choose whether wallpapers crop, preserve their full aspect ratio, or stretch to the screen")
                    options: [
                        {
                            "label": qsTr("Fill"),
                            "value": "fill"
                        },
                        {
                            "label": qsTr("Fit"),
                            "value": "fit"
                        },
                        {
                            "label": qsTr("Stretch"),
                            "value": "stretch"
                        }
                    ]
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SettingsTextField {
                        id: batteryFpsField

                        Layout.fillWidth: true
                        label: "Engine battery FPS"
                        placeholder: "20"

                        inputItem.validator: IntValidator {
                            bottom: 5
                            top: 60
                        }
                    }
                    SettingsTextField {
                        id: engineFpsField

                        Layout.fillWidth: true
                        label: "Engine FPS"
                        placeholder: "30"

                        inputItem.validator: IntValidator {
                            bottom: 5
                            top: 165
                        }
                    }
                    SettingsTextField {
                        id: wallpaperTransitionField

                        Layout.fillWidth: true
                        label: "Transition (ms)"
                        placeholder: "360"

                        inputItem.validator: IntValidator {
                            bottom: 0
                            top: 2000
                        }
                    }
                }
                SettingsToggleRow {
                    id: pauseFullscreenToggle

                    label: "Pause while fullscreen"
                    note: "Stops live wallpaper decoding behind a fullscreen window"

                    onToggled: value => {
                        return checked = value;
                    }
                }
                SettingsToggleRow {
                    id: pauseLockToggle

                    label: "Pause while locked"
                    note: "Resumes automatically after the lock screen closes"

                    onToggled: value => {
                        return checked = value;
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "color-select-symbolic"
                note: "Generate the shell and application palette from the selected wallpaper"
                title: "Matugen"

                SettingsToggleRow {
                    id: matugenToggle

                    label: "Generate dynamic colors"
                    note: "Disabling this keeps the current palette when wallpaper changes"

                    onToggled: value => {
                        return checked = value;
                    }
                }
                SettingsToggleRow {
                    id: matugenAnimationToggle

                    enabled: matugenToggle.checked
                    label: "Animate shell colors"
                    note: "Blend between the old and new palette"
                    opacity: enabled ? 1 : 0.45

                    onToggled: value => {
                        return checked = value;
                    }
                }
                SettingsTextField {
                    id: matugenTransitionField

                    Layout.fillWidth: true
                    editable: matugenToggle.checked && matugenAnimationToggle.checked
                    label: "Color transition (ms)"
                    opacity: editable ? 1 : 0.45
                    placeholder: "300"

                    inputItem.validator: IntValidator {
                        bottom: 0
                        top: 2000
                    }
                }
            }
        }
    }
}
