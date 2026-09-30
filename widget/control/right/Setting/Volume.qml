import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import "../../../../" // for Config
import "../../../../components"
import "../../../../service"

Item {
    id: volumePageRoot

    readonly property int appStreamCount: AudioService.appStreamCount
    property bool inputDropOpen: false
    property bool outputDropOpen: false
    property real popupAnchorWidth: 0
    property real popupAnchorX: -1
    property bool popupIsSink: true
    property var popupModel: []
    property bool popupOpen: false
    property bool popupOpenAbove: false
    property real popupRightMargin: 12
    property var popupTargetStream: null
    property real popupWidth: 260
    property real popupY: 0
    readonly property real sliderControlInset: 12
    readonly property real sliderControlSpacing: 8
    readonly property real sliderIconContainerSize: 32
    readonly property real sliderIconSize: 20

    function closeDevicePopup() {
        popupOpen = false;
        popupTargetStream = null;
        outputDropOpen = false;
        inputDropOpen = false;
    }
    function popupDeviceActive(device) {
        if (!device)
            return false;
        var activeDevice = null;
        if (popupTargetStream) {
            activeDevice = AudioService.streamTargetDevice(popupTargetStream, popupIsSink);
        } else {
            activeDevice = popupIsSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;
        }
        return activeDevice && activeDevice.name === device.name;
    }
    function popupDeviceVisible(device) {
        return AudioService.isDevice(device, popupIsSink);
    }
    function selectPopupDevice(device) {
        if (!device)
            return;
        if (popupTargetStream) {
            AudioService.moveStream(popupTargetStream, popupIsSink, device);
        } else {
            AudioService.setDefaultDevice(device, popupIsSink);
        }
        outputDropOpen = false;
        inputDropOpen = false;
        popupOpen = false;
        popupTargetStream = null;
    }
    function toggleDevicePopup(button, isSink, targetStream) {
        var stream = targetStream || null;
        if (popupOpen && popupIsSink === isSink && popupTargetStream === stream) {
            closeDevicePopup();
            return;
        }

        var devices = Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : [];
        var visibleCount = 0;
        for (var i = 0; i < devices.length; ++i) {
            if (AudioService.isDevice(devices[i], isSink))
                ++visibleCount;
        }

        var popupHeight = Math.min(visibleCount * 46 + 16, Math.max(0, height - 24));
        var position = button.mapToItem(volumePageRoot, 0, 0);
        var belowY = position.y + button.height + 8;
        var spaceBelow = height - belowY - 12;
        var spaceAbove = position.y - 12;
        popupOpenAbove = spaceBelow < popupHeight && spaceAbove > spaceBelow;
        popupY = popupOpenAbove ? position.y - popupHeight - 8 : belowY;
        popupAnchorWidth = Math.min(44, button.width);
        popupAnchorX = position.x + Math.max(0, button.width - popupAnchorWidth);
        popupRightMargin = Math.max(12, width - position.x - button.width);
        popupModel = devices;
        popupIsSink = isSink;
        popupTargetStream = stream;
        popupOpen = true;
        outputDropOpen = isSink && !stream;
        inputDropOpen = !isSink && !stream;
    }

    anchors.fill: parent

    SettingsPageTransition {
        panelActive: controlRightWindow.active
        targetItem: volumePageRoot
    }
    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: innerColumn.implicitHeight
        contentWidth: width
        interactive: !volumePageRoot.popupOpen

        ColumnLayout {
            id: innerColumn

            spacing: 20
            width: parent.width

            // ─── 1. Applications Section ───────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                    font.pixelSize: Md3.typeScale.titleMedium.size
                    font.weight: Font.DemiBold
                    lineHeight: Md3.typeScale.titleMedium.lineHeight
                    lineHeightMode: Text.FixedHeight
                    text: "Applications"
                }

                // Empty state message
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                    font.pixelSize: Md3.typeScale.bodyLarge.size
                    font.weight: Md3.typeScale.bodyLarge.weight
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: Md3.typeScale.bodyLarge.lineHeight
                    lineHeightMode: Text.FixedHeight
                    text: "No active audio applications"
                    visible: volumePageRoot.appStreamCount === 0
                }

                // App list card container
                Rectangle {
                    Layout.fillWidth: true
                    border.color: controlRightWindow.sectionCardBorderColor
                    border.width: 1
                    color: controlRightWindow.sectionCardColor
                    implicitHeight: appStreamListColumn.height + 24
                    radius: 12
                    visible: volumePageRoot.appStreamCount > 0

                    Column {
                        id: appStreamListColumn

                        spacing: 16
                        width: parent.width - 24
                        x: 12
                        y: 12

                        Repeater {
                            model: Pipewire.ready ? Pipewire.nodes : null

                            delegate: Column {
                                id: appDelegate

                                readonly property bool isAppStream: modelData && modelData.isStream && modelData.audio && AudioService.isPlaybackStream(modelData)
                                readonly property real streamPeak: Math.max(0, Math.min(1, appPeakMonitor.peak))

                                height: isAppStream ? 86 : 0
                                spacing: 6
                                visible: isAppStream
                                width: parent.width

                                PwObjectTracker {
                                    objects: modelData ? [modelData] : []
                                }
                                PwNodePeakMonitor {
                                    id: appPeakMonitor

                                    enabled: controlRightWindow.active && appDelegate.visible && modelData && modelData.audio && !modelData.audio.muted
                                    node: appDelegate.isAppStream ? modelData : null
                                }
                                RowLayout {
                                    spacing: 12
                                    width: parent.width

                                    // Application Icon on the left
                                    IconImage {
                                        readonly property string resolvedIcon: AudioService.resolveAppIcon(modelData)

                                        height: 22
                                        layer.enabled: resolvedIcon.endsWith("-symbolic")
                                        source: Quickshell.iconPath(resolvedIcon)
                                        width: 22

                                        layer.effect: ColorOverlay {
                                            color: Config.md3.on_surface
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                        font.pixelSize: Md3.typeScale.titleMedium.size
                                        font.weight: Md3.typeScale.titleMedium.weight
                                        lineHeight: Md3.typeScale.titleMedium.lineHeight
                                        lineHeightMode: Text.FixedHeight
                                        text: modelData ? (modelData.description || modelData.name || "App Stream") : ""
                                    }

                                    // Application Audio Routing Selector Button (Premium design)
                                    Rectangle {
                                        id: appRouteButton

                                        border.color: routeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                                        border.width: 1
                                        color: Config.alpha(Config.md3.on_surface, routeMouse.pressed ? 0.18 : (routeMouse.containsMouse ? 0.12 : 0.07))
                                        height: 32
                                        radius: 8
                                        scale: routeMouse.pressed ? 0.97 : 1.0
                                        width: 170

                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: Config.animationDuration(120)
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Config.animationDuration(120)
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Config.animationDuration(80)
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 20
                                            anchors.rightMargin: 20
                                            spacing: 8

                                            Text {
                                                Layout.fillWidth: true
                                                color: Config.md3.on_surface
                                                elide: Text.ElideRight
                                                font.family: Config.fontName
                                                font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                                font.pixelSize: Md3.typeScale.titleMedium.size
                                                font.weight: Font.DemiBold
                                                lineHeight: Md3.typeScale.titleMedium.lineHeight
                                                lineHeightMode: Text.FixedHeight
                                                text: {
                                                    var isOut = AudioService.isPlaybackStream(modelData);
                                                    var dev = AudioService.streamTargetDevice(modelData, isOut);
                                                    return dev ? (dev.description || dev.name) : (isOut ? "Default Output" : "Default Input");
                                                }
                                            }
                                            Md3Icon {
                                                color: Config.md3.outline
                                                name: "pan-down-symbolic"
                                                size: 12
                                            }
                                        }
                                        MouseArea {
                                            id: routeMouse

                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true

                                            onClicked: {
                                                volumePageRoot.toggleDevicePopup(appRouteButton, AudioService.isPlaybackStream(modelData), modelData);
                                            }
                                        }
                                    }
                                }

                                // Application slider card (identical styling to system device sliders)
                                Rectangle {
                                    border.color: controlRightWindow.sectionCardBorderColor
                                    border.width: 1
                                    color: controlRightWindow.sectionCardColor
                                    height: 48
                                    radius: 12
                                    width: parent.width

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: volumePageRoot.sliderControlInset
                                        anchors.rightMargin: 20
                                        spacing: volumePageRoot.sliderControlSpacing

                                        // Mute/Unmute speaker icon button on the left
                                        Md3IconButton {
                                            Accessible.name: checked ? qsTr("Unmute application") : qsTr("Mute application")
                                            Layout.preferredHeight: 40
                                            Layout.preferredWidth: 40
                                            checkable: true
                                            checked: enabled && modelData.audio.muted
                                            containerSize: volumePageRoot.sliderIconContainerSize
                                            enabled: !!modelData && !!modelData.audio
                                            iconName: !modelData || !modelData.audio || modelData.audio.muted ? "audio-volume-muted-symbolic" : modelData.audio.volume > 0.6 ? "audio-volume-high-symbolic" : modelData.audio.volume > 0.3 ? "audio-volume-medium-symbolic" : "audio-volume-low-symbolic"
                                            iconSize: volumePageRoot.sliderIconSize

                                            onClicked: modelData.audio.muted = !modelData.audio.muted
                                        }

                                        // Slider in the middle
                                        CustomVolumeSlider {
                                            Layout.fillWidth: true
                                            isMuted: (modelData && modelData.audio) ? modelData.audio.muted : false
                                            maximumValue: Config.audioMaxVolume
                                            peakColor: appDelegate.streamPeak > 0.88 ? Config.md3.error : appDelegate.streamPeak > 0.68 ? Config.md3.tertiary : Config.md3.secondary
                                            peakValue: appDelegate.streamPeak
                                            showPeak: true
                                            value: (modelData && modelData.audio) ? modelData.audio.volume : 0.0

                                            onSliderMoved: val => {
                                                if (modelData && modelData.audio)
                                                    modelData.audio.volume = val;
                                            }
                                        }

                                        // Volume % text on the right
                                        Text {
                                            color: (modelData && modelData.audio && !modelData.audio.muted) ? Config.md3.primary : Config.md3.on_surface_variant
                                            font.family: Config.fontName
                                            font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                            font.pixelSize: Md3.typeScale.titleMedium.size
                                            font.weight: Font.DemiBold
                                            lineHeight: Md3.typeScale.titleMedium.lineHeight
                                            lineHeightMode: Text.FixedHeight
                                            text: (modelData && modelData.audio) ? Math.round(modelData.audio.volume * 100) + "%" : "0%"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.06)
                    height: 1
                }

                // ─── 2. Output Devices ─────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                        font.pixelSize: Md3.typeScale.titleMedium.size
                        font.weight: Font.DemiBold
                        lineHeight: Md3.typeScale.titleMedium.lineHeight
                        lineHeightMode: Text.FixedHeight
                        text: "Output Devices"
                    }

                    // Device dropdown button
                    Rectangle {
                        id: outputDropButton

                        Layout.fillWidth: true
                        border.color: outputDropMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                        border.width: 1
                        color: Config.alpha(Config.md3.on_surface, outputDropMouse.pressed ? 0.18 : (outputDropMouse.containsMouse ? 0.12 : 0.07))
                        height: 46
                        radius: 12
                        scale: outputDropMouse.pressed ? 0.98 : 1.0

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animationDuration(120)
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(120)
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animationDuration(80)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                font.pixelSize: Md3.typeScale.titleMedium.size
                                font.weight: Font.DemiBold
                                lineHeight: Md3.typeScale.titleMedium.lineHeight
                                lineHeightMode: Text.FixedHeight
                                text: Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.name || "Unknown device") : "No output device"
                            }
                            Md3Icon {
                                color: Config.md3.on_surface_variant
                                name: "pan-down-symbolic"
                                rotation: volumePageRoot.outputDropOpen ? 180 : 0
                                size: 16

                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: Config.animationDuration(Md3.motion.short3)
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: outputDropMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                volumePageRoot.toggleDevicePopup(outputDropButton, true, null);
                            }
                        }
                    }

                    // Output speaker slider card
                    Rectangle {
                        Layout.fillWidth: true
                        border.color: controlRightWindow.sectionCardBorderColor
                        border.width: 1
                        color: controlRightWindow.sectionCardColor
                        height: 48
                        radius: 12

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: volumePageRoot.sliderControlInset
                            anchors.rightMargin: 20
                            spacing: volumePageRoot.sliderControlSpacing

                            // Mute toggle button
                            Md3IconButton {
                                Accessible.name: checked ? qsTr("Unmute speaker") : qsTr("Mute speaker")
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 40
                                checkable: true
                                checked: enabled && Pipewire.defaultAudioSink.audio.muted
                                containerSize: volumePageRoot.sliderIconContainerSize
                                enabled: !!Pipewire.defaultAudioSink && !!Pipewire.defaultAudioSink.audio
                                iconName: !Pipewire.defaultAudioSink || Pipewire.defaultAudioSink.audio.muted ? "audio-volume-muted-symbolic" : Pipewire.defaultAudioSink.audio.volume > 0.6 ? "audio-volume-high-symbolic" : Pipewire.defaultAudioSink.audio.volume > 0.3 ? "audio-volume-medium-symbolic" : "audio-volume-low-symbolic"
                                iconSize: volumePageRoot.sliderIconSize

                                onClicked: Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                            }
                            CustomVolumeSlider {
                                Layout.fillWidth: true
                                isMuted: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.muted : true
                                maximumValue: Config.audioMaxVolume
                                value: {
                                    if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio)
                                        return 0.0;
                                    var vols = Pipewire.defaultAudioSink.audio.volumes;
                                    if (!vols || vols.length === 0)
                                        return Pipewire.defaultAudioSink.audio.volume;
                                    return Math.max(vols[0] || 0.0, vols[1] || vols[0] || 0.0);
                                }

                                onSliderMoved: val => {
                                    if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                        var vols = Pipewire.defaultAudioSink.audio.volumes;
                                        if (vols && vols.length >= 2) {
                                            var maxVol = Math.max(vols[0], vols[1]);
                                            if (maxVol === 0) {
                                                Pipewire.defaultAudioSink.audio.volumes = [val, val];
                                            } else {
                                                var ratio = val / maxVol;
                                                Pipewire.defaultAudioSink.audio.volumes = [vols[0] * ratio, vols[1] * ratio];
                                            }
                                        } else {
                                            Pipewire.defaultAudioSink.audio.volume = val;
                                        }
                                    }
                                }
                            }
                            Text {
                                color: (Pipewire.defaultAudioSink && !Pipewire.defaultAudioSink.audio.muted) ? Config.md3.primary : Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                font.pixelSize: Md3.typeScale.titleMedium.size
                                font.weight: Font.DemiBold
                                lineHeight: Md3.typeScale.titleMedium.lineHeight
                                lineHeightMode: Text.FixedHeight
                                text: {
                                    if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio)
                                        return "0%";
                                    var vols = Pipewire.defaultAudioSink.audio.volumes;
                                    var vol = (vols && vols.length >= 2) ? Math.max(vols[0], vols[1]) : Pipewire.defaultAudioSink.audio.volume;
                                    return Math.round(vol * 100) + "%";
                                }
                            }
                        }
                    }

                    // Balance slider header
                    Text {
                        Layout.topMargin: 4
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                        font.pixelSize: Md3.typeScale.titleMedium.size
                        font.weight: Font.DemiBold
                        lineHeight: Md3.typeScale.titleMedium.lineHeight
                        lineHeightMode: Text.FixedHeight
                        text: "Balance"
                        visible: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.volumes && Pipewire.defaultAudioSink.audio.volumes.length >= 2
                    }

                    // Balance slider card
                    Rectangle {
                        Layout.fillWidth: true
                        border.color: controlRightWindow.sectionCardBorderColor
                        border.width: 1
                        color: controlRightWindow.sectionCardColor
                        height: 48
                        radius: 12
                        visible: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.volumes && Pipewire.defaultAudioSink.audio.volumes.length >= 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 12

                            Text {
                                color: Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                                font.pixelSize: Md3.typeScale.labelLarge.size
                                font.weight: Md3.typeScale.labelLarge.weight
                                lineHeight: Md3.typeScale.labelLarge.lineHeight
                                lineHeightMode: Text.FixedHeight
                                text: "L"
                            }
                            CustomVolumeSlider {
                                id: balanceSlider

                                Layout.fillWidth: true
                                isMuted: false
                                showCenterTick: true
                                value: {
                                    if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio)
                                        return 0.5;
                                    var vols = Pipewire.defaultAudioSink.audio.volumes;
                                    if (!vols || vols.length < 2)
                                        return 0.5;
                                    var volL = vols[0];
                                    var volR = vols[1];
                                    if (volL === 0 && volR === 0)
                                        return 0.5;

                                    var bal = 0.0;
                                    if (volL > volR) {
                                        bal = -(1.0 - volR / volL);
                                    } else if (volR > volL) {
                                        bal = (1.0 - volL / volR);
                                    }
                                    return (bal + 1.0) / 2.0;
                                }

                                onSliderMoved: val => {
                                    if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio)
                                        return;
                                    var vols = Pipewire.defaultAudioSink.audio.volumes;
                                    if (!vols || vols.length < 2)
                                        return;

                                    var bal = (val * 2.0) - 1.0;
                                    var currentVol = Math.max(vols[0], vols[1]);
                                    if (currentVol === 0)
                                        currentVol = 0.5;

                                    var newL = currentVol;
                                    var newR = currentVol;

                                    if (bal < 0) {
                                        newR = currentVol * (1.0 + bal);
                                    } else if (bal > 0) {
                                        newL = currentVol * (1.0 - bal);
                                    }

                                    Pipewire.defaultAudioSink.audio.volumes = [newL, newR];
                                }
                            }
                            Text {
                                color: Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                                font.pixelSize: Md3.typeScale.labelLarge.size
                                font.weight: Md3.typeScale.labelLarge.weight
                                lineHeight: Md3.typeScale.labelLarge.lineHeight
                                lineHeightMode: Text.FixedHeight
                                text: "R"
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.06)
                    height: 1
                }

                // ─── 3. Input Devices ──────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                        font.pixelSize: Md3.typeScale.titleMedium.size
                        font.weight: Font.DemiBold
                        lineHeight: Md3.typeScale.titleMedium.lineHeight
                        lineHeightMode: Text.FixedHeight
                        text: "Input Devices"
                    }

                    // Device dropdown button
                    Rectangle {
                        id: inputDropButton

                        Layout.fillWidth: true
                        border.color: inputDropMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                        border.width: 1
                        color: Config.alpha(Config.md3.on_surface, inputDropMouse.pressed ? 0.18 : (inputDropMouse.containsMouse ? 0.12 : 0.07))
                        height: 46
                        radius: 12
                        scale: inputDropMouse.pressed ? 0.98 : 1.0

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animationDuration(120)
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(120)
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animationDuration(80)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                font.pixelSize: Md3.typeScale.titleMedium.size
                                font.weight: Font.DemiBold
                                lineHeight: Md3.typeScale.titleMedium.lineHeight
                                lineHeightMode: Text.FixedHeight
                                text: Pipewire.defaultAudioSource ? (Pipewire.defaultAudioSource.description || Pipewire.defaultAudioSource.name || "Unknown device") : "No input device"
                            }
                            Md3Icon {
                                color: Config.md3.on_surface_variant
                                name: "pan-down-symbolic"
                                rotation: volumePageRoot.inputDropOpen ? 180 : 0
                                size: 16

                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: Config.animationDuration(Md3.motion.short3)
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: inputDropMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                volumePageRoot.toggleDevicePopup(inputDropButton, false, null);
                            }
                        }
                    }

                    // Microphone slider card
                    Rectangle {
                        Layout.fillWidth: true
                        border.color: controlRightWindow.sectionCardBorderColor
                        border.width: 1
                        color: controlRightWindow.sectionCardColor
                        height: 48
                        radius: 12

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: volumePageRoot.sliderControlInset
                            anchors.rightMargin: 20
                            spacing: volumePageRoot.sliderControlSpacing

                            // Microphone Mute toggle button
                            Md3IconButton {
                                Accessible.name: checked ? qsTr("Unmute microphone") : qsTr("Mute microphone")
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 40
                                checkable: true
                                checked: enabled && Pipewire.defaultAudioSource.audio.muted
                                containerSize: volumePageRoot.sliderIconContainerSize
                                enabled: !!Pipewire.defaultAudioSource && !!Pipewire.defaultAudioSource.audio
                                iconName: !Pipewire.defaultAudioSource || Pipewire.defaultAudioSource.audio.muted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
                                iconSize: volumePageRoot.sliderIconSize

                                onClicked: Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                            }
                            CustomVolumeSlider {
                                Layout.fillWidth: true
                                highlightColor: Config.md3.secondary
                                isMuted: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio.muted : true
                                value: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio.volume : 0.0

                                onSliderMoved: val => {
                                    if (Pipewire.defaultAudioSource) {
                                        Pipewire.defaultAudioSource.audio.volume = val;
                                    }
                                }
                            }
                            Text {
                                color: (Pipewire.defaultAudioSource && !Pipewire.defaultAudioSource.audio.muted) ? Config.md3.secondary : Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                font.pixelSize: Md3.typeScale.titleMedium.size
                                font.weight: Font.DemiBold
                                lineHeight: Md3.typeScale.titleMedium.lineHeight
                                lineHeightMode: Text.FixedHeight
                                text: Pipewire.defaultAudioSource ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) + "%" : "0%"
                            }
                        }
                    }
                }

                // Bottom spacer
                Item {
                    Layout.preferredHeight: 10
                }
            }
        }
    }
    SelectPopup {
        accentColor: volumePageRoot.popupIsSink ? Config.md3.primary : Config.md3.secondary
        anchorWidth: volumePageRoot.popupAnchorWidth
        anchorX: volumePageRoot.popupAnchorX
        anchors.fill: parent
        itemActive: device => volumePageRoot.popupDeviceActive(device)
        itemLabel: device => device ? AudioService.cleanDeviceName(device.description || device.name || "Device") : ""
        itemVisible: device => volumePageRoot.popupDeviceVisible(device)
        model: volumePageRoot.popupModel
        openAbove: volumePageRoot.popupOpenAbove
        opened: volumePageRoot.popupOpen
        popupWidth: volumePageRoot.popupWidth
        popupY: volumePageRoot.popupY
        rightMargin: volumePageRoot.popupRightMargin
        shadowOpacity: 0.5

        onDismissed: {
            volumePageRoot.closeDevicePopup();
        }
        onItemSelected: device => volumePageRoot.selectPopupDevice(device)
    }
}
