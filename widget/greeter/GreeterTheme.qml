pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property color background: "#131313"
    property color backgroundText: "#e2e2e2"
    property color error: "#ffb4ab"
    property color errorContainer: "#93000a"
    property color errorContainerText: "#ffdad6"
    property color errorText: "#690005"
    property bool isDark: true
    property color outline: "#918f99"
    property color outlineVariant: "#494751"
    property color primary: "#c5c2ff"
    property color primaryContainer: "#414f91"
    property color primaryContainerText: "#dedfff"
    property color primaryText: "#28265b"
    property bool ready: false
    property color scrim: "#000000"
    property color secondary: "#c5c4d8"
    property color secondaryText: "#2e2f42"
    property color shadow: "#000000"
    property string source: ""
    property color surface: "#131313"
    property color surfaceBright: "#393939"
    property color surfaceContainer: "#1f1f1f"
    property color surfaceContainerHigh: "#2a2a2a"
    property color surfaceContainerHighest: "#353535"
    property color surfaceContainerLow: "#1b1b1b"
    property color surfaceContainerLowest: "#0e0e0e"
    property color surfaceText: "#f0ecf4"
    property color surfaceVariantText: "#c9c5d0"
    property color tertiary: "#a8e6b1"
    property FileView themeFile: FileView {
        blockLoading: true
        path: root.themePath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoadedChanged: {
            if (loaded)
                root.applyTheme(text());
        }
        onTextChanged: {
            if (loaded)
                root.applyTheme(text());
        }
    }
    readonly property string themePath: Quickshell.env("GREETD_THEME_PATH") || "/var/lib/quickshell-greeter/colors.json"

    function applyTheme(rawText) {
        var text = String(rawText || "").trim();
        if (text === "")
            return;

        try {
            var snapshot = JSON.parse(text);
            if (!snapshot || !snapshot.md3)
                return;

            var md3 = snapshot.md3;
            background = colorValue(md3.background, background);
            error = colorValue(md3.error, error);
            errorContainer = colorValue(md3.error_container, errorContainer);
            backgroundText = colorValue(md3.on_background, backgroundText);
            errorText = colorValue(md3.on_error, errorText);
            errorContainerText = colorValue(md3.on_error_container, errorContainerText);
            primaryText = colorValue(md3.on_primary, primaryText);
            primaryContainerText = colorValue(md3.on_primary_container, primaryContainerText);
            secondaryText = colorValue(md3.on_secondary, secondaryText);
            surfaceText = colorValue(md3.on_surface, surfaceText);
            surfaceVariantText = colorValue(md3.on_surface_variant, surfaceVariantText);
            outline = colorValue(md3.outline, outline);
            outlineVariant = colorValue(md3.outline_variant, outlineVariant);
            primary = colorValue(md3.primary, primary);
            primaryContainer = colorValue(md3.primary_container, primaryContainer);
            scrim = colorValue(md3.scrim, scrim);
            secondary = colorValue(md3.secondary, secondary);
            shadow = colorValue(md3.shadow, shadow);
            surface = colorValue(md3.surface, surface);
            surfaceBright = colorValue(md3.surface_bright, surfaceBright);
            surfaceContainer = colorValue(md3.surface_container, surfaceContainer);
            surfaceContainerHigh = colorValue(md3.surface_container_high, surfaceContainerHigh);
            surfaceContainerHighest = colorValue(md3.surface_container_highest, surfaceContainerHighest);
            surfaceContainerLow = colorValue(md3.surface_container_low, surfaceContainerLow);
            surfaceContainerLowest = colorValue(md3.surface_container_lowest, surfaceContainerLowest);
            tertiary = colorValue(md3.tertiary, tertiary);
            isDark = snapshot.mode !== "light";
            source = String(snapshot.source || "");
            ready = true;
        } catch (errorMessage) {
            console.warn("[GreeterTheme] Invalid theme snapshot:", errorMessage);
        }
    }
    function colorValue(value, fallback) {
        return typeof value === "string" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(value) ? value : fallback;
    }
    function withAlpha(value, alpha) {
        return Qt.rgba(value.r, value.g, value.b, Math.max(0, Math.min(1, alpha)));
    }
}
