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
    readonly property real brightnessValue: Math.round(DisplayBrightnessService.value * 100)

    // Draft coordinate management for screen rearranging
    property var draftPositions: ({})
    property bool hasChanges: false
    readonly property string internalHardwareId: DisplayService.internalHardwareId

    // KDL extra features (VRR, focus-at-startup)
    readonly property var kdlOptions: DisplayService.kdlOptions
    property bool monitorDragActive: false
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
    function getVrrMode(outputName) {
        return DisplayService.vrrMode(outputName);
    }
    function getVrrModeLabel(mode) {
        if (mode === "on")
            return qsTr("On");
        if (mode === "on-demand")
            return qsTr("On Demand");
        return qsTr("Off");
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
        if (activeDropdown === "vrr")
            return getVrrMode(targetOutput) === item.value;
        return false;
    }
    function refreshAll() {
        DisplayService.refresh();
        DisplayBrightnessService.refresh();
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
            if (output) {
                for (var modeIndex = 0; modeIndex < output.modes.length; ++modeIndex) {
                    var candidateMode = output.modes[modeIndex];
                    if (candidateMode.width === parseInt(dimensions[0], 10) && candidateMode.height === parseInt(dimensions[1], 10))
                        rate = Math.max(rate, candidateMode.refresh_rate / 1000);
                }
            }
            updateConfig(targetOutput, "mode", dimensions[0] + "x" + dimensions[1] + "@" + rate.toFixed(3));
        } else if (activeDropdown === "refreshRate") {
            var width = 1920;
            var height = 1080;
            if (output && output.current_mode >= 0 && output.current_mode < output.modes.length) {
                width = output.modes[output.current_mode].width;
                height = output.modes[output.current_mode].height;
            }
            updateConfig(targetOutput, "mode", width + "x" + height + "@" + parseFloat(value).toFixed(3));
        } else if (activeDropdown === "vrr") {
            updateVrrMode(targetOutput, value);
        }
        popupOpen = false;
    }
    function toggleKdlOption(output, option, enable) {
        DisplayService.toggleOption(output, option, enable);
    }
    function updateConfig(output, field, value) {
        DisplayService.updateConfig(output, field, value);
    }
    function updateVrrMode(output, mode) {
        DisplayService.setVrrMode(output, mode);
    }

    anchors.fill: parent

    onAllOutputsChanged: {
        if (allOutputs.length === 0) {
            selectedOutputName = "";
            draftPositions = ({});
            hasChanges = false;
            return;
        }
        var found = false;
        for (var i = 0; i < allOutputs.length; ++i) {
            if (allOutputs[i].name === selectedOutputName) {
                found = true;
                break;
            }
        }
        if (!found)
            selectedOutputName = allOutputs[0].name;
        DisplayBrightnessService.selectOutput(selectedOutputName);
        resetDrafts();
    }
    onSelectedOutputNameChanged: DisplayBrightnessService.selectOutput(selectedOutputName)
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
        interactive: !displayPageRoot.popupOpen && !displayPageRoot.monitorDragActive

        ColumnLayout {
            id: contentLayout

            spacing: 24
            width: parent.width

            // 1. Brightness Slider Card
            Rectangle {
                Layout.fillWidth: true
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                color: controlRightWindow.sectionCardColor
                height: 64
                radius: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

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
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                text: "Brightness" + (displayPageRoot.selectedOutputName !== "" ? " • " + displayPageRoot.selectedOutputName : "")
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Text {
                                color: DisplayBrightnessService.available ? Config.md3.primary : Config.md3.outline
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                text: DisplayBrightnessService.available ? displayPageRoot.brightnessValue + "%" : "Unavailable"
                            }
                        }
                        CustomVolumeSlider {
                            enabled: DisplayBrightnessService.available
                            highlightColor: Config.md3.primary
                            opacity: enabled ? 1 : 0.4
                            value: DisplayBrightnessService.value

                            onSliderMoved: value => DisplayBrightnessService.setValue(value)
                        }
                    }
                }
            }

            // 2. Night Light temperature control
            NightLightControl {
                Layout.fillWidth: true
                backgroundColor: controlRightWindow.sectionCardColor
                nightLightEnabled: DisplayService.nightlightEnabled
                temperature: DisplayService.nightlightTemperature

                onTemperatureCommitted: temperature => DisplayService.commitNightlightTemperature(temperature)
                onTemperatureRequested: temperature => DisplayService.setNightlightTemperature(temperature)
                onToggleRequested: enabled => DisplayService.setNightlightEnabled(enabled)
            }

            // 3. Dark Mode toggle
            Rectangle {
                Layout.fillWidth: true
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                clip: true
                color: controlRightWindow.sectionCardColor
                height: 68
                radius: 14

                Item {
                    anchors.fill: parent

                    Rectangle {
                        id: darkIconBackground

                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.alpha(Config.md3.primary, 0.16)
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
                                color: Config.md3.primary
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

            // 4. Windows-style display modes
            Rectangle {
                Layout.fillWidth: true
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                color: controlRightWindow.sectionCardColor
                height: 118
                radius: 14

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        text: "Display Mode"
                    }
                    SettingsSegmentedControl {
                        Layout.fillWidth: true
                        accessibleName: "Display mode"
                        backgroundColor: Config.alpha(Config.md3.on_surface, 0.07)
                        enabled: !DisplayService.displayModeApplying
                        options: [
                            {
                                label: "Internal only",
                                value: "internal",
                                enabled: DisplayService.hasInternalOutput
                            },
                            {
                                label: "Duplicate",
                                value: "duplicate",
                                enabled: false
                            },
                            {
                                label: "Extend",
                                value: "extend",
                                enabled: DisplayService.hasInternalOutput && DisplayService.hasExternalOutput
                            },
                            {
                                label: "External only",
                                value: "external",
                                enabled: DisplayService.hasExternalOutput
                            }
                        ]
                        selectedValue: DisplayService.displayMode

                        onSelected: value => DisplayService.applyDisplayMode(value, displayPageRoot.selectedOutputName)
                    }
                    Text {
                        Layout.fillWidth: true
                        color: DisplayService.displayModeError !== "" ? Config.md3.error : Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 12
                        text: DisplayService.displayModeApplying ? "Applying display mode…" : DisplayService.displayModeError !== "" ? DisplayService.displayModeError : DisplayService.hasExternalOutput ? "Duplicate requires compositor mirroring support" : "Connect an external display to enable more modes"
                    }
                }
            }

            // 5. Visual Monitor Layout Diagram
            Rectangle {
                id: monitorLayoutContainer

                Layout.fillWidth: true
                border.color: controlRightWindow.sectionCardBorderColor
                border.width: 1
                color: controlRightWindow.sectionCardColor
                height: displayPageRoot.allOutputs.length > 1 ? 300 : 200
                radius: 12
                visible: displayPageRoot.allOutputs.length > 0

                Behavior on height {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    spacing: 1
                    x: 12
                    y: 8

                    Text {
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        text: "Display arrangement"
                    }
                    Text {
                        color: Config.alpha(Config.md3.on_surface_variant, 0.72)
                        font.family: Config.fontName
                        font.pixelSize: 11
                        text: displayPageRoot.allOutputs.length > 1 ? "Drag a display left, right, above, or below" : "Drag displays to rearrange them"
                    }
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
                    anchors.topMargin: 48

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
                            color: isDragging ? Config.alpha(Config.md3.primary, 0.3) : (isSelected ? Config.alpha(Config.md3.primary, 0.15) : Config.alpha(Config.md3.on_surface, 0.12))
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
                                preventStealing: true

                                onCanceled: {
                                    displayPageRoot.monitorDragActive = false;
                                    monitorRect.isDragging = false;
                                    monitorRect.dragX = 0;
                                    monitorRect.dragY = 0;
                                }
                                onPositionChanged: mouse => {
                                    if (monitorRect.isDragging) {
                                        monitorRect.dragX += mouse.x - monitorRect.startX;
                                        monitorRect.dragY += mouse.y - monitorRect.startY;
                                    }
                                }
                                onPressed: mouse => {
                                    displayPageRoot.monitorDragActive = true;
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
                                    displayPageRoot.monitorDragActive = false;
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
                        color: Config.md3.on_primary
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 46
                        Layout.preferredWidth: 46
                        color: Config.alpha(Config.md3.primary, 0.14)
                        radius: 14

                        IconImage {
                            anchors.centerIn: parent
                            height: 24
                            layer.enabled: true
                            source: Quickshell.iconPath("video-display-symbolic")
                            width: 24

                            layer.effect: ColorOverlay {
                                color: Config.md3.primary
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            text: qsTr("Display Configuration")
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.52)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            text: {
                                var outData = activeOutputCard.activeOutputData;
                                if (!outData)
                                    return "";
                                var make = outData.make || qsTr("Generic");
                                var modelName = outData.model || "";
                                var sizeStr = "";
                                if (outData.physical_size && outData.physical_size.length === 2)
                                    sizeStr = " • " + outData.physical_size[0] + " × " + outData.physical_size[1] + " mm";
                                return make + (modelName ? " " + modelName : "") + sizeStr;
                            }
                            visible: text !== ""
                        }
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: connectorLabel.implicitWidth + 18
                        color: Config.alpha(Config.md3.primary, 0.14)
                        radius: 14

                        Text {
                            id: connectorLabel

                            anchors.centerIn: parent
                            color: Config.md3.primary
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: displayPageRoot.selectedOutputName
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    border.color: controlRightWindow.sectionCardBorderColor
                    border.width: 1
                    color: controlRightWindow.sectionCardColor
                    implicitHeight: configurationLayout.implicitHeight + 24
                    radius: 18

                    ColumnLayout {
                        id: configurationLayout

                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        GridLayout {
                            id: primarySettingsGrid

                            Layout.fillWidth: true
                            columnSpacing: 10
                            columns: width >= 390 ? 2 : 1
                            rowSpacing: 10

                            // 4.1 Orientation
                            DisplaySettingTile {
                                id: orientRow

                                iconName: "object-rotate-right-symbolic"
                                label: qsTr("Orientation")
                                value: displayPageRoot.getTransformLabel(activeOutputCard.activeOutputData && activeOutputCard.activeOutputData.logical ? activeOutputCard.activeOutputData.logical.transform : "Normal")

                                onActivated: sourceItem => displayPageRoot.openPopup(sourceItem, "transform", [
                                        {
                                            "label": qsTr("Landscape"),
                                            "value": "normal"
                                        },
                                        {
                                            "label": qsTr("Portrait"),
                                            "value": "270"
                                        },
                                        {
                                            "label": qsTr("Landscape (Flipped)"),
                                            "value": "180"
                                        },
                                        {
                                            "label": qsTr("Portrait (Flipped)"),
                                            "value": "90"
                                        }
                                    ])
                            }

                            // 4.2 Resolution
                            DisplaySettingTile {
                                id: resRow

                                iconName: "video-display-symbolic"
                                label: qsTr("Resolution")
                                value: {
                                    var outData = activeOutputCard.activeOutputData;
                                    var width = 0;
                                    var height = 0;
                                    if (outData) {
                                        var modeIndex = outData.current_mode;
                                        if (modeIndex >= 0 && modeIndex < outData.modes.length) {
                                            width = outData.modes[modeIndex].width;
                                            height = outData.modes[modeIndex].height;
                                        }
                                    }
                                    return width + " × " + height;
                                }

                                onActivated: sourceItem => {
                                    var outData = activeOutputCard.activeOutputData;
                                    if (!outData)
                                        return;

                                    var resList = [];
                                    var preferredRes = "";
                                    for (var i = 0; i < outData.modes.length; i++) {
                                        var m = outData.modes[i];
                                        if (m.is_preferred)
                                            preferredRes = m.width + "x" + m.height;
                                    }

                                    for (var modeIndex = 0; modeIndex < outData.modes.length; modeIndex++) {
                                        var mode = outData.modes[modeIndex];
                                        var resolution = mode.width + "x" + mode.height;
                                        if (resList.indexOf(resolution) === -1)
                                            resList.push(resolution);
                                    }

                                    var model = [];
                                    for (var j = 0; j < resList.length; j++) {
                                        var labelString = resList[j];
                                        if (resList[j] === preferredRes)
                                            labelString += " (" + qsTr("Preferred") + ")";
                                        model.push({
                                            "label": labelString,
                                            "value": resList[j]
                                        });
                                    }
                                    displayPageRoot.openPopup(sourceItem, "resolution", model);
                                }
                            }

                            // 4.3 Refresh Rate
                            DisplaySettingTile {
                                id: rateRow

                                iconName: "speedometer-symbolic"
                                label: qsTr("Refresh Rate")
                                value: {
                                    var outData = activeOutputCard.activeOutputData;
                                    var rate = 0.0;
                                    if (outData) {
                                        var modeIndex = outData.current_mode;
                                        if (modeIndex >= 0 && modeIndex < outData.modes.length)
                                            rate = outData.modes[modeIndex].refresh_rate / 1000;
                                    }
                                    return rate.toFixed(2) + " Hz";
                                }

                                onActivated: sourceItem => {
                                    var outData = activeOutputCard.activeOutputData;
                                    if (!outData)
                                        return;

                                    var currentModeIndex = outData.current_mode;
                                    var currentWidth = 0;
                                    var currentHeight = 0;
                                    if (currentModeIndex >= 0 && currentModeIndex < outData.modes.length) {
                                        currentWidth = outData.modes[currentModeIndex].width;
                                        currentHeight = outData.modes[currentModeIndex].height;
                                    }

                                    var rateList = [];
                                    var preferredRate = "";
                                    for (var i = 0; i < outData.modes.length; i++) {
                                        var mode = outData.modes[i];
                                        if (mode.width === currentWidth && mode.height === currentHeight) {
                                            var rateString = (mode.refresh_rate / 1000).toFixed(3) + " Hz";
                                            if (rateList.indexOf(rateString) === -1)
                                                rateList.push(rateString);
                                            if (mode.is_preferred)
                                                preferredRate = rateString;
                                        }
                                    }

                                    var model = [];
                                    for (var j = 0; j < rateList.length; j++) {
                                        var labelString = rateList[j];
                                        if (rateList[j] === preferredRate)
                                            labelString += " (" + qsTr("Preferred") + ")";
                                        model.push({
                                            "label": labelString,
                                            "value": rateList[j]
                                        });
                                    }
                                    displayPageRoot.openPopup(sourceItem, "refreshRate", model);
                                }
                            }

                            // 4.4 Scale
                            DisplaySettingTile {
                                id: scaleRow

                                iconName: "zoom-fit-best-symbolic"
                                label: qsTr("Scale")
                                value: {
                                    var outData = activeOutputCard.activeOutputData;
                                    var scale = outData && outData.logical ? outData.logical.scale : 1.0;
                                    return Math.round(scale * 100) + " %";
                                }

                                onActivated: sourceItem => displayPageRoot.openPopup(sourceItem, "scale", [
                                        {
                                            "label": "100 %",
                                            "value": "1.0"
                                        },
                                        {
                                            "label": "125 %",
                                            "value": "1.25"
                                        },
                                        {
                                            "label": "150 %",
                                            "value": "1.5"
                                        },
                                        {
                                            "label": "200 %",
                                            "value": "2.0"
                                        }
                                    ])
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            border.color: Config.alpha(Config.md3.on_surface, 0.07)
                            border.width: 1
                            color: Config.alpha(Config.md3.on_surface, 0.035)
                            implicitHeight: displayControlsLayout.implicitHeight
                            radius: 14

                            ColumnLayout {
                                id: displayControlsLayout

                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 0

                                // 4.5 Focus at Startup Switch
                                Rectangle {
                                    id: focusRow

                                    readonly property bool checked: displayPageRoot.getKdlOption(displayPageRoot.selectedOutputName, "focus")

                                    function requestToggle() {
                                        displayPageRoot.toggleKdlOption(displayPageRoot.selectedOutputName, "focus", !checked);
                                    }

                                    Accessible.checked: checked
                                    Accessible.name: qsTr("Focus at Startup")
                                    Accessible.role: Accessible.CheckBox
                                    Layout.fillWidth: true
                                    activeFocusOnTab: true
                                    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.56) : "transparent"
                                    border.width: 1
                                    color: focusRowMouse.pressed ? Config.alpha(Config.md3.primary, 0.14) : focusRowMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.08) : "transparent"
                                    implicitHeight: 58
                                    radius: 13

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 130
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 130
                                        }
                                    }

                                    Accessible.onPressAction: requestToggle()
                                    Keys.onReturnPressed: event => {
                                        requestToggle();
                                        event.accepted = true;
                                    }
                                    Keys.onSpacePressed: event => {
                                        requestToggle();
                                        event.accepted = true;
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredHeight: 36
                                            Layout.preferredWidth: 36
                                            color: Config.alpha(Config.md3.secondary, 0.14)
                                            radius: 11

                                            IconImage {
                                                anchors.centerIn: parent
                                                height: 19
                                                layer.enabled: true
                                                source: Quickshell.iconPath("go-home-symbolic")
                                                width: 19

                                                layer.effect: ColorOverlay {
                                                    color: Config.md3.secondary
                                                }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            color: Config.md3.on_surface
                                            elide: Text.ElideRight
                                            font.family: Config.fontName
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            text: qsTr("Focus at Startup")
                                        }
                                        ToggleSwitch {
                                            Accessible.ignored: true
                                            checked: focusRow.checked
                                            interactive: false
                                        }
                                    }
                                    MouseArea {
                                        id: focusRowMouse

                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true

                                        onClicked: {
                                            focusRow.forceActiveFocus();
                                            focusRow.requestToggle();
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 12
                                    Layout.rightMargin: 12
                                    color: Config.alpha(Config.md3.on_surface, 0.07)
                                    implicitHeight: 1
                                }

                                // 4.6 Variable Refresh Rate (VRR) mode
                                Rectangle {
                                    id: vrrRow

                                    readonly property bool isVrrSupported: {
                                        var outData = activeOutputCard.activeOutputData;
                                        return outData ? !!outData.vrr_supported : false;
                                    }

                                    function activate() {
                                        if (!isVrrSupported)
                                            return;
                                        forceActiveFocus();
                                        displayPageRoot.openPopup(vrrRow, "vrr", [
                                            {
                                                "label": qsTr("Off"),
                                                "value": "off"
                                            },
                                            {
                                                "label": qsTr("On"),
                                                "value": "on"
                                            },
                                            {
                                                "label": qsTr("On Demand"),
                                                "value": "on-demand"
                                            }
                                        ]);
                                    }

                                    Accessible.name: qsTr("Variable Refresh Rate: %1").arg(displayPageRoot.getVrrModeLabel(displayPageRoot.getVrrMode(displayPageRoot.selectedOutputName)))
                                    Accessible.role: Accessible.ComboBox
                                    Layout.fillWidth: true
                                    activeFocusOnTab: isVrrSupported
                                    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.56) : "transparent"
                                    border.width: 1
                                    color: vrrRowMouse.pressed ? Config.alpha(Config.md3.primary, 0.14) : vrrRowMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.08) : "transparent"
                                    implicitHeight: 58
                                    opacity: isVrrSupported ? 1 : 0.48
                                    radius: 13

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: 130
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 130
                                        }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 120
                                        }
                                    }

                                    Accessible.onPressAction: activate()
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                                            activate();
                                            event.accepted = true;
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredHeight: 36
                                            Layout.preferredWidth: 36
                                            color: Config.alpha(Config.md3.tertiary, 0.14)
                                            radius: 11

                                            IconImage {
                                                anchors.centerIn: parent
                                                height: 19
                                                layer.enabled: true
                                                source: Quickshell.iconPath("view-refresh-symbolic")
                                                width: 19

                                                layer.effect: ColorOverlay {
                                                    color: Config.md3.tertiary
                                                }
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                color: Config.md3.on_surface
                                                elide: Text.ElideRight
                                                font.family: Config.fontName
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                                text: qsTr("Variable Refresh Rate")
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                color: Config.alpha(Config.md3.on_surface, 0.48)
                                                elide: Text.ElideRight
                                                font.family: Config.fontName
                                                font.pixelSize: 11
                                                text: vrrRow.isVrrSupported ? qsTr("Adaptive refresh behavior") : qsTr("Not supported by this display")
                                            }
                                        }
                                        Text {
                                            color: vrrRow.isVrrSupported ? Config.md3.primary : Config.md3.outline
                                            font.family: Config.fontName
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            text: displayPageRoot.getVrrModeLabel(displayPageRoot.getVrrMode(displayPageRoot.selectedOutputName))
                                        }
                                        IconImage {
                                            Layout.preferredHeight: 16
                                            Layout.preferredWidth: 16
                                            layer.enabled: true
                                            source: Quickshell.iconPath("pan-down-symbolic")
                                            visible: vrrRow.isVrrSupported

                                            layer.effect: ColorOverlay {
                                                color: Config.alpha(Config.md3.on_surface, 0.52)
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: vrrRowMouse

                                        anchors.fill: parent
                                        cursorShape: vrrRow.isVrrSupported ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        enabled: vrrRow.isVrrSupported
                                        hoverEnabled: true

                                        onClicked: vrrRow.activate()
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    border.color: controlRightWindow.sectionCardBorderColor
                    border.width: 1
                    color: controlRightWindow.sectionCardColor
                    height: 76
                    radius: 12

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 12

                        IconImage {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: 24
                            layer.enabled: true
                            source: Quickshell.iconPath("video-display-symbolic")

                            layer.effect: ColorOverlay {
                                color: Config.md3.primary
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                text: "Sunshine streaming display"
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.outline
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 11
                                text: DisplayService.sunshineStatusOutput === displayPageRoot.selectedOutputName ? DisplayService.sunshineStatus : "Switch Sunshine encoder and capture to " + displayPageRoot.selectedOutputName
                            }
                        }
                        Rectangle {
                            color: sunshineButtonMouse.pressed ? Config.md3.primary_container : Config.md3.primary
                            enabled: !DisplayService.sunshineBusy
                            height: 38
                            opacity: enabled ? 1 : 0.55
                            radius: 19
                            width: 94

                            Text {
                                anchors.centerIn: parent
                                color: parent.enabled ? Config.md3.on_primary : Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                text: DisplayService.sunshineBusy ? "Applying…" : "Use display"
                            }
                            MouseArea {
                                id: sunshineButtonMouse

                                anchors.fill: parent
                                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: parent.enabled

                                onClicked: DisplayService.configureSunshine(displayPageRoot.selectedOutputName)
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
        popupWidth: displayPageRoot.activeDropdown === "vrr" ? 220 : displayPageRoot.popupWidth
        popupY: displayPageRoot.popupY
        rightMargin: displayPageRoot.activeDropdown === "vrr" ? 12 : Math.max(12, width - displayPageRoot.popupX - popupWidth)
        rowHeight: 40

        onDismissed: displayPageRoot.popupOpen = false
        onItemSelected: item => displayPageRoot.selectPopupItem(item)
    }
}
