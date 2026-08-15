pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: themeServiceRoot

    property var activeColors: null
    property string activeMode: ""
    property string activeSource: ""
    property string colorMode: "dark"
    property ParallelAnimation colorTransition: ParallelAnimation {
        ColorAnimation {
            id: anim_background

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "background"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_error

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "error"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_error_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "error_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_inverse_on_surface

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "inverse_on_surface"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_inverse_primary

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "inverse_primary"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_inverse_surface

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "inverse_surface"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_background

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_background"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_error

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_error"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_error_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_error_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_primary

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_primary"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_primary_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_primary_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_primary_fixed

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_primary_fixed"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_primary_fixed_variant

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_primary_fixed_variant"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_secondary

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_secondary"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_secondary_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_secondary_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_secondary_fixed

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_secondary_fixed"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_secondary_fixed_variant

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_secondary_fixed_variant"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_surface

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_surface"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_surface_variant

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_surface_variant"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_tertiary

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_tertiary"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_tertiary_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_tertiary_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_tertiary_fixed

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_tertiary_fixed"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_on_tertiary_fixed_variant

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "on_tertiary_fixed_variant"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_outline

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "outline"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_outline_variant

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "outline_variant"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_primary

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "primary"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_primary_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "primary_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_primary_fixed

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "primary_fixed"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_primary_fixed_dim

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "primary_fixed_dim"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_scrim

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "scrim"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_secondary

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "secondary"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_secondary_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "secondary_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_secondary_fixed

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "secondary_fixed"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_secondary_fixed_dim

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "secondary_fixed_dim"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_shadow

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "shadow"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface_bright

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface_bright"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface_container_high

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface_container_high"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface_container_highest

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface_container_highest"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface_container_low

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface_container_low"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface_container_lowest

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface_container_lowest"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface_dim

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface_dim"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_surface_variant

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "surface_variant"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_tertiary

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "tertiary"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_tertiary_container

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "tertiary_container"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_tertiary_fixed

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "tertiary_fixed"
            target: Config.md3
        }
        ColorAnimation {
            id: anim_tertiary_fixed_dim

            duration: Config.matugenTransitionDuration
            easing.type: Easing.OutCubic
            property: "tertiary_fixed_dim"
            target: Config.md3
        }
    }
    property FileView dconfUserFile: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Config.homeDir + "/.config") + "/dconf/user"
        printErrors: false
        watchChanges: true

        onFileChanged: themeServiceRoot.modeQueryDebounce.restart()
    }
    property string expectedSource: ""
    property int generationRetryCount: 0
    property Timer generationValidation: Timer {
        interval: 1200
        repeat: false

        onTriggered: {
            if (themeServiceRoot.expectedSource !== themeServiceRoot.validationSource || themeServiceRoot.colorMode !== themeServiceRoot.validationMode)
                return;
            if (themeServiceRoot.themeFileValid && themeServiceRoot.activeMode === themeServiceRoot.validationMode && themeServiceRoot.activeSource === themeServiceRoot.validationSource) {
                themeServiceRoot.generationRetryCount = 0;
                return;
            }
            if (themeServiceRoot.generationRetryCount < 1 && (Config.matugenEnabled || themeServiceRoot.validationForced)) {
                themeServiceRoot.generationRetryCount += 1;
                themeServiceRoot.pendingGenerationPath = themeServiceRoot.validationPath;
                themeServiceRoot.pendingGenerationMode = themeServiceRoot.validationMode;
                themeServiceRoot.pendingGenerationSource = themeServiceRoot.validationSource;
                themeServiceRoot.pendingGenerationForced = themeServiceRoot.validationForced;
                themeServiceRoot.startPendingGeneration();
                return;
            }
            console.warn("[ThemeService] Matugen did not produce the expected Quickshell theme snapshot");
        }
    }
    property Process generator: Process {
        onExited: (exitCode, exitStatus) => {
            var completedPath = themeServiceRoot.runningGenerationPath;
            var completedMode = themeServiceRoot.runningGenerationMode;
            var completedSource = themeServiceRoot.runningGenerationSource;
            var completedForced = themeServiceRoot.runningGenerationForced;
            themeServiceRoot.runningGenerationPath = "";
            themeServiceRoot.runningGenerationMode = "";
            themeServiceRoot.runningGenerationSource = "";
            themeServiceRoot.runningGenerationForced = false;
            if (themeServiceRoot.pendingGenerationPath) {
                themeServiceRoot.startPendingGeneration();
                return;
            }
            if (exitCode !== 0) {
                console.warn("[ThemeService] Matugen exited with code", exitCode);
            } else {
                themeServiceRoot.reloadTheme();
            }
            themeServiceRoot.validateGeneration(completedPath, completedMode, completedSource, completedForced);
        }
    }
    property Process gtkThemeSetter: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[ThemeService] Could not synchronize the GTK theme:", exitCode);
            if (themeServiceRoot.pendingGtkThemeMode !== "")
                themeServiceRoot.startGtkThemeSync();
        }
    }
    property bool hasAppliedTheme: false
    property string lastFileText: ""
    property Process modeQuery: Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]

        stdout: StdioCollector {
            onStreamFinished: themeServiceRoot.syncSystemMode(text, themeServiceRoot.modeResolved)
        }

        onExited: {
            if (themeServiceRoot.modeQueryPending) {
                themeServiceRoot.modeQueryPending = false;
                Qt.callLater(themeServiceRoot.requestModeQuery);
            }
        }
    }
    property Timer modeQueryDebounce: Timer {
        interval: 120
        repeat: false

        onTriggered: themeServiceRoot.requestModeQuery()
    }
    property bool modeQueryPending: false
    property Timer modeQueryRetry: Timer {
        interval: 5000
        repeat: false

        onTriggered: themeServiceRoot.requestModeQuery()
    }
    property bool modeResolved: false
    property bool pendingGenerationForced: false
    property string pendingGenerationMode: "dark"
    property string pendingGenerationPath: ""
    property string pendingGenerationSource: ""
    property string pendingGtkThemeMode: ""
    property bool runningGenerationForced: false
    property string runningGenerationMode: ""
    property string runningGenerationPath: ""
    property string runningGenerationSource: ""
    readonly property bool themeAvailable: themeFileValid && expectedSource !== "" && activeMode === colorMode && activeSource === expectedSource
    property FileView themeFile: FileView {
        blockLoading: true
        path: Config.quickshellDir + "/colors.json"
        watchChanges: true

        onFileChanged: reload()
        onLoadFailed: {
            themeServiceRoot.themeFileValid = false;
            themeServiceRoot.themeFileResolved = true;
        }
        onLoadedChanged: {
            if (loaded) {
                themeServiceRoot.applyTheme();
                themeServiceRoot.themeFileResolved = true;
            }
        }
        onTextChanged: {
            if (loaded)
                themeServiceRoot.applyTheme();
        }
    }
    property bool themeFileResolved: false
    property bool themeFileValid: false
    property bool validationForced: false
    property string validationMode: ""
    property string validationPath: ""
    property string validationSource: ""

    signal systemModeChanged(string mode)

    function applyColors(colors, animated) {
        if (!colors)
            return;

        activeColors = colors;

        // Always update palette and base16 instantly as they are not animated
        if (colors.palette) {
            Config.palette = colors.palette;
            Config.paletteChanged();
        }
        if (colors.base16) {
            Config.base16 = colors.base16;
            Config.base16Changed();
        }

        colorTransition.stop();
        if (!animated || !Config.matugenAnimateColors) {
            Config.updateMd3(colors);
            return;
        }

        if (colors.md3) {
            if (colors.md3.background)
                anim_background.to = colors.md3.background;
            if (colors.md3.error)
                anim_error.to = colors.md3.error;
            if (colors.md3.error_container)
                anim_error_container.to = colors.md3.error_container;
            if (colors.md3.inverse_on_surface)
                anim_inverse_on_surface.to = colors.md3.inverse_on_surface;
            if (colors.md3.inverse_primary)
                anim_inverse_primary.to = colors.md3.inverse_primary;
            if (colors.md3.inverse_surface)
                anim_inverse_surface.to = colors.md3.inverse_surface;
            if (colors.md3.on_background)
                anim_on_background.to = colors.md3.on_background;
            if (colors.md3.on_error)
                anim_on_error.to = colors.md3.on_error;
            if (colors.md3.on_error_container)
                anim_on_error_container.to = colors.md3.on_error_container;
            if (colors.md3.on_primary)
                anim_on_primary.to = colors.md3.on_primary;
            if (colors.md3.on_primary_container)
                anim_on_primary_container.to = colors.md3.on_primary_container;
            if (colors.md3.on_primary_fixed)
                anim_on_primary_fixed.to = colors.md3.on_primary_fixed;
            if (colors.md3.on_primary_fixed_variant)
                anim_on_primary_fixed_variant.to = colors.md3.on_primary_fixed_variant;
            if (colors.md3.on_secondary)
                anim_on_secondary.to = colors.md3.on_secondary;
            if (colors.md3.on_secondary_container)
                anim_on_secondary_container.to = colors.md3.on_secondary_container;
            if (colors.md3.on_secondary_fixed)
                anim_on_secondary_fixed.to = colors.md3.on_secondary_fixed;
            if (colors.md3.on_secondary_fixed_variant)
                anim_on_secondary_fixed_variant.to = colors.md3.on_secondary_fixed_variant;
            if (colors.md3.on_surface)
                anim_on_surface.to = colors.md3.on_surface;
            if (colors.md3.on_surface_variant)
                anim_on_surface_variant.to = colors.md3.on_surface_variant;
            if (colors.md3.on_tertiary)
                anim_on_tertiary.to = colors.md3.on_tertiary;
            if (colors.md3.on_tertiary_container)
                anim_on_tertiary_container.to = colors.md3.on_tertiary_container;
            if (colors.md3.on_tertiary_fixed)
                anim_on_tertiary_fixed.to = colors.md3.on_tertiary_fixed;
            if (colors.md3.on_tertiary_fixed_variant)
                anim_on_tertiary_fixed_variant.to = colors.md3.on_tertiary_fixed_variant;
            if (colors.md3.outline)
                anim_outline.to = colors.md3.outline;
            if (colors.md3.outline_variant)
                anim_outline_variant.to = colors.md3.outline_variant;
            if (colors.md3.primary)
                anim_primary.to = colors.md3.primary;
            if (colors.md3.primary_container)
                anim_primary_container.to = colors.md3.primary_container;
            if (colors.md3.primary_fixed)
                anim_primary_fixed.to = colors.md3.primary_fixed;
            if (colors.md3.primary_fixed_dim)
                anim_primary_fixed_dim.to = colors.md3.primary_fixed_dim;
            if (colors.md3.scrim)
                anim_scrim.to = colors.md3.scrim;
            if (colors.md3.secondary)
                anim_secondary.to = colors.md3.secondary;
            if (colors.md3.secondary_container)
                anim_secondary_container.to = colors.md3.secondary_container;
            if (colors.md3.secondary_fixed)
                anim_secondary_fixed.to = colors.md3.secondary_fixed;
            if (colors.md3.secondary_fixed_dim)
                anim_secondary_fixed_dim.to = colors.md3.secondary_fixed_dim;
            if (colors.md3.shadow)
                anim_shadow.to = colors.md3.shadow;
            if (colors.md3.surface)
                anim_surface.to = colors.md3.surface;
            if (colors.md3.surface_bright)
                anim_surface_bright.to = colors.md3.surface_bright;
            if (colors.md3.surface_container)
                anim_surface_container.to = colors.md3.surface_container;
            if (colors.md3.surface_container_high)
                anim_surface_container_high.to = colors.md3.surface_container_high;
            if (colors.md3.surface_container_highest)
                anim_surface_container_highest.to = colors.md3.surface_container_highest;
            if (colors.md3.surface_container_low)
                anim_surface_container_low.to = colors.md3.surface_container_low;
            if (colors.md3.surface_container_lowest)
                anim_surface_container_lowest.to = colors.md3.surface_container_lowest;
            if (colors.md3.surface_dim)
                anim_surface_dim.to = colors.md3.surface_dim;
            if (colors.md3.surface_variant)
                anim_surface_variant.to = colors.md3.surface_variant;
            if (colors.md3.tertiary)
                anim_tertiary.to = colors.md3.tertiary;
            if (colors.md3.tertiary_container)
                anim_tertiary_container.to = colors.md3.tertiary_container;
            if (colors.md3.tertiary_fixed)
                anim_tertiary_fixed.to = colors.md3.tertiary_fixed;
            if (colors.md3.tertiary_fixed_dim)
                anim_tertiary_fixed_dim.to = colors.md3.tertiary_fixed_dim;
            colorTransition.start();
        }
    }
    function applyTheme() {
        if (!themeFile.loaded)
            return;
        // When a newer request is already queued, the file watcher may be
        // observing output from the superseded Matugen process. Wait for the
        // latest job instead of briefly applying stale colours.
        if (generator.running && pendingGenerationPath)
            return;
        var output = themeFile.text().trim();
        if (output === "")
            return;
        if (output === lastFileText) {
            // A temporary partial write may have marked the file invalid. If
            // the last known-good snapshot is restored byte-for-byte, restore
            // its validity without replaying the same color animation.
            themeFileValid = activeColors !== null;
            return;
        }
        try {
            var colors = JSON.parse(output);
            if (modeResolved && (colors.mode === "light" || colors.mode === "dark") && colors.mode !== colorMode) {
                themeFileValid = false;
                return;
            }
            var snapshotSource = String(colors.source || "");
            if (expectedSource !== "" && snapshotSource !== expectedSource) {
                themeFileValid = false;
                return;
            }
            applyColors(colors, hasAppliedTheme);
            activeMode = colors.mode === "light" || colors.mode === "dark" ? colors.mode : "";
            activeSource = snapshotSource;
            lastFileText = output;
            hasAppliedTheme = true;
            themeFileValid = true;
        } catch (error) {
            themeFileValid = false;
            console.warn("[ThemeService] Invalid colors.json:", error);
        }
    }
    function generate(path, mode, forceModeVariant, sourceKey) {
        if (sourceKey !== undefined && sourceKey !== null)
            setExpectedSource(sourceKey);
        if (!path || (!Config.matugenEnabled && forceModeVariant !== true))
            return;

        colorMode = normalizeMode(mode === undefined ? colorMode : mode);
        pendingGenerationMode = colorMode;
        pendingGenerationPath = path;
        pendingGenerationSource = expectedSource;
        pendingGenerationForced = forceModeVariant === true;
        generationValidation.stop();
        generationRetryCount = 0;
        if (!generator.running)
            startPendingGeneration();
    }
    function normalizeMode(mode) {
        if (mode === "light" || mode === "dark")
            return mode;
        return colorMode === "light" || colorMode === "dark" ? colorMode : "dark";
    }
    function reloadTheme() {
        themeFile.reload();
    }
    function requestGtkThemeSync(mode) {
        pendingGtkThemeMode = normalizeMode(mode);
        if (!gtkThemeSetter.running)
            startGtkThemeSync();
    }
    function requestModeQuery() {
        if (modeQuery.running) {
            modeQueryPending = true;
            return;
        }
        modeQuery.running = true;
    }
    function setExpectedSource(sourceKey) {
        expectedSource = String(sourceKey || "");
    }
    function startGtkThemeSync() {
        if (gtkThemeSetter.running || pendingGtkThemeMode === "")
            return;
        var mode = pendingGtkThemeMode;
        pendingGtkThemeMode = "";
        gtkThemeSetter.command = ["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", mode === "dark" ? "adw-gtk3-dark" : "adw-gtk3"];
        gtkThemeSetter.running = true;
    }
    function startPendingGeneration() {
        if (!pendingGenerationPath || generator.running)
            return;

        var path = pendingGenerationPath;
        var mode = pendingGenerationMode;
        var source = pendingGenerationSource;
        var forced = pendingGenerationForced;
        pendingGenerationPath = "";
        pendingGenerationForced = false;
        var matugenConfig = Config.dotfilesDir + "/.config/matugen/config.toml";
        var prepareGtk = Config.dotfilesDir + "/.config/matugen/scripts/prepare-gtk-runtime.sh";
        var matugenRunner = Config.quickshellDir + "/scripts/matugen-auto-scheme.sh";
        var metadata = JSON.stringify({
            "theme_source": source
        });
        generator.command = ["sh", "-c", "\"$1\" && exec \"$2\" --config \"$3\" --mode \"$5\" --metadata-json \"$6\" \"$4\"", "wallpaper-theme", prepareGtk, matugenRunner, matugenConfig, path, mode, metadata];
        runningGenerationPath = path;
        runningGenerationMode = mode;
        runningGenerationSource = source;
        runningGenerationForced = forced;
        generator.running = true;
    }
    function syncSystemMode(value, notifyChange) {
        var text = String(value || "");
        if (text.trim() === "") {
            console.warn("[ThemeService] Could not read the system color mode; retrying");
            modeQueryRetry.restart();
            return;
        }
        var mode = text.indexOf("prefer-dark") >= 0 ? "dark" : text.indexOf("prefer-light") >= 0 || text.indexOf("default") >= 0 ? "light" : normalizeMode(colorMode);
        var wasResolved = modeResolved;
        var changed = colorMode !== mode;
        modeQueryRetry.stop();
        colorMode = mode;
        modeResolved = true;
        if (!wasResolved || changed)
            requestGtkThemeSync(mode);
        if (changed && notifyChange)
            systemModeChanged(mode);
    }
    function updateMode(mode, notifyChange) {
        var normalized = normalizeMode(mode);
        var changed = colorMode !== normalized;
        colorMode = normalized;
        modeResolved = true;
        requestGtkThemeSync(normalized);
        if (notifyChange && (changed || activeMode !== normalized))
            systemModeChanged(normalized);
    }
    function validateGeneration(path, mode, source, forced) {
        if (!path || !source)
            return;
        validationPath = path;
        validationMode = mode;
        validationSource = source;
        validationForced = forced;
        generationValidation.restart();
    }

    Component.onCompleted: {
        applyTheme();
        requestModeQuery();
    }
}
