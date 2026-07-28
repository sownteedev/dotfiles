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
    readonly property var dependencies: SettingsHubService.quickshellSettings.dependencies || ({})
    readonly property var dependencyRows: [
        {
            "key": "matugen",
            "label": "Matugen",
            "note": "Dynamic color generation"
        },
        {
            "key": "mpvpaper",
            "label": "mpvpaper",
            "note": "Video wallpaper playback"
        },
        {
            "key": "linux-wallpaperengine",
            "label": "linux-wallpaperengine",
            "note": "Wallpaper Engine projects"
        },
        {
            "key": "gpu-screen-recorder",
            "label": "gpu-screen-recorder",
            "note": "Wayland screen recording"
        },
        {
            "key": "slurp",
            "label": "slurp",
            "note": "Region selection"
        },
        {
            "key": "ffmpeg",
            "label": "FFmpeg",
            "note": "Frames and media conversion"
        },
        {
            "key": "wl-copy",
            "label": "wl-clipboard",
            "note": "Clipboard copy"
        },
        {
            "key": "inotifywait",
            "label": "inotify-tools",
            "note": "Screenshot watcher"
        },
        {
            "key": "tesseract",
            "label": "Tesseract",
            "note": "Screenshot OCR"
        }
    ]
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    property bool revealApiKey: false

    function refreshIntegrations() {
        GoogleService.checkAuthentication();
        EngineWallpaperService.checkAvailability();
        SettingsHubService.refresh();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        fontField.text = settings.fontName || Config.fontName;
        profileField.text = settings.profileImagePath || Config.profileImagePath;
        clockToggle.checked = settings.clock24h ?? Config.clock24h;
        locationField.text = settings.latLon || Config.latLon;
        apiField.text = settings.apiWeather || Config.apiWeather;
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
        editorToolChoice.value = settings.captureEditorTool || Config.captureEditorTool;
        editorColorField.text = settings.captureEditorColor || Config.captureEditorColor;
        editorWidthField.text = String(settings.captureEditorWidth ?? Config.captureEditorWidth);
        engineAssetsField.text = settings.wallpaperEngineAssetsDirPath || Config.wallpaperEngineAssetsDirPath;
        engineWorkshopField.text = settings.wallpaperEngineWorkshopDirPath || Config.wallpaperEngineWorkshopDirPath;
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell({
            "fontName": fontField.text,
            "profileImagePath": profileField.text,
            "clock24h": clockToggle.checked,
            "latLon": locationField.text,
            "apiWeather": apiField.text,
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
            "captureEditorTool": editorToolChoice.value,
            "captureEditorColor": editorColorField.text,
            "captureEditorWidth": Number(editorWidthField.text),
            "wallpaperEngineAssetsDirPath": engineAssetsField.text,
            "wallpaperEngineWorkshopDirPath": engineWorkshopField.text
        });
    }

    Component.onCompleted: syncFields()
    onActiveSectionChanged: {
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
    ScrollView {
        id: scroll

        anchors.fill: parent
        clip: true

        ScrollBar.vertical: SlimScrollBar {
            accentColor: root.activeSection === 0 ? Config.md3.secondary : root.activeSection === 1 ? Config.md3.tertiary : root.activeSection === 2 ? Config.md3.primary : Config.md3.error
        }

        ColumnLayout {
            spacing: 14
            width: scroll.availableWidth

            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                note: "Typography shared by every shell widget"
                title: "Appearance"
                visible: root.activeSection === 0

                SettingsTextField {
                    id: fontField

                    Layout.fillWidth: true
                    label: "Font family"
                    placeholder: "Inter"
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                note: "Personalize your shell identity"
                title: "Profile"
                visible: root.activeSection === 0

                SettingsTextField {
                    id: profileField

                    Layout.fillWidth: true
                    actionIcon: "document-open-symbolic"
                    label: "Profile image path"
                    placeholder: "~/Dotfiles/quickshell/assets/images/sownteedev.png"

                    onActionClicked: {
                        SettingsHubService.filePickerDialog.open(profileField, "file://" + Config.expandHomePath("~"), false);
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                note: "Date and time display formats"
                title: "Localization"
                visible: root.activeSection === 0

                SettingsToggleRow {
                    id: clockToggle

                    label: "Use 24-hour time format"
                    note: "Turn off to use 12-hour AM/PM format"

                    onToggled: value => checked = value
                }
            }
            SettingsSectionCard {
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
                            {
                                "label": "AV1",
                                "value": "av1"
                            }
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
                    id: copyRecordingToggle

                    label: "Copy recording after stop"
                    note: "Copies a file URI without buffering the whole video in memory"

                    onToggled: value => checked = value
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                note: "Initial values used whenever the screenshot editor opens"
                title: "Screenshot editor"
                visible: root.activeSection === 2

                SettingsToggleRow {
                    id: copyScreenshotToggle

                    label: "Copy edited screenshot"
                    note: "Automatically places the saved PNG on the clipboard"

                    onToggled: value => checked = value
                }
                SettingsChoiceRow {
                    id: editorToolChoice

                    Layout.fillWidth: true
                    label: "Default tool"
                    options: [
                        {
                            "label": "Pen",
                            "value": "pen"
                        },
                        {
                            "label": "Arrow",
                            "value": "arrow"
                        },
                        {
                            "label": "Rectangle",
                            "value": "rectangle"
                        },
                        {
                            "label": "Blur",
                            "value": "blur"
                        },
                        {
                            "label": "Pixelate",
                            "value": "pixelate"
                        },
                        {
                            "label": "Text",
                            "value": "text"
                        }
                    ]
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SettingsTextField {
                        id: editorColorField

                        Layout.fillWidth: true
                        label: "Default color"
                        placeholder: "#ff3b30"
                    }
                    SettingsTextField {
                        id: editorWidthField

                        Layout.fillWidth: true
                        label: "Default width"
                        placeholder: "6"

                        inputItem.validator: IntValidator {
                            bottom: 1
                            top: 96
                        }
                    }
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
                    label: "Location (latitude, longitude)"
                    placeholder: "21.03,105.85"
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
                        iconName: "view-refresh-symbolic"
                        text: "Check again"

                        onClicked: GoogleService.checkAuthentication()
                    }
                }
            }
            SettingsSectionCard {
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
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.error
                note: "Detected on PATH when this panel was opened"
                title: "Dependencies"
                visible: root.activeSection === 3

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: 3
                    rowSpacing: 10

                    Repeater {
                        model: root.dependencyRows

                        delegate: Rectangle {
                            id: dependencyItem

                            readonly property bool installed: root.dependencies[modelData.key] === true
                            required property var modelData

                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.035)
                            implicitHeight: 58
                            radius: 12

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Rectangle {
                                    color: dependencyItem.installed ? Config.md3.secondary : Config.md3.error
                                    implicitHeight: 9
                                    implicitWidth: 9
                                    radius: 5
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        text: dependencyItem.modelData.label
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.alpha(Config.md3.on_surface, 0.43)
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 11
                                        text: dependencyItem.installed ? "Installed" : "Missing · " + dependencyItem.modelData.note
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item {
                Layout.preferredHeight: 10
            }
        }
    }
}
