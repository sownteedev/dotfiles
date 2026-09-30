pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property int compactMaxHeight: 599
    // Material 3 window size classes. Keep width and height independent so a
    // short, wide window does not accidentally inherit a phone-like layout.
    readonly property int compactMaxWidth: 599
    readonly property int expandedMaxWidth: 1199
    readonly property int largeMaxWidth: 1599
    readonly property int mediumMaxWidth: 839
    readonly property int minimumSidePanelWidth: 360
    readonly property int preferredSidePanelWidth: 650
    readonly property int settingsCompactContentWidth: 760
    readonly property int settingsMaximumContentWidth: 1040
    readonly property int spacingL: 16
    readonly property int spacingM: 12
    readonly property int spacingS: 8
    readonly property int spacingXL: 24
    readonly property int spacingXS: 4

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }
    function columnsFor(width, minimumCellWidth, maximumColumns, minimumColumns, spacing) {
        const safeSpacing = Math.max(0, spacing || 0);
        const availableColumns = Math.floor((Math.max(0, width) + safeSpacing) / (Math.max(1, minimumCellWidth) + safeSpacing));
        return clamp(availableColumns, Math.max(1, minimumColumns), Math.max(1, maximumColumns));
    }
    function constrained(availableWidth, availableHeight, preferredWidth, preferredHeight) {
        return availableWidth < preferredWidth || (preferredHeight > 0 && availableHeight < preferredHeight);
    }
    function fit(preferred, available, minimum) {
        const safeAvailable = Math.max(0, available);
        if (safeAvailable < minimum)
            return safeAvailable;
        return Math.min(preferred, safeAvailable);
    }
    function fitWithMargins(preferred, viewport, margin, minimum) {
        return fit(preferred, Math.max(0, viewport - Math.max(0, margin) * 2), minimum);
    }
    function heightClass(value) {
        return Math.max(0, Number(value) || 0) <= compactMaxHeight ? "compact" : "expanded";
    }
    function isCompactHeight(value) {
        return heightClass(value) === "compact";
    }
    function isCompactWidth(value) {
        return widthClass(value) === "compact";
    }
    function isMediumWidth(value) {
        return widthClass(value) === "medium";
    }
    function sidePanelWidth(viewWidth) {
        return fitWithMargins(preferredSidePanelWidth, viewWidth, 10, minimumSidePanelWidth);
    }
    function widthClass(value) {
        const width = Math.max(0, Number(value) || 0);
        if (width <= compactMaxWidth)
            return "compact";
        if (width <= mediumMaxWidth)
            return "medium";
        if (width <= expandedMaxWidth)
            return "expanded";
        if (width <= largeMaxWidth)
            return "large";
        return "extraLarge";
    }
}
