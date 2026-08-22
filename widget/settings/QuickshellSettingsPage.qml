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
    property bool revealApiKey: false
    property bool revealSteamApiKey: false
    property bool revealWallhavenApiKey: false

    function currentState() {
        var settings = SettingsHubService.quickshellSettings || ({});
        return {
            "fontName": fontField.text,
            "shellBlurBarEnabled": barBlurToggle.checked,
            "shellBlurControlLeftEnabled": controlLeftBlurToggle.checked,
            "shellBlurControlRightEnabled": controlRightBlurToggle.checked,
            "shellBlurLauncherEnabled": launcherBlurToggle.checked,
            "shellBlurSettingsEnabled": settingsBlurToggle.checked,
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
        barBlurToggle.checked = settings.shellBlurBarEnabled ?? Config.shellBlurBarEnabled;
        controlLeftBlurToggle.checked = settings.shellBlurControlLeftEnabled ?? Config.shellBlurControlLeftEnabled;
        controlRightBlurToggle.checked = settings.shellBlurControlRightEnabled ?? Config.shellBlurControlRightEnabled;
        launcherBlurToggle.checked = settings.shellBlurLauncherEnabled ?? Config.shellBlurLauncherEnabled;
        settingsBlurToggle.checked = settings.shellBlurSettingsEnabled ?? Config.shellBlurSettingsEnabled;
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
                note: "Typography and surface blur"
                title: "Appearance"
                visible: root.activeSection === 0

                SettingsFontPicker {
                    id: fontField

                    Layout.fillWidth: true
                    label: "Font family"
                    placeholder: "Inter"
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsToggleTile {
                        id: barBlurToggle

                        label: "Bar blur"
                        note: "Blur the wallpaper behind the top bar"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: launcherBlurToggle

                        label: "Launcher blur"
                        note: "Blur content behind the launcher"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: settingsBlurToggle

                        label: "Settings blur"
                        note: "Blur content behind Settings"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: controlLeftBlurToggle

                        label: "Control Left blur"
                        note: "Blur content behind the left panel"

                        onToggled: value => checked = value
                    }
                    SettingsToggleTile {
                        id: controlRightBlurToggle

                        label: "Control Right blur"
                        note: "Blur content behind the right panel"

                        onToggled: value => checked = value
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                compact: true
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
                note: "Playback policy and transition timing"
                title: "Playback"
                visible: root.activeSection === 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SettingsTextField {
                        id: batteryFpsField

                        Layout.fillWidth: true
                        label: "Battery FPS"
                        placeholder: "20"

                        inputItem.validator: IntValidator {
                            bottom: 5
                            top: 60
                        }
                    }
                    SettingsTextField {
                        id: engineFpsField

                        Layout.fillWidth: true
                        label: "Live / Engine FPS"
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
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                note: "OpenWeatherMap location and credentials"
                title: "Weather"
                visible: root.activeSection === 3

                SettingsTextField {
                    id: locationField

                    Layout.fillWidth: true
                    actionIcon: WeatherService.detectingLocation ? "process-stop-symbolic" : "find-location-symbolic"
                    label: "Location (latitude, longitude)"
                    placeholder: "21.03,105.85"

                    onActionClicked: {
                        if (WeatherService.detectingLocation)
                            WeatherService.cancelLocationDetection();
                        else
                            WeatherService.detectLocation();
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: WeatherService.locationDetectionError ? Config.md3.error : Config.alpha(Config.md3.on_surface, 0.58)
                    font.family: Config.fontName
                    font.pixelSize: 13
                    text: WeatherService.locationDetectionStatus || qsTr("Use the location button to detect coordinates automatically")
                    visible: text !== ""
                    wrapMode: Text.Wrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingsTextField {
                        id: apiField

                        Layout.fillWidth: true
                        echoMode: root.revealApiKey ? TextInput.Normal : TextInput.Password
                        label: "OpenWeatherMap API key"
                        placeholder: "Enter API key"
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        iconName: root.revealApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        iconOnly: true
                        text: root.revealApiKey ? "Hide" : "Show"

                        onClicked: root.revealApiKey = !root.revealApiKey
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                note: "Calendar and Tasks share the same OAuth session"
                title: "Google Calendar & Tasks"
                visible: root.activeSection === 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        color: GoogleService.authenticated ? Config.alpha(Config.md3.secondary, 0.16) : Config.alpha(Config.md3.tertiary, 0.13)
                        implicitHeight: 42
                        implicitWidth: googleStatus.implicitWidth + 30
                        radius: 12

                        Text {
                            id: googleStatus

                            anchors.centerIn: parent
                            color: GoogleService.authenticated ? Config.md3.secondary : Config.md3.tertiary
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            text: GoogleService.authenticated ? "Connected" : GoogleService.authChecked ? "Not connected" : "Checking…"
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.55)
                        font.family: Config.fontName
                        font.pixelSize: 13
                        text: GoogleService.authStatus || "Authentication is managed from Calendar and Todo."
                        wrapMode: Text.Wrap
                    }
                    SettingsActionButton {
                        id: removeGoogleButton

                        property bool confirmingRemoval: false

                        enabled: !GoogleService.disconnecting
                        iconName: confirmingRemoval ? "dialog-warning-symbolic" : "user-trash-symbolic"
                        text: GoogleService.disconnecting ? "Removing…" : confirmingRemoval ? "Confirm removal" : "Remove account"
                        visible: GoogleService.authenticated || GoogleService.disconnecting

                        onClicked: {
                            if (!confirmingRemoval) {
                                confirmingRemoval = true;
                                googleRemovalTimer.restart();
                            } else {
                                confirmingRemoval = false;
                                googleRemovalTimer.stop();
                                GoogleService.disconnectAccount();
                            }
                        }

                        Timer {
                            id: googleRemovalTimer

                            interval: 3000

                            onTriggered: removeGoogleButton.confirmingRemoval = false
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.error
                note: "Paths used to discover and launch Steam Workshop projects"
                title: "Wallpaper Engine"
                visible: root.activeSection === 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        color: EngineWallpaperService.available ? Config.alpha(Config.md3.secondary, 0.16) : Config.alpha(Config.md3.error, 0.13)
                        implicitHeight: 42
                        implicitWidth: engineStatus.implicitWidth + 30
                        radius: 12

                        Text {
                            id: engineStatus

                            anchors.centerIn: parent
                            color: EngineWallpaperService.available ? Config.md3.secondary : Config.md3.error
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            text: EngineWallpaperService.availabilityKnown ? (EngineWallpaperService.available ? "Ready" : "Unavailable") : "Checking…"
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.55)
                        font.family: Config.fontName
                        font.pixelSize: 13
                        text: EngineWallpaperService.errorMessage
                        visible: text !== ""
                        wrapMode: Text.Wrap
                    }
                    SettingsActionButton {
                        iconName: "view-refresh-symbolic"
                        iconOnly: true
                        text: "Rescan"

                        onClicked: EngineWallpaperService.refresh()
                    }
                }
                SettingsTextField {
                    id: engineAssetsField

                    Layout.fillWidth: true
                    actionIcon: "folder-open-symbolic"
                    label: "Wallpaper Engine assets"
                    placeholder: "~/.local/share/Steam/steamapps/common/wallpaper_engine/assets"

                    onActionClicked: {
                        SettingsHubService.filePickerDialog.open(engineAssetsField, "file://" + Config.expandHomePath("~"), true);
                    }
                }
                SettingsTextField {
                    id: engineWorkshopField

                    Layout.fillWidth: true
                    actionIcon: "folder-open-symbolic"
                    label: "Workshop folder"
                    placeholder: "~/.local/share/Steam/steamapps/workshop/content/431960"

                    onActionClicked: {
                        SettingsHubService.filePickerDialog.open(engineWorkshopField, "file://" + Config.expandHomePath("~"), true);
                    }
                }
                SettingsTextField {
                    id: steamUsernameField

                    Layout.fillWidth: true
                    label: "Steam username"
                    placeholder: "Account name used by SteamCMD"
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingsTextField {
                        id: steamApiKeyField

                        Layout.fillWidth: true
                        echoMode: root.revealSteamApiKey ? TextInput.Normal : TextInput.Password
                        label: "Steam Web API key"
                        placeholder: "Required for Workshop search"
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        iconName: root.revealSteamApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        iconOnly: true
                        text: root.revealSteamApiKey ? "Hide" : "Show"

                        onClicked: root.revealSteamApiKey = !root.revealSteamApiKey
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                note: "Optional account access for private collections and NSFW results"
                title: "Wallhaven"
                visible: root.activeSection === 3

                SettingsTextField {
                    id: wallhavenUsernameField

                    Layout.fillWidth: true
                    label: "Wallhaven username"
                    placeholder: "Required for Collections"
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingsTextField {
                        id: wallhavenApiKeyField

                        Layout.fillWidth: true
                        echoMode: root.revealWallhavenApiKey ? TextInput.Normal : TextInput.Password
                        label: "Wallhaven API key"
                        placeholder: "Optional for Browse, required for account access"
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        iconName: root.revealWallhavenApiKey ? "view-conceal-symbolic" : "view-reveal-symbolic"
                        iconOnly: true
                        text: root.revealWallhavenApiKey ? "Hide" : "Show"

                        onClicked: root.revealWallhavenApiKey = !root.revealWallhavenApiKey
                    }
                }
            }
        }
    }
}
