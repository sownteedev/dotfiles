pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: themeServiceRoot

    property var activeColors: null
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
    property Process generator: Process {
        onExited: (exitCode, exitStatus) => {
            if (themeServiceRoot.pendingGenerationPath) {
                themeServiceRoot.startPendingGeneration();
                return;
            }
            if (exitCode !== 0) {
                console.warn("[ThemeService] Matugen exited with code", exitCode);
                return;
            }
            themeServiceRoot.reloadTheme();
        }
    }
    property bool hasAppliedTheme: false
    property string lastFileText: ""
    property string pendingGenerationPath: ""
    readonly property bool themeAvailable: themeFileValid
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
        var output = themeFile.text().trim();
        if (output === "" || output === lastFileText)
            return;
        try {
            applyColors(JSON.parse(output), hasAppliedTheme);
            lastFileText = output;
            hasAppliedTheme = true;
            themeFileValid = true;
        } catch (error) {
            themeFileValid = false;
            console.warn("[ThemeService] Invalid colors.json:", error);
        }
    }
    function generate(path) {
        if (!path || !Config.matugenEnabled)
            return;

        pendingGenerationPath = path;
        if (!generator.running)
            startPendingGeneration();
    }
    function reloadTheme() {
        themeFile.reload();
    }
    function startPendingGeneration() {
        if (!pendingGenerationPath || generator.running)
            return;

        var path = pendingGenerationPath;
        pendingGenerationPath = "";
        var matugenConfig = Config.dotfilesDir + "/.config/matugen/config.toml";
        var prepareGtk = Config.dotfilesDir + "/.config/matugen/scripts/prepare-gtk-runtime.sh";
        var matugenRunner = Config.quickshellDir + "/scripts/matugen-auto-scheme.sh";
        generator.command = ["sh", "-c", "\"$1\" && exec \"$2\" --config \"$3\" \"$4\"", "wallpaper-theme", prepareGtk, matugenRunner, matugenConfig, path];
        generator.running = true;
    }

    Component.onCompleted: applyTheme()
}
