pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property int minimumSidePanelWidth: 360
    readonly property int preferredSidePanelWidth: 650
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
    function sidePanelWidth(viewWidth) {
        return fitWithMargins(preferredSidePanelWidth, viewWidth, 10, minimumSidePanelWidth);
    }
}
