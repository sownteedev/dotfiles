import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../../"
import "../../service"

PanelWindow {
    id: osdWindow

    // State active flag
    property bool active: false
    property bool activeBrightnessInit: false
    readonly property string activeIcon: {
        if (activeIndicator === "volume")
            return getVolumeIcon(volumeVal, volumeMuted);
        if (activeIndicator === "volume-mute")
            return "audio-volume-muted-symbolic";
        if (activeIndicator === "mic")
            return "audio-input-microphone-symbolic";
        if (activeIndicator === "mic-mute")
            return "microphone-sensitivity-muted-symbolic";
        if (activeIndicator === "brightness")
            return "display-brightness-symbolic";
        return "";
    }

    // State values
    property string activeIndicator: "" // "volume", "volume-mute", "mic", "mic-mute", "brightness"

    readonly property string activeLabel: {
        if (activeIndicator === "volume")
            return "Volume";
        if (activeIndicator === "mic")
            return "Microphone";
        if (activeIndicator === "brightness")
            return "Brightness";
        return "";
    }
    property bool activeMicInit: false

    // Event flags to ignore the initial values
    property bool activeSpeakerInit: false
    readonly property real activeValue: {
        if (activeIndicator === "volume")
            return volumeVal;
        if (activeIndicator === "mic")
            return micVal;
        if (activeIndicator === "brightness")
            return brightnessVal;
        return 0.0;
    }
    readonly property bool brightnessReady: BrightnessService.initialized && BrightnessService.available
    readonly property real brightnessVal: BrightnessService.value
    readonly property color highlightColor: {
        if (activeIndicator === "volume" || activeIndicator === "volume-mute")
            return Config.md3.primary;
        if (activeIndicator === "mic" || activeIndicator === "mic-mute")
            return Config.md3.tertiary;
        if (activeIndicator === "brightness")
            return Config.md3.secondary;
        return Config.md3.on_surface;
    }

    // Helper to get active properties
    readonly property bool isMute: activeIndicator === "volume-mute" || activeIndicator === "mic-mute"
    readonly property bool isOsdScreen: Quickshell.screens.length > 0 && (WorkspaceService.focusedOutputName !== "" ? screen && screen.name === WorkspaceService.focusedOutputName : screen === Quickshell.screens[0])
    readonly property bool micMuted: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio.muted : false
    readonly property bool micReady: Pipewire.ready && !!(Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio)
    readonly property real micVal: maximumAudioVolume(Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null)
    readonly property string muteIconName: activeIndicator.indexOf("mic") === 0 ? "microphone-sensitivity-muted-symbolic" : "audio-volume-muted-symbolic"
    readonly property bool speakerReady: Pipewire.ready && !!(Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
    readonly property bool volumeMuted: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.muted : false
    readonly property real volumeVal: maximumAudioVolume(Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null)

    function getVolumeIcon(val, muted) {
        if (muted)
            return "audio-volume-muted-symbolic";
        if (val >= 0.7)
            return "audio-volume-high-symbolic";
        if (val >= 0.3)
            return "audio-volume-medium-symbolic";
        if (val > 0)
            return "audio-volume-low-symbolic";
        return "audio-volume-muted-symbolic";
    }
    function maximumAudioVolume(audio) {
        if (!audio)
            return 0.0;
        var volumes = audio.volumes;
        if (!volumes || volumes.length === 0)
            return Math.max(0.0, audio.volume || 0.0);

        var maximum = 0.0;
        for (var i = 0; i < volumes.length; ++i) {
            var channelVolume = Number(volumes[i]);
            if (!isNaN(channelVolume))
                maximum = Math.max(maximum, channelVolume);
        }
        return maximum;
    }

    // Core OSD display logic
    function showOSD(type) {
        activeIndicator = type;
        active = true;

        hideTimer.stop();
        hideTimer.start();
    }

    WlrLayershell.layer: WlrLayer.Overlay

    // Position: bottom center of screen
    anchors.bottom: true
    anchors.left: false
    anchors.right: false
    anchors.top: false
    color: "transparent"
    exclusiveZone: 0 // Floating window - do not reserve screen space or push windows

    focusable: false
    implicitHeight: screen ? Math.min(110, screen.height) : 110

    // Keep the Wayland surface stable while the popup morphs between modes.
    implicitWidth: screen ? Math.min(320, screen.width) : 320
    margins.bottom: 10 // Distance from bottom of screen to window edge

    // Keep the window alive only while the popup is visible so it does not block clicks when hidden
    visible: isOsdScreen && (active || popup.opacity > 0.0)

    Component.onCompleted: {
        if (brightnessReady)
            brightnessInitTimer.start();
        if (micReady)
            micInitTimer.start();
        if (speakerReady)
            speakerInitTimer.start();
    }
    onBrightnessReadyChanged: {
        brightnessInitTimer.stop();
        activeBrightnessInit = false;
        if (brightnessReady)
            brightnessInitTimer.start();
    }
    onBrightnessValChanged: {
        if (activeBrightnessInit)
            showOSD("brightness");
    }
    onMicMutedChanged: {
        if (activeMicInit)
            showOSD(micMuted ? "mic-mute" : "mic");
    }
    onMicReadyChanged: {
        micInitTimer.stop();
        activeMicInit = false;
        if (micReady)
            micInitTimer.start();
    }
    onMicValChanged: {
        if (activeMicInit)
            showOSD("mic");
    }
    onSpeakerReadyChanged: {
        speakerInitTimer.stop();
        activeSpeakerInit = false;
        if (speakerReady)
            speakerInitTimer.start();
    }
    onVolumeMutedChanged: {
        if (activeSpeakerInit)
            showOSD(volumeMuted ? "volume-mute" : "volume");
    }
    onVolumeValChanged: {
        if (activeSpeakerInit)
            showOSD("volume");
    }

    Timer {
        id: hideTimer

        interval: 2000
        repeat: false

        onTriggered: {
            active = false;
        }
    }
    PwObjectTracker {
        id: audioTracker

        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    Timer {
        id: brightnessInitTimer

        interval: 50
        repeat: false

        onTriggered: activeBrightnessInit = brightnessReady
    }
    Timer {
        id: micInitTimer

        interval: 50
        repeat: false

        onTriggered: activeMicInit = micReady
    }
    Timer {
        id: speakerInitTimer

        interval: 50
        repeat: false

        onTriggered: activeSpeakerInit = speakerReady
    }

    // Window root content holder to contain drop shadow bounds
    Item {
        anchors.fill: parent
        clip: true // Cleanly clip the popup as it slides down below the window boundary

        // Premium drop shadow for floating glassmorphism effect
        DropShadow {
            anchors.fill: popup
            cached: true
            color: "#66000000"
            horizontalOffset: 3
            radius: 14
            samples: 24
            source: popup
            verticalOffset: 3
            visible: popup.opacity > 0.0 // Only enable shader drawing when the popup is visible/opaque
        }

        // Morphing layout container
        Rectangle {
            id: popup

            property real modeProgress: isMute ? 0.0 : 1.0
            property real popScale: 0.85

            // Animation variables
            property real yOffset: 40 // Slide down when hidden (away from screen)

            anchors.horizontalCenter: parent.horizontalCenter
            border.color: Config.md3.surface_container_high
            border.width: 1

            // Premium glassmorphic background styling
            clip: true
            color: Config.alpha(Config.md3.background, 0.85)
            height: Math.min(parent.height, 60 + 10 * modeProgress)
            opacity: 0.0
            radius: Math.min(width, height) / 2
            scale: popScale

            // Morphing properties
            width: Math.min(parent.width, 60 + Math.max(0, Math.min(240, osdWindow.width - 80)) * modeProgress)
            y: parent.height / 2 - height / 2 + yOffset

            Behavior on modeProgress {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            // Animation States (Springy Bounce Entry and Smooth Exit)
            states: [
                State {
                    name: "visible"
                    when: active

                    PropertyChanges {
                        opacity: 1.0
                        popScale: 1.0
                        target: popup
                        yOffset: 0
                    }
                },
                State {
                    name: "hidden"
                    when: !active

                    PropertyChanges {
                        opacity: 0.0
                        popScale: 0.85
                        target: popup
                        yOffset: 40
                    }
                }
            ]
            transitions: [
                Transition {
                    from: "hidden"
                    to: "visible"

                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuad
                        properties: "opacity"
                    }
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutBack
                        properties: "yOffset, popScale"
                    }
                },
                Transition {
                    from: "visible"
                    to: "hidden"

                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                        properties: "opacity"
                    }
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.InQuad
                        properties: "yOffset, popScale"
                    }
                }
            ]

            // Content container
            Item {
                anchors.fill: parent

                // Slider Layout (for volume, mic, brightness)
                RowLayout {
                    id: sliderLayout

                    anchors.centerIn: parent
                    height: parent.height
                    opacity: Math.max(0.0, Math.min(1.0, (popup.modeProgress - 0.32) / 0.68))
                    spacing: popup.width < 180 ? 10 : 15
                    visible: opacity > 0.01
                    width: Math.max(0, popup.width - 44)

                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 25
                        implicitWidth: 25

                        IconImage {
                            id: sliderIcon

                            anchors.fill: parent
                            layer.enabled: true
                            source: activeIcon !== "" ? Quickshell.iconPath(activeIcon) : ""

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                text: activeLabel
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                text: Math.round(activeValue * 100)
                            }
                        }

                        // Custom capsule progress bar
                        Item {
                            id: trough

                            readonly property real gapSize: 4
                            readonly property real totalWidth: width

                            Layout.fillWidth: true
                            height: 4

                            Rectangle {
                                id: activeProgress

                                anchors.left: parent.left
                                color: highlightColor
                                height: parent.height
                                radius: height / 2
                                width: {
                                    if (activeValue <= 0)
                                        return 0;
                                    if (activeValue >= 1)
                                        return trough.totalWidth;
                                    return Math.max(height, trough.totalWidth * activeValue - trough.gapSize / 2);
                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            // Inactive remainder capsule (right)
                            Rectangle {
                                id: inactiveProgress

                                anchors.right: parent.right
                                color: Config.alpha(highlightColor, 0.15)
                                height: parent.height
                                radius: height / 2
                                width: {
                                    if (activeValue <= 0)
                                        return trough.totalWidth;
                                    if (activeValue >= 1)
                                        return 0;
                                    return Math.max(height, trough.totalWidth * (1.0 - activeValue) - trough.gapSize / 2);
                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }
                        }
                    }
                }

                // Mute Icon Layout (centered single red icon)
                Item {
                    id: muteLayout

                    anchors.fill: parent
                    opacity: Math.max(0.0, 1.0 - popup.modeProgress / 0.38)
                    visible: opacity > 0.01

                    Item {
                        anchors.centerIn: parent
                        height: 30
                        width: 30

                        IconImage {
                            id: muteIcon

                            anchors.fill: parent
                            layer.enabled: true
                            source: Quickshell.iconPath(muteIconName)

                            layer.effect: ColorOverlay {
                                color: Config.md3.error
                            }
                        }
                    }
                }
            }
        }
    }
}
