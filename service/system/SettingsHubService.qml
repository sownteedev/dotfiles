pragma Singleton
import "../../"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

QtObject {
    id: root

    property var activeFilePickerTarget: null
    property var animationSettings: ({
            "enabled": true,
            "slowdown": 1,
            "entries": []
        })
    property var behaviorSettings: ({
            "showHotkeyOverlayAtStartup": false,
            "preferNoCsd": true,
            "screenshotSavingEnabled": true,
            "screenshotPath": "",
            "hideUnboundHotkeys": false,
            "disablePrimaryClipboard": false,
            "disableConfigError": false,
            "xwaylandEnabled": false,
            "xwaylandPath": "xwayland-satellite",
            "switchEvents": false,
            "hideCursorWhileTyping": false,
            "cursorTimeoutEnabled": false,
            "cursorTimeoutMs": 1000,
            "cursorTheme": "",
            "cursorSize": 24,
            "disablePowerKeyHandling": false,
            "warpMouseToFocus": false,
            "warpMouseMode": "separate",
            "focusFollowsMouse": false,
            "focusFollowsMaxScrollAmount": "0%",
            "workspaceAutoBackAndForth": false,
            "modKey": "",
            "modKeyNested": "",
            "dndViewTriggerWidth": 30,
            "dndViewDelayMs": 100,
            "dndViewMaxSpeed": 1500,
            "dndWorkspaceTriggerHeight": 50,
            "dndWorkspaceDelayMs": 100,
            "dndWorkspaceMaxSpeed": 1500,
            "hotCornersEnabled": true,
            "hotCornerTopLeft": true,
            "hotCornerTopRight": false,
            "hotCornerBottomLeft": false,
            "hotCornerBottomRight": false,
            "lidCloseAction": "",
            "lidOpenAction": "",
            "tabletModeOnAction": "",
            "tabletModeOffAction": ""
        })
    property bool busy: false
    property string errorMessage: ""
    property bool filePickerActive: false
    property Process filePickerDialog: Process {
        id: filePickerDialog

        function open(targetField, folder, folderOnly) {
            if (running || root.filePickerActive)
                return;

            root.activeFilePickerTarget = targetField;
            root.filePickerActive = true;
            var args = ["--file-selection", "--title=" + (folderOnly ? "Select folder" : "Select file")];
            if (folderOnly) {
                args.push("--directory");
            }
            if (folder !== "") {
                args.push("--filename=" + folder.replace("file://", ""));
            }
            command = ["zenity"].concat(args);

            // Temporarily push SettingsHub to the background (Wayland layer shell prevents zenity from being on top)
            if (StateManager.settingsHubLoader.item) {
                var hub = StateManager.settingsHubLoader.item;
                hub.aboveWindows = false;
                hub.WlrLayershell.keyboardFocus = WlrKeyboardFocus.None;
            }

            running = true;
        }

        stdout: StdioCollector {
            id: filePickerDialogStdout
        }

        onExited: (exitCode, exitStatus) => {
            root.filePickerActive = false;
            // Restore SettingsHub
            if (StateManager.settingsHubLoader.item) {
                var hub = StateManager.settingsHubLoader.item;
                hub.aboveWindows = true;
                hub.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive;
            }

            if (exitCode === 0 && root.activeFilePickerTarget) {
                var path = filePickerDialogStdout.text.trim();
                if (path !== "")
                    root.activeFilePickerTarget.text = path;
            }
            root.activeFilePickerTarget = null;
        }
    }
    readonly property string helperPath: Config.quickshellDir + "/scripts/settings_hub.py"
    property var inputEnabled: ({
            "Touchpad": true,
            "Mouse": true,
            "Trackpoint": false,
            "Trackball": false,
            "Tablet": false,
            "Touch": false
        })
    property var inputSettings: ({})
    property var keybindGroups: []
    property var layoutSettings: ({
            "gaps": 10,
            "borderWidth": 1,
            "shadow": true,
            "centerFocused": "on-overflow",
            "alwaysCenterSingle": true,
            "emptyWorkspaceAboveFirst": false,
            "defaultColumnDisplay": "normal",
            "backgroundColor": "transparent",
            "defaultColumnWidthMode": "proportion",
            "defaultColumnWidth": 1,
            "presetColumnWidthsEnabled": false,
            "presetColumnWidths": "proportion 0.33333, proportion 0.5, proportion 0.66667",
            "presetWindowHeightsEnabled": false,
            "presetWindowHeights": "proportion 0.33333, proportion 0.5, proportion 0.66667",
            "strutsEnabled": false,
            "strutLeft": 0,
            "strutRight": 0,
            "strutTop": 0,
            "strutBottom": 0,
            "overviewZoom": 0.4,
            "overviewBackdropColor": "#0a0a0a",
            "workspaceShadowEnabled": true,
            "workspaceShadowSoftness": 30,
            "workspaceShadowSpread": 5,
            "workspaceShadowOffsetX": 0,
            "workspaceShadowOffsetY": 0,
            "workspaceShadowColor": "#000000",
            "borderEnabled": true,
            "borderActiveColor": "#222222",
            "borderInactiveColor": "#222222",
            "borderUrgentColor": "#9b0000",
            "borderGradientEnabled": false,
            "borderActiveGradient": "from=\"#80c8ff\" to=\"#c7ff7f\" angle=45",
            "borderInactiveGradient": "from=\"#505050\" to=\"#808080\" angle=45",
            "borderUrgentGradient": "from=\"#800\" to=\"#a33\" angle=45",
            "focusRingEnabled": false,
            "focusRingWidth": 4,
            "focusRingActiveColor": "#7fc8ff",
            "focusRingInactiveColor": "#505050",
            "focusRingUrgentColor": "#9b0000",
            "focusRingGradientEnabled": false,
            "focusRingActiveGradient": "from=\"#80c8ff\" to=\"#bbddff\" angle=45",
            "focusRingInactiveGradient": "from=\"#505050\" to=\"#808080\" angle=45",
            "focusRingUrgentGradient": "from=\"#800\" to=\"#a33\" angle=45",
            "tabIndicatorEnabled": false,
            "tabHideSingle": true,
            "tabPlaceWithinColumn": true,
            "tabGap": 5,
            "tabWidth": 4,
            "tabLength": 1,
            "tabPosition": "right",
            "tabGapsBetween": 2,
            "tabCornerRadius": 8,
            "tabActiveColor": "#7fc8ff",
            "tabInactiveColor": "#505050",
            "tabUrgentColor": "#9b0000",
            "tabGradientEnabled": false,
            "tabActiveGradient": "from=\"#80c8ff\" to=\"#bbddff\" angle=45",
            "tabInactiveGradient": "from=\"#505050\" to=\"#808080\" angle=45",
            "tabUrgentGradient": "from=\"#800\" to=\"#a33\" angle=45",
            "insertHintEnabled": false,
            "insertHintColor": "#7fc8ff80",
            "insertHintGradientEnabled": false,
            "insertHintGradient": "from=\"#ffbb6680\" to=\"#ffc88080\" angle=45",
            "shadowSoftness": 20,
            "shadowSpread": 5,
            "shadowOffsetX": 0,
            "shadowOffsetY": 0,
            "shadowDrawBehind": true,
            "shadowColor": "#000000",
            "shadowInactiveColor": "#00000054",
            "blurEnabled": true,
            "blurPasses": 3,
            "blurOffset": 3,
            "blurNoise": 0.02,
            "blurSaturation": 1.5,
            "recentWindows": true,
            "recentDebounceMs": 750,
            "recentOpenDelayMs": 150,
            "recentHighlightActiveColor": "#999999ff",
            "recentHighlightUrgentColor": "#ff9999ff",
            "recentHighlightPadding": 30,
            "recentHighlightCornerRadius": 0,
            "recentPreviewHeight": 480,
            "recentPreviewScale": 0.5,
            "recentBinds": []
        })
    property var niriFiles: ({})
    property var pendingPayload: ({})
    property var quickshellSettings: ({
            "fontName": Config.fontName,
            "audioMaxVolume": Config.audioMaxVolume,
            "barDensity": Config.barDensity,
            "barHeight": Config.barHeight,
            "barShowActiveClient": Config.barShowActiveClient,
            "barShowBattery": Config.barShowBattery,
            "barShowBluetooth": Config.barShowBluetooth,
            "barShowClock": Config.barShowClock,
            "barShowMedia": Config.barShowMedia,
            "barShowMicrophone": Config.barShowMicrophone,
            "barShowNetwork": Config.barShowNetwork,
            "barShowNotifications": Config.barShowNotifications,
            "barShowRecording": Config.barShowRecording,
            "barShowSysTray": Config.barShowSysTray,
            "barShowWeather": Config.barShowWeather,
            "barShowWorkspaces": Config.barShowWorkspaces,
            "caffeineAutoDisableMinutes": Config.caffeineAutoDisableMinutes,
            "cavaEnabled": Config.cavaEnabled,
            "idleDisplayTimeout": Config.idleDisplayTimeout,
            "idleEnabled": Config.idleEnabled,
            "idleLockBeforeSleep": Config.idleLockBeforeSleep,
            "idleLockedDisplayTimeout": Config.idleLockedDisplayTimeout,
            "idleLockTimeout": Config.idleLockTimeout,
            "idleSuspendTimeout": Config.idleSuspendTimeout,
            "launcherCalculatorEnabled": Config.launcherCalculatorEnabled,
            "launcherCalculatorPrefix": Config.launcherCalculatorPrefix,
            "launcherClipboardAutoPaste": Config.launcherClipboardAutoPaste,
            "launcherClipboardEnabled": Config.launcherClipboardEnabled,
            "launcherClipboardPrefix": Config.launcherClipboardPrefix,
            "launcherEmojiEnabled": Config.launcherEmojiEnabled,
            "launcherEmojiPrefix": Config.launcherEmojiPrefix,
            "launcherFilesEnabled": Config.launcherFilesEnabled,
            "launcherFilesPrefix": Config.launcherFilesPrefix,
            "launcherFuzzySearch": Config.launcherFuzzySearch,
            "launcherMaxResults": Config.launcherMaxResults,
            "notificationBlockedApps": Config.notificationBlockedApps,
            "notificationDndEnd": Config.notificationDndEnd,
            "notificationDndScheduleEnabled": Config.notificationDndScheduleEnabled,
            "notificationDndStart": Config.notificationDndStart,
            "notificationHistoryExcludedApps": Config.notificationHistoryExcludedApps,
            "notificationHistoryLimit": Config.notificationHistoryLimit,
            "notificationMaxVisible": Config.notificationMaxVisible,
            "notificationPopupDuration": Config.notificationPopupDuration,
            "notificationPosition": Config.notificationPosition,
            "notificationShowInFullscreen": Config.notificationShowInFullscreen,
            "notificationShowOnLock": Config.notificationShowOnLock,
            "osdDuration": Config.osdDuration,
            "osdEnabled": Config.osdEnabled,
            "osdPosition": Config.osdPosition,
            "osdShowBrightness": Config.osdShowBrightness,
            "osdShowMicrophone": Config.osdShowMicrophone,
            "osdShowVolume": Config.osdShowVolume,
            "shellAnimationScale": Config.shellAnimationScale,
            "shellBlurBarEnabled": Config.shellBlurBarEnabled,
            "shellBlurControlLeftEnabled": Config.shellBlurControlLeftEnabled,
            "shellBlurControlRightEnabled": Config.shellBlurControlRightEnabled,
            "shellBlurLauncherEnabled": Config.shellBlurLauncherEnabled,
            "shellBlurSettingsEnabled": Config.shellBlurSettingsEnabled,
            "shellLowPowerMode": Config.shellLowPowerMode,
            "shellReducedMotion": Config.shellReducedMotion,
            "latLon": Config.latLon,
            "apiWeather": Config.apiWeather,
            "steamUsername": Config.steamUsername,
            "steamWebApiKey": Config.steamWebApiKey,
            "wallhavenUsername": Config.wallhavenUsername,
            "wallhavenApiKey": Config.wallhavenApiKey,
            "wallhavenShowNsfw": Config.wallhavenShowNsfw,
            "wallpaperWorkshopShowNsfw": Config.wallpaperWorkshopShowNsfw,
            "wallFolderPath": Config.wallFolderPath,
            "liveWallFolderPath": Config.liveWallFolderPath,
            "wallpaperBatteryFps": Config.wallpaperBatteryFps,
            "wallpaperEngineFps": Config.wallpaperEngineFps,
            "wallpaperPauseOnFullscreen": Config.wallpaperPauseOnFullscreen,
            "wallpaperPauseOnLock": Config.wallpaperPauseOnLock,
            "wallpaperTransitionDuration": Config.wallpaperTransitionDuration,
            "matugenEnabled": Config.matugenEnabled,
            "matugenAnimateColors": Config.matugenAnimateColors,
            "matugenTransitionDuration": Config.matugenTransitionDuration,
            "captureScreenshotDirPath": Config.captureScreenshotDirPath,
            "captureRecordingDirPath": Config.captureRecordingDirPath,
            "captureAutoCopyScreenshot": Config.captureAutoCopyScreenshot,
            "captureAutoCopyRecording": Config.captureAutoCopyRecording,
            "captureRecordingFps": Config.captureRecordingFps,
            "captureRecordingCodec": Config.captureRecordingCodec,
            "captureRecordingQuality": Config.captureRecordingQuality,
            "captureRecordingMicrophone": Config.captureRecordingMicrophone,
            "captureEditorTool": Config.captureEditorTool,
            "captureEditorColor": Config.captureEditorColor,
            "captureEditorWidth": Config.captureEditorWidth,
            "wallpaperEngineAssetsDirPath": Config.wallpaperEngineAssetsDirPath,
            "wallpaperEngineWorkshopDirPath": Config.wallpaperEngineWorkshopDirPath,
            "clock24h": Config.clock24h
        })
    property bool ready: false
    property Process saveProcess: Process {
        id: saveProcess

        property string operation: ""
        property string payloadJson: "{}"
        property bool timedOut: false

        command: ["python3", root.helperPath, operation, "-"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: saveError
        }
        stdout: StdioCollector {
            id: saveOutput
        }

        onExited: (exitCode, exitStatus) => {
            saveWatchdog.stop();
            root.busy = false;
            if (timedOut) {
                timedOut = false;
                root.pendingPayload = {};
                root.setStatus(false, "Settings apply timed out after 30 seconds");
                return;
            }
            var response = null;
            try {
                response = JSON.parse(saveOutput.text);
            } catch (error) {
                response = {
                    "ok": false,
                    "message": saveError.text.trim() || "Settings helper returned invalid data"
                };
            }
            var success = exitCode === 0 && response.ok === true;
            root.setStatus(success, response.message || (success ? "Saved" : "Could not save settings"));
            if (success) {
                if (operation === "set-quickshell")
                    root.applyQuickshellRuntime(root.pendingPayload);
                root.refresh();
            }
            root.pendingPayload = {};
        }
        onStarted: {
            timedOut = false;
            saveWatchdog.restart();
            // settings_hub.py reads one JSON line. Without the newline it waits
            // for EOF, which only happened when Quickshell was reloaded.
            write(payloadJson + "\n");
            payloadJson = "{}";
        }
    }
    property Timer saveWatchdog: Timer {
        interval: 30000
        repeat: false

        onTriggered: {
            if (!saveProcess.running)
                return;
            saveProcess.timedOut = true;
            saveProcess.signal(15);
        }
    }
    property Process snapshotProcess: Process {
        id: snapshotProcess

        command: ["python3", root.helperPath, "snapshot"]

        stderr: StdioCollector {
            id: snapshotError
        }
        stdout: StdioCollector {
            id: snapshotOutput
        }

        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0) {
                root.setStatus(false, snapshotError.text.trim() || "Could not read settings");
                return;
            }
            try {
                var data = JSON.parse(snapshotOutput.text);
                root.applySnapshot(data);
                root.errorMessage = "";
                root.ready = true;
            } catch (error) {
                root.setStatus(false, "Invalid settings response: " + error);
            }
        }
    }
    property string statusMessage: ""
    property bool statusSuccess: true

    signal operationFinished(bool success, string message)

    function applyQuickshellRuntime(settings) {
        for (var key in settings) {
            if (Config[key] !== undefined)
                Config[key] = settings[key];
        }
    }
    function applySnapshot(data) {
        var niri = data.niri || {};
        keybindGroups = niri.keybindGroups || [];
        layoutSettings = niri.layout || layoutSettings;
        inputSettings = niri.input || {};
        inputEnabled = niri.inputEnabled || inputEnabled;
        animationSettings = niri.animations || animationSettings;
        behaviorSettings = niri.behavior || behaviorSettings;
        niriFiles = niri.files || {};
        quickshellSettings = data.quickshell || quickshellSettings;
    }
    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }
    function refresh() {
        if (snapshotProcess.running || saveProcess.running)
            return;

        busy = true;
        snapshotProcess.running = true;
    }
    function save(operation, payload) {
        if (busy)
            return;

        pendingPayload = payload;
        saveProcess.payloadJson = JSON.stringify(payload);
        saveProcess.operation = operation;
        busy = true;
        Qt.callLater(function () {
            if (root.busy && !saveProcess.running)
                saveProcess.running = true;
        });
    }
    function saveAnimationEntry(name, enabled) {
        save("set-animation-entry", {
            "name": name,
            "enabled": enabled
        });
    }
    function saveAnimationGlobal(enabled, slowdown) {
        save("set-animation-global", {
            "enabled": enabled,
            "slowdown": slowdown
        });
    }
    function saveBehavior(settings) {
        save("set-behavior", settings);
    }
    function saveInput(section, entryIndex, value) {
        save("set-input", {
            "section": section,
            "entryIndex": entryIndex,
            "value": value
        });
    }
    function saveInputEnabled(section, enabled) {
        save("set-input-enabled", {
            "section": section,
            "enabled": enabled
        });
    }
    function saveInputEntryEnabled(section, entryIndex, enabled) {
        save("set-input-entry-enabled", {
            "section": section,
            "entryIndex": entryIndex,
            "enabled": enabled
        });
    }
    function saveKeybind(oldHeader, newKey) {
        save("set-keybind", {
            "oldHeader": oldHeader,
            "newKey": newKey
        });
    }
    function saveLayout(settings) {
        save("set-layout", settings);
    }
    function saveNiriFile(fileName, content) {
        save("set-niri-file", {
            "fileName": fileName,
            "content": content
        });
    }
    function saveQuickshell(settings) {
        save("set-quickshell", settings);
    }
    function setStatus(success, message) {
        statusSuccess = success;
        statusMessage = message;
        errorMessage = success ? "" : message;
        operationFinished(success, message);
    }
}
