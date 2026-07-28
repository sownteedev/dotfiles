import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../../../" // for Config
import "../../../../components"
import "../../../../service"

Item {
    id: displayPageRoot

    // Dropdown popup state
    property string activeDropdown: ""

    // Array of all connected outputs from Niri
    readonly property var allOutputs: DisplayService.outputs
    readonly property real brightnessValue: BrightnessService.percent

    // Draft coordinate management for screen rearranging
    property var draftPositions: ({})
    property bool hasChanges: false
    readonly property string internalHardwareId: DisplayService.internalHardwareId

    // KDL extra features (VRR, focus-at-startup)
    readonly property var kdlOptions: DisplayService.kdlOptions
    property var popupModel: []
    property bool popupOpen: false
    property bool popupOpenAbove: false
    property real popupWidth: 0
    property real popupX: 0
    property real popupY: 0

    // Selected output for configuration
    property string selectedOutputName: ""

    // Dropdown target output name (for sed queries)
    property string targetOutput: ""

    function applyDrafts() {
        DisplayService.applyPositions(draftPositions);
        hasChanges = false;
    }
    function getKdlOption(outputName, optionName) {
        return DisplayService.optionEnabled(outputName, optionName);
    }
    function getOutputsToUpdate(output) {
        return DisplayService.outputsToUpdate(output);
    }
    function getTransformLabel(transformVal) {
        if (transformVal === "Normal" || transformVal === "normal")
            return "Landscape";
        if (transformVal === "270")
            return "Portrait";
        if (transformVal === "180")
            return "Landscape (Flipped)";
        if (transformVal === "90")
            return "Portrait (Flipped)";
        return transformVal;
    }
    function handleMonitorDrop(draggedIndex, currentVisualX, currentVisualY, visualW, visualH) {
        if (displayPageRoot.allOutputs.length < 2)
            return;

        var draggedNotif = displayPageRoot.allOutputs[draggedIndex];
        var cx = currentVisualX + visualW / 2;
        var cy = currentVisualY + visualH / 2;

        var closestIndex = -1;
        var minDistance = 999999;

        for (var i = 0; i < displayPageRoot.allOutputs.length; i++) {
            if (i === draggedIndex)
                continue;
            var out = displayPageRoot.allOutputs[i];

            var log = out.logical || {
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            };

            // Calculate base position using draft coordinates
            var dx = log.x;
            var dy = log.y;
            if (displayPageRoot.draftPositions && displayPageRoot.draftPositions[out.name]) {
                dx = displayPageRoot.draftPositions[out.name].x;
                dy = displayPageRoot.draftPositions[out.name].y;
            }

            var baseX = (layoutArea.width - (layoutArea.totalW * layoutArea.scaleFactor)) / 2 + (dx - layoutArea.minX) * layoutArea.scaleFactor;
            var baseY = (layoutArea.height - (layoutArea.totalH * layoutArea.scaleFactor)) / 2 + (dy - layoutArea.minY) * layoutArea.scaleFactor;
            var w = log.width * layoutArea.scaleFactor;
            var h = log.height * layoutArea.scaleFactor;

            var ax = baseX + w / 2;
            var ay = baseY + h / 2;

            var dist = Math.sqrt(Math.pow(cx - ax, 2) + Math.pow(cy - ay, 2));
            if (dist < minDistance) {
                minDistance = dist;
                closestIndex = i;
            }
        }

        if (closestIndex === -1)
            return;

        var anchorOut = displayPageRoot.allOutputs[closestIndex];
        var anchorLog = anchorOut.logical || {
            x: 0,
            y: 0,
            width: 1920,
            height: 1080
        };

        // Calculate anchor base position using draft coordinates
        var adx = anchorLog.x;
        var ady = anchorLog.y;
        if (displayPageRoot.draftPositions && displayPageRoot.draftPositions[anchorOut.name]) {
            adx = displayPageRoot.draftPositions[anchorOut.name].x;
            ady = displayPageRoot.draftPositions[anchorOut.name].y;
        }

        var anchorBaseX = (layoutArea.width - (layoutArea.totalW * layoutArea.scaleFactor)) / 2 + (adx - layoutArea.minX) * layoutArea.scaleFactor;
        var anchorBaseY = (layoutArea.height - (layoutArea.totalH * layoutArea.scaleFactor)) / 2 + (ady - layoutArea.minY) * layoutArea.scaleFactor;
        var anchorW = anchorLog.width * layoutArea.scaleFactor;
        var anchorH = anchorLog.height * layoutArea.scaleFactor;

        var ax = anchorBaseX + anchorW / 2;
        var ay = anchorBaseY + anchorH / 2;

        var dx = cx - ax;
        var dy = cy - ay;

        var newX = adx;
        var newY = ady;

        var draggedLog = draggedNotif.logical || {
            x: 0,
            y: 0,
            width: 1920,
            height: 1080
        };

        if (Math.abs(dx) / anchorW > Math.abs(dy) / anchorH) {
            if (dx > 0) {
                newX = adx + anchorLog.width;
                newY = ady;
            } else {
                newX = adx - draggedLog.width;
                newY = ady;
            }
        } else {
            if (dy > 0) {
                newX = adx;
                newY = ady + anchorLog.height;
            } else {
                newX = adx;
                newY = ady - draggedLog.height;
            }
        }

        // Update draft coordinate locally (no instant save to KDL)
        if (displayPageRoot.draftPositions && displayPageRoot.draftPositions[draggedNotif.name]) {
            displayPageRoot.draftPositions[draggedNotif.name].x = newX;
            displayPageRoot.draftPositions[draggedNotif.name].y = newY;

            // Re-assign object to trigger QML property bindings update
            displayPageRoot.draftPositions = Object.assign({}, displayPageRoot.draftPositions);
            displayPageRoot.hasChanges = true;
            layoutArea.updateLayoutGeometry();
        }
    }
    function openPopup(row, activeDropName, model) {
        var coords = row.mapToItem(displayPageRoot, 0, 0);
        displayPageRoot.popupModel = model;
        displayPageRoot.activeDropdown = activeDropName;
        displayPageRoot.targetOutput = displayPageRoot.selectedOutputName;

        var pHeight = model.length * 40 + 16;
        var targetY = coords.y + row.height + 8;
        if (targetY + pHeight > displayPageRoot.height) {
            displayPageRoot.popupY = coords.y - pHeight - 8;
            displayPageRoot.popupOpenAbove = true;
        } else {
            displayPageRoot.popupY = targetY;
            displayPageRoot.popupOpenAbove = false;
        }
        displayPageRoot.popupX = coords.x;
        displayPageRoot.popupWidth = row.width;
        displayPageRoot.popupOpen = true;
    }
    function outputByName(name) {
        for (var i = 0; i < allOutputs.length; ++i) {
            if (allOutputs[i].name === name)
                return allOutputs[i];
        }
        return null;
    }
    function popupItemChecked(item) {
        var output = outputByName(targetOutput);
        if (!output || !item)
            return false;
        if (activeDropdown === "transform") {
            var transform = output.logical ? output.logical.transform : "Normal";
            return transform.toLowerCase() === item.value.toLowerCase() || (transform === "Normal" && item.value === "normal");
        }
        if (activeDropdown === "scale") {
            var scale = output.logical ? output.logical.scale : 1;
            return Math.abs(scale - parseFloat(item.value)) < 0.05;
        }
        if (activeDropdown === "resolution") {
            var resolution = "0x0";
            if (output.current_mode >= 0 && output.current_mode < output.modes.length) {
                var mode = output.modes[output.current_mode];
                resolution = mode.width + "x" + mode.height;
            }
            return resolution === item.value;
        }
        if (activeDropdown === "refreshRate") {
            var refreshRate = 0;
            if (output.current_mode >= 0 && output.current_mode < output.modes.length)
                refreshRate = output.modes[output.current_mode].refresh_rate / 1000;
            return Math.abs(refreshRate - parseFloat(item.value)) < 0.05;
        }
        return false;
    }
    function refreshAll() {
        DisplayService.refresh();
    }
    function resetDrafts() {
        var drafts = {};
        for (var i = 0; i < displayPageRoot.allOutputs.length; i++) {
            var out = displayPageRoot.allOutputs[i];
            drafts[out.name] = {
                x: out.logical ? out.logical.x : 0,
                y: out.logical ? out.logical.y : 0
            };
        }
        displayPageRoot.draftPositions = drafts;
        displayPageRoot.hasChanges = false;
    }
    function selectPopupItem(item) {
        if (!item)
            return;
        var output = outputByName(targetOutput);
        var value = item.value;
        if (activeDropdown === "transform" || activeDropdown === "scale") {
            updateConfig(targetOutput, activeDropdown, value);
        } else if (activeDropdown === "resolution") {
            var dimensions = value.split("x");
            var rate = 60;
            if (output && output.current_mode >= 0 && output.current_mode < output.modes.length)
                rate = output.modes[output.current_mode].refresh_rate / 1000;
            updateConfig(targetOutput, "mode", dimensions[0] + "x" + dimensions[1] + "@" + rate.toFixed(3));
        } else if (activeDropdown === "refreshRate") {
            var width = 1920;
            var height = 1080;
            if (output && output.current_mode >= 0 && output.current_mode < output.modes.length) {
                width = output.modes[output.current_mode].width;
                height = output.modes[output.current_mode].height;
            }
            updateConfig(targetOutput, "mode", width + "x" + height + "@" + parseFloat(value).toFixed(3));
        }
        popupOpen = false;
    }
    function toggleKdlOption(output, option, enable) {
        DisplayService.toggleOption(output, option, enable);
    }
    function updateConfig(output, field, value) {
        DisplayService.updateConfig(output, field, value);
    }

    anchors.fill: parent

    onAllOutputsChanged: {
        if (allOutputs.length === 0)
            return;
        var found = false;
        for (var i = 0; i < allOutputs.length; ++i) {
            if (allOutputs[i].name === selectedOutputName) {
                found = true;
                break;
            }
        }
        if (!found)
            selectedOutputName = allOutputs[0].name;
        resetDrafts();
    }
    onVisibleChanged: {
        if (visible) {
            refreshAll();
        }
    }

    SettingsPageTransition {
        panelActive: controlRightWindow.active
        targetItem: displayPageRoot
    }
    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: contentLayout.implicitHeight
        contentWidth: width
        interactive: !displayPageRoot.popupOpen

        ColumnLayout {
            id: contentLayout

            spacing: 24
            width: parent.width

            // 1. Brightness Slider Card
            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.on_surface, 0.06)
                border.width: 1
                color: Config.md3.surface_container
                height: 60
                radius: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // Icon
                    Image {
                        fillMode: Image.PreserveAspectFit
                        height: 25
                        layer.enabled: true
                        source: "image://icon/display-brightness-symbolic"
                        sourceSize.height: 25
                        sourceSize.width: 25
                        width: 25

                        layer.effect: ColorOverlay {
                            color: Config.md3.primary
                        }
                    }
                    CustomVolumeSlider {
                        highlightColor: Config.md3.primary
                        value: BrightnessService.value

                        onSliderMoved: value => BrightnessService.setValue(value)
                    }
                }
            }

            // 2. Night Light temperature control
            NightLightControl {
                Layout.fillWidth: true
                nightLightEnabled: DisplayService.nightlightEnabled
                temperature: DisplayService.nightlightTemperature

                onTemperatureRequested: temperature => DisplayService.setNightlightTemperature(temperature)
                onToggleRequested: enabled => DisplayService.setNightlightEnabled(enabled)
            }

            // 3. Dark Mode toggle
            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.on_surface, 0.06)
                border.width: 1
                clip: true
                color: Config.md3.surface_container
                height: 68
                radius: 14

                Item {
                    anchors.fill: parent

                    Rectangle {
                        id: darkIconBackground

                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.alpha(Config.md3.on_surface, 0.16)
                        height: 40
                        radius: 20
                        width: 40

                        IconImage {
                            anchors.centerIn: parent
                            height: 22
                            layer.enabled: true
                            source: Quickshell.iconPath("dark-mode-symbolic")
                            width: 22

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface_variant
                            }
                        }
                    }
                    Column {
                        anchors.left: darkIconBackground.right
                        anchors.leftMargin: 12
                        anchors.right: darkModeSwitch.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                            text: "Dark Mode"
                            width: parent.width
                        }
                        Text {
                            color: Config.md3.on_surface_variant
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            text: "Night mode for apps and system UI"
                            width: parent.width
                        }
                    }
                    ToggleSwitch {
                        id: darkModeSwitch

                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        checked: DisplayService.darkmodeEnabled
                        height: 26
                        thumbCheckedColor: Config.md3.surface_container
                        thumbMargin: 3
                        thumbUncheckedColor: Config.md3.on_surface
                        width: 48

                        onToggled: checked => DisplayService.setDarkmodeEnabled(checked)
                    }
                }
            }

            // 3. Visual Monitor Layout Diagram
            Rectangle {
                id: monitorLayoutContainer

                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.on_surface, 0.06)
                border.width: 1
                color: Config.md3.surface_container
                height: 200
                radius: 12
                visible: displayPageRoot.allOutputs.length > 0

                // Label in the top left
                Text {
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    text: "Identify Displays (Drag and drop to rearrange)"
                    x: 12
                    y: 8
                }

                // Inner area containing layouted rectangles
                Item {
                    id: layoutArea

                    property real minX: 0
                    property real minY: 0
                    property real scaleFactor: 1.0
                    property real totalH: 1

                    // Coordinates variables
                    property real totalW: 1

                    function updateLayoutGeometry() {
                        if (displayPageRoot.allOutputs.length === 0)
                            return;

                        var min_x = 999999;
                        var max_x = -999999;
                        var min_y = 999999;
                        var max_y = -999999;

                        for (var i = 0; i < displayPageRoot.allOutputs.length; i++) {
                            var out = displayPageRoot.allOutputs[i];
                            var log = out.logical || {
                                x: 0,
                                y: 0,
                                width: 1920,
                                height: 1080
                            };

                            // Use draft coordinates if available
                            var dx = log.x;
                            var dy = log.y;
                            if (displayPageRoot.draftPositions && displayPageRoot.draftPositions[out.name]) {
                                dx = displayPageRoot.draftPositions[out.name].x;
                                dy = displayPageRoot.draftPositions[out.name].y;
                            }

                            var x1 = dx;
                            var y1 = dy;
                            var x2 = dx + log.width;
                            var y2 = dy + log.height;

                            if (x1 < min_x)
                                min_x = x1;
                            if (x2 > max_x)
                                max_x = x2;
                            if (y1 < min_y)
                                min_y = y1;
                            if (y2 > max_y)
                                max_y = y2;
                        }

                        var w = max_x - min_x;
                        var h = max_y - min_y;
                        if (w <= 0)
                            w = 1;
                        if (h <= 0)
                            h = 1;

                        minX = min_x;
                        minY = min_y;
                        totalW = w;
                        totalH = h;

                        var sX = layoutArea.width / w;
                        var sY = layoutArea.height / h;
                        scaleFactor = Math.min(sX, sY) * 0.9;
                    }

                    anchors.bottomMargin: 16
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    anchors.topMargin: 28

                    onHeightChanged: updateLayoutGeometry()
                    onWidthChanged: updateLayoutGeometry()

                    Connections {
                        function onAllOutputsChanged() {
                            layoutArea.updateLayoutGeometry();
                        }

                        target: displayPageRoot
                    }
                    Repeater {
                        model: displayPageRoot.allOutputs

                        delegate: Rectangle {
                            id: monitorRect

                            // Base positioning (centered + scaled draft/logical offset)
                            property real baseX: {
                                var dx = log.x;
                                if (displayPageRoot.draftPositions && displayPageRoot.draftPositions[modelData.name]) {
                                    dx = displayPageRoot.draftPositions[modelData.name].x;
                                }
                                return (layoutArea.width - (layoutArea.totalW * layoutArea.scaleFactor)) / 2 + (dx - layoutArea.minX) * layoutArea.scaleFactor;
                            }
                            property real baseY: {
                                var dy = log.y;
                                if (displayPageRoot.draftPositions && displayPageRoot.draftPositions[modelData.name]) {
                                    dy = displayPageRoot.draftPositions[modelData.name].y;
                                }
                                return (layoutArea.height - (layoutArea.totalH * layoutArea.scaleFactor)) / 2 + (dy - layoutArea.minY) * layoutArea.scaleFactor;
                            }
                            property real dragX: 0
                            property real dragY: 0
                            property bool isDragging: false
                            property bool isSelected: displayPageRoot.selectedOutputName === modelData.name
                            property var log: modelData.logical || {
                                x: 0,
                                y: 0,
                                width: 1920,
                                height: 1080
                            }
                            property real startX: 0
                            property real startY: 0

                            border.color: isDragging || isSelected ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.15)
                            border.width: isDragging || isSelected ? 2 : 1
                            color: isDragging ? Config.alpha(Config.md3.primary, 0.3) : (isSelected ? Config.alpha(Config.md3.primary, 0.15) : Config.md3.surface_container_high)
                            height: log.height * layoutArea.scaleFactor
                            radius: 6

                            // Visual feedback scale on drag
                            scale: isDragging ? 1.05 : 1.0
                            width: log.width * layoutArea.scaleFactor
                            x: baseX + dragX
                            y: baseY + dragY
                            z: isDragging ? 10 : 1

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                }
                            }

                            // Monitor index label
                            Text {
                                anchors.centerIn: parent
                                color: monitorRect.isSelected ? Config.md3.primary : Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.pixelSize: parent.height > 40 ? 24 : 16
                                font.weight: Font.Bold
                                text: (index + 1).toString()
                            }

                            // Sub-label showing monitor name
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: monitorRect.isSelected ? Config.md3.on_surface : Config.md3.outline
                                font.family: Config.fontName
                                font.pixelSize: 12
                                text: modelData.name
                                visible: parent.height > 50
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: monitorRect.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                onPositionChanged: mouse => {
                                    if (monitorRect.isDragging) {
                                        monitorRect.dragX += mouse.x - monitorRect.startX;
                                        monitorRect.dragY += mouse.y - monitorRect.startY;
                                    }
                                }
                                onPressed: mouse => {
                                    monitorRect.isDragging = true;
                                    monitorRect.startX = mouse.x;
                                    monitorRect.startY = mouse.y;
                                    displayPageRoot.selectedOutputName = modelData.name;
                                }
                                onReleased: {
                                    if (monitorRect.isDragging) {
                                        monitorRect.isDragging = false;
                                        displayPageRoot.handleMonitorDrop(index, monitorRect.x, monitorRect.y, monitorRect.width, monitorRect.height);
                                        monitorRect.dragX = 0;
                                        monitorRect.dragY = 0;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Apply / Reset Draft Positions Buttons Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: displayPageRoot.hasChanges

                Item {
                    Layout.fillWidth: true
                }

                // Reset Button
                Rectangle {
                    border.color: Config.alpha(Config.md3.on_surface, 0.15)
                    border.width: 1
                    color: "transparent"
                    height: 32
                    radius: 8
                    width: 90

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: "Reset"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            displayPageRoot.resetDrafts();
                        }
                    }
                }

                // Apply Button
                Rectangle {
                    color: Config.md3.primary
                    height: 32
                    radius: 8
                    width: 100

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        text: "Apply"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            displayPageRoot.applyDrafts();
                        }
                    }
                }
            }

            // 4. Output Configuration Card for selected display
            ColumnLayout {
                id: activeOutputCard

                // Compute output data for selected display
                property var activeOutputData: {
                    for (var i = 0; i < displayPageRoot.allOutputs.length; i++) {
                        if (displayPageRoot.allOutputs[i].name === displayPageRoot.selectedOutputName) {
                            return displayPageRoot.allOutputs[i];
                        }
                    }
                    return null;
                }

                Layout.fillWidth: true
                spacing: 8
                visible: displayPageRoot.selectedOutputName !== ""

                ColumnLayout {
                    spacing: 2

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        text: "Display Configuration (" + displayPageRoot.selectedOutputName + ")"
                    }
                    Text {
                        color: Config.md3.outline
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        text: {
                            var outData = activeOutputCard.activeOutputData;
                            if (!outData)
                                return "";
                            var make = outData.make || "Generic";
                            var modelName = outData.model || "";
                            var sizeStr = "";
                            if (outData.physical_size && outData.physical_size.length === 2) {
                                sizeStr = " • " + outData.physical_size[0] + " × " + outData.physical_size[1] + " mm";
                            }
                            return make + (modelName ? " " + modelName : "") + sizeStr;
                        }
                        visible: text !== ""
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    border.color: Config.alpha(Config.md3.on_surface, 0.06)
                    border.width: 1
                    color: Config.md3.surface_container
                    height: 330
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // 4.1 Orientation
                        MouseArea {
                            id: orientRow

                            Layout.fillWidth: true
                            height: 55
                            hoverEnabled: true

                            onClicked: {
                                displayPageRoot.openPopup(orientRow, "transform", [
                                    {
                                        label: "Landscape",
                                        value: "normal"
                                    },
                                    {
                                        label: "Portrait",
                                        value: "270"
                                    },
                                    {
                                        label: "Landscape (Flipped)",
                                        value: "180"
                                    },
                                    {
                                        label: "Portrait (Flipped)",
                                        value: "90"
                                    }
                                ]);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: "Orientation"
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Text {
                                    color: Config.md3.primary
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    text: displayPageRoot.getTransformLabel(activeOutputCard.activeOutputData && activeOutputCard.activeOutputData.logical ? activeOutputCard.activeOutputData.logical.transform : "Normal")
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.05)
                            height: 1
                        }

                        // 4.2 Resolution
                        MouseArea {
                            id: resRow

                            Layout.fillWidth: true
                            height: 55
                            hoverEnabled: true

                            onClicked: {
                                var outData = activeOutputCard.activeOutputData;
                                if (!outData)
                                    return;

                                var resList = [];
                                var preferredRes = "";
                                for (var i = 0; i < outData.modes.length; i++) {
                                    var m = outData.modes[i];
                                    if (m.is_preferred) {
                                        preferredRes = m.width + "x" + m.height;
                                    }
                                }

                                for (var i = 0; i < outData.modes.length; i++) {
                                    var m = outData.modes[i];
                                    var resStr = m.width + "x" + m.height;
                                    if (resList.indexOf(resStr) === -1) {
                                        resList.push(resStr);
                                    }
                                }

                                var model = [];
                                for (var j = 0; j < resList.length; j++) {
                                    var labelStr = resList[j];
                                    if (resList[j] === preferredRes) {
                                        labelStr += " (Preferred)";
                                    }
                                    model.push({
                                        label: labelStr,
                                        value: resList[j]
                                    });
                                }
                                displayPageRoot.openPopup(resRow, "resolution", model);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: "Resolution"
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Text {
                                    color: Config.md3.primary
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    text: {
                                        var outData = activeOutputCard.activeOutputData;
                                        var w = 0, h = 0;
                                        if (outData) {
                                            var modeIdx = outData.current_mode;
                                            if (modeIdx >= 0 && modeIdx < outData.modes.length) {
                                                w = outData.modes[modeIdx].width;
                                                h = outData.modes[modeIdx].height;
                                            }
                                        }
                                        return w + " × " + h;
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.05)
                            height: 1
                        }

                        // 4.3 Refresh Rate
                        MouseArea {
                            id: rateRow

                            Layout.fillWidth: true
                            height: 55
                            hoverEnabled: true

                            onClicked: {
                                var outData = activeOutputCard.activeOutputData;
                                if (!outData)
                                    return;

                                var curModeIdx = outData.current_mode;
                                var curW = 0, curH = 0;
                                if (curModeIdx >= 0 && curModeIdx < outData.modes.length) {
                                    curW = outData.modes[curModeIdx].width;
                                    curH = outData.modes[curModeIdx].height;
                                }

                                var rateList = [];
                                var preferredRateStr = "";
                                for (var i = 0; i < outData.modes.length; i++) {
                                    var m = outData.modes[i];
                                    if (m.width === curW && m.height === curH) {
                                        var rVal = m.refresh_rate / 1000;
                                        var rateStr = rVal.toFixed(3) + " Hz";
                                        if (rateList.indexOf(rateStr) === -1) {
                                            rateList.push(rateStr);
                                        }
                                        if (m.is_preferred) {
                                            preferredRateStr = rateStr;
                                        }
                                    }
                                }

                                var model = [];
                                for (var j = 0; j < rateList.length; j++) {
                                    var labelStr = rateList[j];
                                    if (rateList[j] === preferredRateStr) {
                                        labelStr += " (Preferred)";
                                    }
                                    model.push({
                                        label: labelStr,
                                        value: rateList[j]
                                    });
                                }
                                displayPageRoot.openPopup(rateRow, "refreshRate", model);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: "Refresh Rate"
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Text {
                                    color: Config.md3.primary
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    text: {
                                        var outData = activeOutputCard.activeOutputData;
                                        var r = 0.0;
                                        if (outData) {
                                            var modeIdx = outData.current_mode;
                                            if (modeIdx >= 0 && modeIdx < outData.modes.length) {
                                                r = outData.modes[modeIdx].refresh_rate / 1000;
                                            }
                                        }
                                        return r.toFixed(2) + " Hz";
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.05)
                            height: 1
                        }

                        // 4.4 Scale
                        MouseArea {
                            id: scaleRow

                            Layout.fillWidth: true
                            height: 55
                            hoverEnabled: true

                            onClicked: {
                                displayPageRoot.openPopup(scaleRow, "scale", [
                                    {
                                        label: "100 %",
                                        value: "1.0"
                                    },
                                    {
                                        label: "125 %",
                                        value: "1.25"
                                    },
                                    {
                                        label: "150 %",
                                        value: "1.5"
                                    },
                                    {
                                        label: "200 %",
                                        value: "2.0"
                                    }
                                ]);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: "Scale"
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Text {
                                    color: Config.md3.primary
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    text: {
                                        var outData = activeOutputCard.activeOutputData;
                                        var s = outData && outData.logical ? outData.logical.scale : 1.0;
                                        return Math.round(s * 100) + " %";
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.05)
                            height: 1
                        }

                        // 4.5 Focus at Startup Switch
                        Rectangle {
                            Layout.fillWidth: true
                            color: "transparent"
                            height: 55

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: "Focus at Startup"
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                ToggleSwitch {
                                    checked: displayPageRoot.getKdlOption(displayPageRoot.selectedOutputName, "focus")
                                    height: 22
                                    thumbCheckedColor: Config.md3.on_surface
                                    thumbMargin: 3
                                    thumbUncheckedColor: Config.md3.on_surface
                                    width: 42

                                    onToggled: checked => {
                                        displayPageRoot.toggleKdlOption(displayPageRoot.selectedOutputName, "focus", checked);
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.05)
                            height: 1
                        }

                        // 4.6 Variable Refresh Rate (VRR) Switch
                        Rectangle {
                            property bool isVrrSupported: {
                                var outData = activeOutputCard.activeOutputData;
                                return outData ? !!outData.vrr_supported : false;
                            }

                            Layout.fillWidth: true
                            color: "transparent"
                            height: 55

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                Text {
                                    color: parent.parent.isVrrSupported ? Config.md3.on_surface : Config.md3.outline
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: parent.parent.isVrrSupported ? "Variable Refresh Rate (VRR)" : "Variable Refresh Rate (VRR) (Not Supported)"
                                }
                                Item {
                                    Layout.fillWidth: true
                                }

                                // Switch
                                ToggleSwitch {
                                    checked: displayPageRoot.getKdlOption(displayPageRoot.selectedOutputName, "vrr")
                                    enabled: parent.parent.isVrrSupported
                                    height: 22
                                    opacity: parent.parent.isVrrSupported ? 1.0 : 0.4
                                    thumbCheckedColor: Config.md3.on_surface
                                    thumbMargin: 3
                                    thumbUncheckedColor: Config.md3.on_surface
                                    width: 42

                                    onToggled: checked => {
                                        displayPageRoot.toggleKdlOption(displayPageRoot.selectedOutputName, "vrr", checked);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    SelectPopup {
        anchors.fill: parent
        itemActive: item => displayPageRoot.popupItemChecked(item)
        model: displayPageRoot.popupModel
        openAbove: displayPageRoot.popupOpenAbove
        opened: displayPageRoot.popupOpen
        popupY: displayPageRoot.popupY
        rowHeight: 40

        onDismissed: displayPageRoot.popupOpen = false
        onItemSelected: item => displayPageRoot.selectPopupItem(item)
    }
}
