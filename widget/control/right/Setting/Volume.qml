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
    property bool popupIsSink: true
    property var popupModel: []
    property bool popupOpen: false
    property bool popupOpenAbove: false
    property var popupTargetStream: null
    property real popupY: 0

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

        var popupHeight = visibleCount * 46 + 16;
        var position = button.mapToItem(volumePageRoot, 0, 0);
        var belowY = position.y + button.height + 8;
        popupOpenAbove = belowY + popupHeight > height;
        popupY = popupOpenAbove ? position.y - popupHeight - 8 : belowY;
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
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: "Applications"
                }

                // Empty state message
                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.35)
                    font.family: Config.fontName
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    text: "No active audio applications"
                    visible: volumePageRoot.appStreamCount === 0
                }

                // App list card container
                Rectangle {
                    Layout.fillWidth: true
                    border.color: Config.alpha(Config.md3.on_surface, 0.06)
                    border.width: 1
                    color: Config.md3.surface_container
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

                                height: isAppStream ? 86 : 0
                                spacing: 6
                                visible: isAppStream
                                width: parent.width

                                PwObjectTracker {
                                    objects: modelData ? [modelData] : []
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
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                        text: modelData ? (modelData.description || modelData.name || "App Stream") : ""
                                    }

                                    // Application Audio Routing Selector Button (Premium design)
                                    Rectangle {
                                        id: appRouteButton

                                        border.color: routeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                                        border.width: 1
                                        color: routeMouse.pressed ? Config.md3.surface_container_highest : (routeMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container)
                                        height: 32
                                        radius: 8
                                        scale: routeMouse.pressed ? 0.97 : 1.0
                                        width: 170

                                        Behavior on border.color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 80
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
                                                font.pixelSize: 15
                                                font.weight: Font.DemiBold
                                                text: {
                                                    var isOut = AudioService.isPlaybackStream(modelData);
                                                    var dev = AudioService.streamTargetDevice(modelData, isOut);
                                                    return dev ? (dev.description || dev.name) : (isOut ? "Default Output" : "Default Input");
                                                }
                                            }
                                            IconImage {
                                                height: 12
                                                layer.enabled: true
                                                source: Quickshell.iconPath("pan-down-symbolic")
                                                width: 12

                                                layer.effect: ColorOverlay {
                                                    color: Config.md3.outline
                                                }
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
                                    border.color: Config.alpha(Config.md3.on_surface, 0.06)
                                    border.width: 1
                                    color: Config.md3.surface_container
                                    height: 48
                                    radius: 12
                                    width: parent.width

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 20
                                        anchors.rightMargin: 20
                                        spacing: 10

                                        // Mute/Unmute speaker icon button on the left
                                        Rectangle {
                                            color: "transparent"
                                            height: 24
                                            width: 24

                                            IconImage {
                                                anchors.centerIn: parent
                                                height: 22
                                                layer.enabled: true
                                                source: Quickshell.iconPath(!modelData || !modelData.audio || modelData.audio.muted ? "audio-volume-muted-symbolic" : modelData.audio.volume > 0.6 ? "audio-volume-high-symbolic" : modelData.audio.volume > 0.3 ? "audio-volume-medium-symbolic" : "audio-volume-low-symbolic")
                                                width: 22

                                                layer.effect: ColorOverlay {
                                                    color: modelData && modelData.audio && !modelData.audio.muted ? Config.md3.primary : Config.md3.on_surface_variant
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true

                                                onClicked: {
                                                    if (modelData && modelData.audio) {
                                                        modelData.audio.muted = !modelData.audio.muted;
                                                    }
                                                }
                                            }
                                        }

                                        // Slider in the middle
                                        CustomVolumeSlider {
                                            Layout.fillWidth: true
                                            isMuted: (modelData && modelData.audio) ? modelData.audio.muted : false
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
                                            font.pixelSize: 15
                                            font.weight: Font.Bold
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
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        text: "Output Devices"
                    }

                    // Device dropdown button
                    Rectangle {
                        id: outputDropButton

                        Layout.fillWidth: true
                        border.color: outputDropMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                        border.width: 1
                        color: outputDropMouse.pressed ? Config.md3.surface_container_highest : (outputDropMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container)
                        height: 46
                        radius: 12
                        scale: outputDropMouse.pressed ? 0.98 : 1.0

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 80
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
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                text: Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.name || "Unknown device") : "No output device"
                            }
                            IconImage {
                                height: 16
                                layer.enabled: true
                                rotation: volumePageRoot.outputDropOpen ? 180 : 0
                                source: Quickshell.iconPath("pan-down-symbolic")
                                width: 16

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_surface_variant
                                }
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: 150
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
                        border.color: Config.alpha(Config.md3.on_surface, 0.06)
                        border.width: 1
                        color: Config.md3.surface_container
                        height: 48
                        radius: 12

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 12

                            // Mute toggle button
                            Rectangle {
                                color: "transparent"
                                height: 24
                                width: 24

                                IconImage {
                                    anchors.centerIn: parent
                                    height: 22
                                    layer.enabled: true
                                    source: Quickshell.iconPath(!Pipewire.defaultAudioSink || Pipewire.defaultAudioSink.audio.muted ? "audio-volume-muted-symbolic" : Pipewire.defaultAudioSink.audio.volume > 0.6 ? "audio-volume-high-symbolic" : Pipewire.defaultAudioSink.audio.volume > 0.3 ? "audio-volume-medium-symbolic" : "audio-volume-low-symbolic")
                                    width: 22

                                    layer.effect: ColorOverlay {
                                        color: Pipewire.defaultAudioSink && !Pipewire.defaultAudioSink.audio.muted ? Config.md3.primary : Config.md3.on_surface_variant
                                    }
                                }
                                MouseArea {
                                    id: speakerMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: {
                                        if (Pipewire.defaultAudioSink) {
                                            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                                        }
                                    }
                                }
                            }
                            CustomVolumeSlider {
                                Layout.fillWidth: true
                                isMuted: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.muted : true
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
                                font.pixelSize: 15
                                font.weight: Font.Bold
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
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        text: "Balance"
                        visible: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.volumes && Pipewire.defaultAudioSink.audio.volumes.length >= 2
                    }

                    // Balance slider card
                    Rectangle {
                        Layout.fillWidth: true
                        border.color: Config.alpha(Config.md3.on_surface, 0.06)
                        border.width: 1
                        color: Config.md3.surface_container
                        height: 48
                        radius: 12
                        visible: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.volumes && Pipewire.defaultAudioSink.audio.volumes.length >= 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 12

                            Text {
                                color: Config.alpha(Config.md3.on_surface, 0.6)
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.Bold
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
                                color: Config.alpha(Config.md3.on_surface, 0.6)
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.Bold
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
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        text: "Input Devices"
                    }

                    // Device dropdown button
                    Rectangle {
                        id: inputDropButton

                        Layout.fillWidth: true
                        border.color: inputDropMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                        border.width: 1
                        color: inputDropMouse.pressed ? Config.md3.surface_container_highest : (inputDropMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container)
                        height: 46
                        radius: 12
                        scale: inputDropMouse.pressed ? 0.98 : 1.0

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 80
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
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                text: Pipewire.defaultAudioSource ? (Pipewire.defaultAudioSource.description || Pipewire.defaultAudioSource.name || "Unknown device") : "No input device"
                            }
                            IconImage {
                                height: 16
                                layer.enabled: true
                                rotation: volumePageRoot.inputDropOpen ? 180 : 0
                                source: Quickshell.iconPath("pan-down-symbolic")
                                width: 16

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_surface_variant
                                }
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: 150
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
                        border.color: Config.alpha(Config.md3.on_surface, 0.06)
                        border.width: 1
                        color: Config.md3.surface_container
                        height: 48
                        radius: 12

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 12

                            // Microphone Mute toggle button
                            Rectangle {
                                color: "transparent"
                                height: 24
                                width: 24

                                IconImage {
                                    anchors.centerIn: parent
                                    height: 22
                                    layer.enabled: true
                                    source: Quickshell.iconPath(!Pipewire.defaultAudioSource || Pipewire.defaultAudioSource.audio.muted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic")
                                    width: 22

                                    layer.effect: ColorOverlay {
                                        color: Pipewire.defaultAudioSource && !Pipewire.defaultAudioSource.audio.muted ? Config.md3.secondary : Config.md3.on_surface_variant
                                    }
                                }
                                MouseArea {
                                    id: micMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: {
                                        if (Pipewire.defaultAudioSource) {
                                            Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
                                        }
                                    }
                                }
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
                                font.pixelSize: 15
                                font.weight: Font.Bold
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
        SelectPopup {
            accentColor: volumePageRoot.popupIsSink ? Config.md3.primary : Config.md3.secondary
            anchors.fill: parent
            itemActive: device => volumePageRoot.popupDeviceActive(device)
            itemLabel: device => device ? AudioService.cleanDeviceName(device.description || device.name || "Device") : ""
            itemVisible: device => volumePageRoot.popupDeviceVisible(device)
            model: volumePageRoot.popupModel
            openAbove: volumePageRoot.popupOpenAbove
            opened: volumePageRoot.popupOpen
            popupY: volumePageRoot.popupY

            onDismissed: {
                volumePageRoot.closeDevicePopup();
            }
            onItemSelected: device => volumePageRoot.selectPopupDevice(device)
        }
    }
}
