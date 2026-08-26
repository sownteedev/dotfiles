import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property int activeSection: 0
    property string baselineState: ""
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState
    property QtObject profileImageField: QtObject {
        property string text: ""
    }
    property bool revealApiKey: false
    property bool revealGoogleToken: false
    property bool revealSteamApiKey: false
    property bool revealWallhavenApiKey: false

    function currentState() {
        var settings = SettingsHubService.quickshellSettings || ({});
        return {
            "fontName": fontField.text,
            "profileImagePath": profileImageField.text,
            "shellBlurBarEnabled": barBlurToggle.checked,
            "shellBlurBarOpacityDark": barOpacityDarkField.text === "" ? Config.shellBlurBarOpacityDark : Number(barOpacityDarkField.text),
            "shellBlurBarOpacityLight": barOpacityLightField.text === "" ? Config.shellBlurBarOpacityLight : Number(barOpacityLightField.text),
            "shellBlurControlLeftEnabled": controlLeftBlurToggle.checked,
            "shellBlurControlRightEnabled": controlRightBlurToggle.checked,
            "shellBlurDockEnabled": dockBlurToggle.checked,
            "shellBlurLauncherEnabled": launcherBlurToggle.checked,
            "shellBlurNotificationEnabled": notificationBlurToggle.checked,
            "shellBlurOsdEnabled": osdBlurToggle.checked,
            "shellBlurPanelOpacityDark": panelOpacityDarkField.text === "" ? Config.shellBlurPanelOpacityDark : Number(panelOpacityDarkField.text),
            "shellBlurPanelOpacityLight": panelOpacityLightField.text === "" ? Config.shellBlurPanelOpacityLight : Number(panelOpacityLightField.text),
            "shellBlurSettingsEnabled": settingsBlurToggle.checked,
            "shellComponentShadowBlur": componentShadowBlurField.text === "" ? Config.shellComponentShadowBlur : Number(componentShadowBlurField.text),
            "shellComponentShadowEnabled": componentShadowEnabledToggle.checked,
            "shellComponentShadowOffsetX": componentShadowOffsetXField.text === "" ? Config.shellComponentShadowOffsetX : Number(componentShadowOffsetXField.text),
            "shellComponentShadowOffsetY": componentShadowOffsetYField.text === "" ? Config.shellComponentShadowOffsetY : Number(componentShadowOffsetYField.text),
            "shellComponentShadowOpacity": componentShadowOpacityField.text === "" ? Config.shellComponentShadowOpacity : Number(componentShadowOpacityField.text),
            "shellComponentShadowSpread": componentShadowSpreadField.text === "" ? Config.shellComponentShadowSpread : Number(componentShadowSpreadField.text),
            "shellShadowBlur": Number(shadowBlurField.text),
            "shellShadowEnabled": shadowEnabledToggle.checked,
            "shellShadowOffsetX": Number(shadowOffsetXField.text),
            "shellShadowOffsetY": Number(shadowOffsetYField.text),
            "shellShadowOpacity": Number(shadowOpacityField.text),
            "shellShadowSpread": Number(shadowSpreadField.text),
            "clock24h": clockToggle.checked,
            "latLon": locationField.text,
            "apiWeather": apiField.text,
            "steamUsername": steamUsernameField.text,
            "steamWebApiKey": steamApiKeyField.text,
            "wallhavenUsername": wallhavenUsernameField.text,
            "wallhavenApiKey": wallhavenApiKeyField.text,
            "wallhavenShowNsfw": Config.wallhavenShowNsfw,
            "wallpaperWorkshopShowNsfw": Config.wallpaperWorkshopShowNsfw,
            "wallFolderPath": wallFolderField.text,
            "liveWallFolderPath": liveWallFolderField.text,
            "wallpaperBatteryFps": Number(batteryFpsField.text),
            "wallpaperEngineFps": Number(engineFpsField.text),
            "wallpaperPauseOnFullscreen": pauseFullscreenToggle.checked,
            "wallpaperPauseOnLock": pauseLockToggle.checked,
            "wallpaperTransitionDuration": Number(wallpaperTransitionField.text),
            "matugenEnabled": matugenToggle.checked,
            "matugenAnimateColors": matugenAnimationToggle.checked,
            "matugenTransitionDuration": Number(matugenTransitionField.text),
            "captureScreenshotDirPath": screenshotDirField.text,
            "captureRecordingDirPath": recordingDirField.text,
            "captureAutoCopyScreenshot": copyScreenshotToggle.checked,
            "captureAutoCopyRecording": copyRecordingToggle.checked,
            "captureRecordingFps": Number(recordingFpsField.text),
            "captureRecordingCodec": recordingCodecChoice.value,
            "captureRecordingQuality": recordingQualityChoice.value,
            "captureRecordingMicrophone": recordingMicrophoneToggle.checked,
            "captureEditorTool": settings.captureEditorTool ?? Config.captureEditorTool,
            "captureEditorColor": settings.captureEditorColor ?? Config.captureEditorColor,
            "captureEditorWidth": settings.captureEditorWidth ?? Config.captureEditorWidth,
            "wallpaperEngineAssetsDirPath": engineAssetsField.text,
            "wallpaperEngineWorkshopDirPath": engineWorkshopField.text
        };
    }
    function refreshIntegrations() {
        GoogleService.checkAuthentication();
        EngineWallpaperService.checkAvailability();
        SettingsHubService.refresh();
    }
    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        fontField.text = settings.fontName || Config.fontName;
        profileImageField.text = settings.profileImagePath || Config.profileImagePath;
        barBlurToggle.checked = settings.shellBlurBarEnabled ?? Config.shellBlurBarEnabled;
        barOpacityDarkField.text = String(settings.shellBlurBarOpacityDark ?? Config.shellBlurBarOpacityDark);
        barOpacityLightField.text = String(settings.shellBlurBarOpacityLight ?? Config.shellBlurBarOpacityLight);
        controlLeftBlurToggle.checked = settings.shellBlurControlLeftEnabled ?? Config.shellBlurControlLeftEnabled;
        controlRightBlurToggle.checked = settings.shellBlurControlRightEnabled ?? Config.shellBlurControlRightEnabled;
        dockBlurToggle.checked = settings.shellBlurDockEnabled ?? Config.shellBlurDockEnabled;
        launcherBlurToggle.checked = settings.shellBlurLauncherEnabled ?? Config.shellBlurLauncherEnabled;
        notificationBlurToggle.checked = settings.shellBlurNotificationEnabled ?? Config.shellBlurNotificationEnabled;
        osdBlurToggle.checked = settings.shellBlurOsdEnabled ?? Config.shellBlurOsdEnabled;
        panelOpacityDarkField.text = String(settings.shellBlurPanelOpacityDark ?? Config.shellBlurPanelOpacityDark);
        panelOpacityLightField.text = String(settings.shellBlurPanelOpacityLight ?? Config.shellBlurPanelOpacityLight);
        settingsBlurToggle.checked = settings.shellBlurSettingsEnabled ?? Config.shellBlurSettingsEnabled;
        componentShadowBlurField.text = String(settings.shellComponentShadowBlur ?? Config.shellComponentShadowBlur);
        componentShadowEnabledToggle.checked = settings.shellComponentShadowEnabled ?? Config.shellComponentShadowEnabled;
        componentShadowOffsetXField.text = String(settings.shellComponentShadowOffsetX ?? Config.shellComponentShadowOffsetX);
        componentShadowOffsetYField.text = String(settings.shellComponentShadowOffsetY ?? Config.shellComponentShadowOffsetY);
        componentShadowOpacityField.text = String(settings.shellComponentShadowOpacity ?? Config.shellComponentShadowOpacity);
        componentShadowSpreadField.text = String(settings.shellComponentShadowSpread ?? Config.shellComponentShadowSpread);
        shadowBlurField.text = String(settings.shellShadowBlur ?? Config.shellShadowBlur);
        shadowEnabledToggle.checked = settings.shellShadowEnabled ?? Config.shellShadowEnabled;
        shadowOffsetXField.text = String(settings.shellShadowOffsetX ?? Config.shellShadowOffsetX);
        shadowOffsetYField.text = String(settings.shellShadowOffsetY ?? Config.shellShadowOffsetY);
        shadowOpacityField.text = String(settings.shellShadowOpacity ?? Config.shellShadowOpacity);
        shadowSpreadField.text = String(settings.shellShadowSpread ?? Config.shellShadowSpread);
        clockToggle.checked = settings.clock24h ?? Config.clock24h;
        locationField.text = settings.latLon || Config.latLon;
        apiField.text = settings.apiWeather || Config.apiWeather;
        steamUsernameField.text = settings.steamUsername || Config.steamUsername;
        steamApiKeyField.text = settings.steamWebApiKey || Config.steamWebApiKey;
        wallhavenUsernameField.text = settings.wallhavenUsername || Config.wallhavenUsername;
        wallhavenApiKeyField.text = settings.wallhavenApiKey || Config.wallhavenApiKey;
        wallFolderField.text = settings.wallFolderPath || Config.wallFolderPath;
        liveWallFolderField.text = settings.liveWallFolderPath || Config.liveWallFolderPath;
        batteryFpsField.text = String(settings.wallpaperBatteryFps ?? Config.wallpaperBatteryFps);
        engineFpsField.text = String(settings.wallpaperEngineFps ?? Config.wallpaperEngineFps);
        pauseFullscreenToggle.checked = settings.wallpaperPauseOnFullscreen ?? Config.wallpaperPauseOnFullscreen;
        pauseLockToggle.checked = settings.wallpaperPauseOnLock ?? Config.wallpaperPauseOnLock;
        wallpaperTransitionField.text = String(settings.wallpaperTransitionDuration ?? Config.wallpaperTransitionDuration);
        matugenToggle.checked = settings.matugenEnabled ?? Config.matugenEnabled;
        matugenAnimationToggle.checked = settings.matugenAnimateColors ?? Config.matugenAnimateColors;
        matugenTransitionField.text = String(settings.matugenTransitionDuration ?? Config.matugenTransitionDuration);
        screenshotDirField.text = settings.captureScreenshotDirPath || Config.captureScreenshotDirPath;
        recordingDirField.text = settings.captureRecordingDirPath || Config.captureRecordingDirPath;
        copyScreenshotToggle.checked = settings.captureAutoCopyScreenshot ?? Config.captureAutoCopyScreenshot;
        copyRecordingToggle.checked = settings.captureAutoCopyRecording ?? Config.captureAutoCopyRecording;
        recordingFpsField.text = String(settings.captureRecordingFps ?? Config.captureRecordingFps);
        recordingCodecChoice.value = settings.captureRecordingCodec || Config.captureRecordingCodec;
        recordingQualityChoice.value = settings.captureRecordingQuality || Config.captureRecordingQuality;
        recordingMicrophoneToggle.checked = settings.captureRecordingMicrophone ?? Config.captureRecordingMicrophone;
        engineAssetsField.text = settings.wallpaperEngineAssetsDirPath || Config.wallpaperEngineAssetsDirPath;
        engineWorkshopField.text = settings.wallpaperEngineWorkshopDirPath || Config.wallpaperEngineWorkshopDirPath;
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: syncFields()
    onActiveSectionChanged: {
        scroll.contentItem.contentX = 0;
        scroll.contentItem.contentY = 0;
        if (activeSection === 3)
            refreshIntegrations();
    }

    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    Connections {
        function onLocationDetected(coordinates) {
            locationField.text = coordinates;
        }

        target: WeatherService
    }
    ScrollView {
        id: scroll

        anchors.fill: parent
        contentHeight: content.implicitHeight
        contentWidth: availableWidth

        ScrollBar.horizontal: SlimScrollBar {
            accentColor: root.activeSection === 0 ? Config.md3.secondary : root.activeSection === 1 ? Config.md3.tertiary : root.activeSection === 2 ? Config.md3.primary : Config.md3.error
        }
        ScrollBar.vertical: SlimScrollBar {
            accentColor: root.activeSection === 0 ? Config.md3.secondary : root.activeSection === 1 ? Config.md3.tertiary : root.activeSection === 2 ? Config.md3.primary : Config.md3.error
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
                accentColor: Config.md3.secondary
                iconName: "avatar-default-symbolic"
                note: qsTr("Used by authentication prompts and the login screen")
                title: qsTr("Profile image")
                visible: root.activeSection === 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ProfileAvatar {
                        Layout.preferredHeight: 76
                        Layout.preferredWidth: 76
                        sourcePath: root.profileImageField.text
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideMiddle
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: root.profileImageField.text === "" ? qsTr("Default profile icon") : root.profileImageField.text.split("/").pop()
                        }
                        Text {
                            Layout.fillWidth: true
                            color: ProfileImageService.errorMessage !== "" ? Config.md3.error : Config.alpha(Config.md3.on_surface, 0.5)
                            font.family: Config.fontName
                            font.pixelSize: 12
                            text: ProfileImageService.errorMessage || ProfileImageService.statusMessage || qsTr("PNG, JPEG, WebP or AVIF")
                            wrapMode: Text.Wrap
                        }
                    }
                    SettingsActionButton {
                        iconName: "document-open-symbolic"
                        iconOnly: true
                        text: qsTr("Choose image")

                        onClicked: SettingsHubService.filePickerDialog.open(root.profileImageField, "file://" + Config.expandHomePath("~"), false, [qsTr("Images | *.png *.jpg *.jpeg *.webp *.avif")])
                    }
                    SettingsActionButton {
                        enabled: root.profileImageField.text !== ""
                        iconName: "user-trash-symbolic"
                        iconOnly: true
                        text: qsTr("Remove profile image")

                        onClicked: root.profileImageField.text = ""
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                iconName: "preferences-desktop-font-symbolic"
                note: "Shell typography"
                title: "Typography"
                visible: root.activeSection === 0

                SettingsFontPicker {
                    id: fontField

                    Layout.fillWidth: true
                    label: "Font family"
                    placeholder: "Inter"
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                iconName: "weather-fog-symbolic"
                note: "Higher values make surfaces more opaque"
                title: "Surface blur"
                visible: root.activeSection === 0

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: width >= 620 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: panelOpacityLightField

                        Layout.fillWidth: true
                        label: "Panels · Light mode"
                        placeholder: "0.88"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: panelOpacityDarkField

                        Layout.fillWidth: true
                        label: "Panels · Dark mode"
                        placeholder: "0.76"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: barOpacityLightField

                        Layout.fillWidth: true
                        label: "Bar · Light mode"
                        placeholder: "0.86"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: barOpacityDarkField

                        Layout.fillWidth: true
                        label: "Bar · Dark mode"
                        placeholder: "0.24"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: width >= 620 ? 2 : 1
                    rowSpacing: 4
                    uniformCellWidths: true

                    SettingsToggleTile {
                        id: barBlurToggle

                        label: "Bar"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: launcherBlurToggle

                        label: "Launcher"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: osdBlurToggle

                        label: "OSD"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: notificationBlurToggle

                        label: "Notifications"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: settingsBlurToggle

                        label: "Settings"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: controlLeftBlurToggle

                        label: "Control Left"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: controlRightBlurToggle

                        label: "Control Right"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: dockBlurToggle

                        label: "Dock"

                        onToggled: value => checked = value
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "preferences-desktop-effects-symbolic"
                note: "Shadow used by large panels, dialogs and popups"
                title: "Panel shadows"
                visible: root.activeSection === 0

                SettingsToggleTile {
                    id: shadowEnabledToggle

                    label: "Enable panel shadows"
                    note: "Uses the current Material You shadow color"

                    onToggled: value => checked = value
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: width >= 620 ? 3 : 2
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: shadowBlurField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Blur (0–64)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "18"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 64
                        }
                    }
                    SettingsTextField {
                        id: shadowOpacityField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Opacity (0–1)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0.28"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: shadowSpreadField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Spread (-32–32)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "1"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsTextField {
                        id: shadowOffsetXField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Horizontal offset"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsTextField {
                        id: shadowOffsetYField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Vertical offset"
                        opacity: editable ? 1 : 0.45
                        placeholder: "3"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                iconName: "color-select-symbolic"
                note: "Lighter shadow for buttons, tabs and compact controls"
                title: "Component shadows"
                visible: root.activeSection === 0

                SettingsToggleTile {
                    id: componentShadowEnabledToggle

                    label: "Enable component shadows"
                    note: "Independent from panel shadow settings"

                    onToggled: value => checked = value
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: width >= 620 ? 3 : 2
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: componentShadowBlurField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Blur (0–64)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "10"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 64
                        }
                    }
                    SettingsTextField {
                        id: componentShadowOpacityField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Opacity (0–1)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0.18"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: componentShadowSpreadField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Spread (-32–32)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsTextField {
                        id: componentShadowOffsetXField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Horizontal offset"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsTextField {
                        id: componentShadowOffsetYField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Vertical offset"
                        opacity: editable ? 1 : 0.45
                        placeholder: "2"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                compact: true
                iconName: "preferences-system-time-symbolic"
                note: "Regional date and time presentation"
                title: "Date & time"
                visible: root.activeSection === 0

                SettingsToggleTile {
                    id: clockToggle

                    label: "Use 24-hour time format"
                    note: "Turn off to use 12-hour AM/PM format"

                    onToggled: value => checked = value
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "preferences-desktop-wallpaper-symbolic"
                note: "Folders scanned by the static and live wallpaper selectors"
                title: "Wallpaper library"
                visible: root.activeSection === 1

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
                visible: root.activeSection === 1

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

                    onToggled: value => checked = value
                }
                SettingsToggleRow {
                    id: pauseLockToggle

                    label: "Pause while locked"
                    note: "Resumes automatically after the lock screen closes"

                    onToggled: value => checked = value
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "color-select-symbolic"
                note: "Generate the shell and application palette from the selected wallpaper"
                title: "Matugen"
                visible: root.activeSection === 1

                SettingsToggleRow {
                    id: matugenToggle

                    label: "Generate dynamic colors"
                    note: "Disabling this keeps the current palette when wallpaper changes"

                    onToggled: value => checked = value
                }
                SettingsToggleRow {
                    id: matugenAnimationToggle

                    enabled: matugenToggle.checked
                    label: "Animate shell colors"
                    note: "Blend between the old and new palette"
                    opacity: enabled ? 1 : 0.45

                    onToggled: value => checked = value
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
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                iconName: "folder-symbolic"
                note: "The screenshot path is also written to Niri so the watcher stays in sync"
                title: "Storage"
                visible: root.activeSection === 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SettingsTextField {
                        id: screenshotDirField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: "Screenshot folder"
                        placeholder: "~/Pictures/Screenshots"

                        onActionClicked: {
                            SettingsHubService.filePickerDialog.open(screenshotDirField, "file://" + Config.expandHomePath("~"), true);
                        }
                    }
                    SettingsTextField {
                        id: recordingDirField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: "Recording folder"
                        placeholder: "~/Videos"

                        onActionClicked: {
                            SettingsHubService.filePickerDialog.open(recordingDirField, "file://" + Config.expandHomePath("~"), true);
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                iconName: "media-record-symbolic"
                note: "Defaults passed directly to gpu-screen-recorder"
                title: "Recording"
                visible: root.activeSection === 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SettingsTextField {
                        id: recordingFpsField

                        Layout.fillWidth: true
                        label: "FPS"
                        placeholder: "60"

                        inputItem.validator: IntValidator {
                            bottom: 5
                            top: 165
                        }
                    }
                    SettingsChoiceRow {
                        id: recordingCodecChoice

                        Layout.fillWidth: true
                        label: "Codec"
                        options: [
                            {
                                "label": "H.264",
                                "value": "h264"
                            },
                            {
                                "label": "HEVC",
                                "value": "hevc"
                            },
                        ]
                    }
                    SettingsChoiceRow {
                        id: recordingQualityChoice

                        Layout.fillWidth: true
                        label: "Quality"
                        options: [
                            {
                                "label": "Medium",
                                "value": "medium"
                            },
                            {
                                "label": "High",
                                "value": "high"
                            },
                            {
                                "label": "Very high",
                                "value": "very_high"
                            }
                        ]
                    }
                }
                SettingsToggleRow {
                    id: recordingMicrophoneToggle

                    label: "Record microphone"
                    note: "Mixes the default microphone with system audio directly"

                    onToggled: value => checked = value
                }
                SettingsToggleRow {
                    id: copyRecordingToggle

                    label: "Copy recording after stop"
                    note: "Copies a file URI without buffering the whole video in memory"

                    onToggled: value => checked = value
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                iconName: "camera-photo-symbolic"
                note: "Clipboard behavior after editing a screenshot"
                title: "Screenshot"
                visible: root.activeSection === 2

                SettingsToggleRow {
                    id: copyScreenshotToggle

                    label: "Copy edited screenshot"
                    note: "Automatically places the saved PNG on the clipboard"

                    onToggled: value => checked = value
                }
            }
            SettingsIntegrationCard {
                id: weatherIntegration

                accentColor: Config.md3.primary
                actionIcon: WeatherService.detectingLocation ? "process-stop-symbolic" : "find-location-symbolic"
                actionText: WeatherService.detectingLocation ? qsTr("Cancel location detection") : qsTr("Detect location")
                actionVisible: true
                iconName: "weather-clear-symbolic"
                note: qsTr("OpenWeatherMap coordinates and credentials")
                statusColor: WeatherService.locationDetectionError ? Config.md3.error : locationField.text !== "" && apiField.text !== "" ? Config.md3.secondary : Config.md3.tertiary
                statusIcon: WeatherService.detectingLocation ? "process-working-symbolic" : WeatherService.locationDetectionError ? "dialog-error-symbolic" : locationField.text !== "" && apiField.text !== "" ? "emblem-ok-symbolic" : "dialog-information-symbolic"
                statusText: WeatherService.detectingLocation ? qsTr("Detecting") : WeatherService.locationDetectionError ? qsTr("Location error") : locationField.text !== "" && apiField.text !== "" ? qsTr("Ready") : qsTr("Setup")
                title: qsTr("Weather")
                visible: root.activeSection === 3

                onActionClicked: {
                    if (WeatherService.detectingLocation)
                        WeatherService.cancelLocationDetection();
                    else
                        WeatherService.detectLocation();
                }

                GridLayout {
                    id: weatherFields

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 720 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: locationField

                        Layout.fillWidth: true
                        label: qsTr("Location")
                        placeholder: "21.03,105.85"
                    }
                    SettingsTextField {
                        id: apiField

                        Layout.fillWidth: true
                        actionIcon: root.revealApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        echoMode: root.revealApiKey ? TextInput.Normal : TextInput.Password
                        label: qsTr("OpenWeatherMap API key")
                        placeholder: qsTr("Enter API key")

                        onActionClicked: root.revealApiKey = !root.revealApiKey
                    }
                    Text {
                        Layout.columnSpan: weatherFields.columns
                        Layout.fillWidth: true
                        color: WeatherService.locationDetectionError ? Config.md3.error : Config.alpha(Config.md3.on_surface, 0.58)
                        font.family: Config.fontName
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                        text: WeatherService.locationDetectionStatus
                        visible: text !== ""
                        wrapMode: Text.Wrap
                    }
                }
            }
            SettingsIntegrationCard {
                id: googleIntegration

                property bool confirmingRemoval: false
                property Timer removalTimer: Timer {
                    interval: 3000

                    onTriggered: googleIntegration.confirmingRemoval = false
                }

                accentColor: Config.md3.secondary
                actionEnabled: !GoogleService.disconnecting
                actionIcon: confirmingRemoval ? "dialog-warning-symbolic" : "user-trash-symbolic"
                actionText: GoogleService.disconnecting ? qsTr("Removing account") : confirmingRemoval ? qsTr("Confirm account removal") : qsTr("Remove account")
                actionVisible: GoogleService.authenticated || GoogleService.disconnecting
                iconName: "x-office-calendar-symbolic"
                note: GoogleService.authenticated ? (GoogleService.connectedAccount !== "" ? qsTr("Connected as %1").arg(GoogleService.connectedAccount) : qsTr("Connected Google account")) : GoogleService.authStatus || qsTr("Connect your account from Calendar or Todo")
                statusColor: GoogleService.authenticated ? Config.md3.secondary : Config.md3.tertiary
                statusIcon: GoogleService.disconnecting ? "process-working-symbolic" : GoogleService.authenticated ? "emblem-ok-symbolic" : "dialog-information-symbolic"
                statusText: GoogleService.disconnecting ? qsTr("Disconnecting") : GoogleService.authenticated ? qsTr("Connected") : qsTr("Not connected")
                title: qsTr("Google Calendar & Tasks")
                visible: root.activeSection === 3

                onActionClicked: {
                    if (!confirmingRemoval) {
                        confirmingRemoval = true;
                        removalTimer.restart();
                    } else {
                        confirmingRemoval = false;
                        removalTimer.stop();
                        GoogleService.disconnectAccount();
                    }
                }

                GridLayout {
                    id: googleCredentialFields

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 720 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        Layout.fillWidth: true
                        inputItem.readOnly: true
                        label: qsTr("App ID (Client ID)")
                        placeholder: qsTr("No App ID stored")
                        text: GoogleService.oauthClientId
                    }
                    SettingsTextField {
                        Layout.fillWidth: true
                        actionIcon: GoogleService.oauthClientSecret !== "" ? (root.revealGoogleToken ? "view-conceal-symbolic" : "view-reveal-symbolic") : ""
                        echoMode: root.revealGoogleToken ? TextInput.Normal : TextInput.Password
                        inputItem.readOnly: true
                        label: qsTr("Token (Client Secret)")
                        placeholder: qsTr("No token stored")
                        text: GoogleService.oauthClientSecret

                        onActionClicked: root.revealGoogleToken = !root.revealGoogleToken
                    }
                }
            }
            SettingsIntegrationCard {
                id: engineIntegration

                accentColor: Config.md3.error
                actionIcon: "view-refresh-symbolic"
                actionText: qsTr("Rescan Wallpaper Engine")
                actionVisible: true
                iconName: "applications-games-symbolic"
                note: EngineWallpaperService.errorMessage || qsTr("Steam Workshop paths and account access")
                statusColor: EngineWallpaperService.availabilityKnown ? (EngineWallpaperService.available ? Config.md3.secondary : Config.md3.error) : Config.md3.tertiary
                statusIcon: EngineWallpaperService.availabilityKnown ? (EngineWallpaperService.available ? "emblem-ok-symbolic" : "dialog-error-symbolic") : "process-working-symbolic"
                statusText: EngineWallpaperService.availabilityKnown ? (EngineWallpaperService.available ? qsTr("Ready") : qsTr("Unavailable")) : qsTr("Checking")
                title: qsTr("Wallpaper Engine")
                visible: root.activeSection === 3

                onActionClicked: EngineWallpaperService.refresh()

                GridLayout {
                    id: engineFields

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 760 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: engineAssetsField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: qsTr("Wallpaper Engine assets")
                        placeholder: "~/.local/share/Steam/steamapps/common/wallpaper_engine/assets"

                        onActionClicked: SettingsHubService.filePickerDialog.open(engineAssetsField, "file://" + Config.expandHomePath("~"), true)
                    }
                    SettingsTextField {
                        id: engineWorkshopField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: qsTr("Workshop folder")
                        placeholder: "~/.local/share/Steam/steamapps/workshop/content/431960"

                        onActionClicked: SettingsHubService.filePickerDialog.open(engineWorkshopField, "file://" + Config.expandHomePath("~"), true)
                    }
                    SettingsTextField {
                        id: steamUsernameField

                        Layout.fillWidth: true
                        label: qsTr("Steam username")
                        placeholder: qsTr("Account name used by SteamCMD")
                    }
                    SettingsTextField {
                        id: steamApiKeyField

                        Layout.fillWidth: true
                        actionIcon: root.revealSteamApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        echoMode: root.revealSteamApiKey ? TextInput.Normal : TextInput.Password
                        label: qsTr("Steam Web API key")
                        placeholder: qsTr("Required for Workshop search")

                        onActionClicked: root.revealSteamApiKey = !root.revealSteamApiKey
                    }
                }
            }
            SettingsIntegrationCard {
                id: wallhavenIntegration

                accentColor: Config.md3.tertiary
                iconName: "preferences-desktop-wallpaper-symbolic"
                note: qsTr("Optional account access for collections and NSFW results")
                statusColor: wallhavenApiKeyField.text !== "" ? Config.md3.secondary : Config.md3.tertiary
                statusIcon: wallhavenApiKeyField.text !== "" ? "emblem-ok-symbolic" : "dialog-information-symbolic"
                statusText: wallhavenApiKeyField.text !== "" ? qsTr("Configured") : qsTr("Optional")
                title: qsTr("Wallhaven")
                visible: root.activeSection === 3

                GridLayout {
                    id: wallhavenFields

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 720 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: wallhavenUsernameField

                        Layout.fillWidth: true
                        label: qsTr("Wallhaven username")
                        placeholder: qsTr("Required for Collections")
                    }
                    SettingsTextField {
                        id: wallhavenApiKeyField

                        Layout.fillWidth: true
                        actionIcon: root.revealWallhavenApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        echoMode: root.revealWallhavenApiKey ? TextInput.Normal : TextInput.Password
                        label: qsTr("Wallhaven API key")
                        placeholder: qsTr("Optional for Browse, required for account access")

                        onActionClicked: root.revealWallhavenApiKey = !root.revealWallhavenApiKey
                    }
                }
            }
        }
    }
}
