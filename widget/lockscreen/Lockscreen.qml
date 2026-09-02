import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets
import "../.."
import "../../components"
import "../../service"
import "../idle"

Scope {
    id: root

    // State
    property bool authenticationGranted: false
    readonly property string backdropPath: BackdropService.ready ? BackdropService.activeBackdrop : ""
    readonly property string cacheRoot: Config.cacheRoot
    readonly property bool clock24h: settingValue("clock24h", true)
    // Time
    property int curH: new Date().getHours()
    property int curM: new Date().getMinutes()
    property int curMS: new Date().getMilliseconds()
    property int curS: new Date().getSeconds()
    readonly property bool enableWindup: true
    // Reading text() with blockLoading forces the PAM service decision to be
    // made before PamContext starts. The file may also contain a password-only
    // fallback, so only an active pam_howdy rule means face unlock is enabled.
    readonly property bool faceUnlockAvailable: pamConfigHasHowdy(pamConfigFile.text())
    readonly property string fallbackWallpaper: wallpaperState.frame || wallpaperState.thumbnail || (wallpaperState.mode === "static" ? wallpaperState.path : "")
    // Fonts
    readonly property string fontName: settingValue("fontName", "Inter Variable")
    property bool isWindup: false
    readonly property real localTimeMS: (curH * 3.6e+06) + (curM * 60000) + (curS * 1000) + curMS
    readonly property QtObject lockscreenColors: QtObject {
        readonly property color background: Config.md3.background
        readonly property color backgroundOverlay: Config.alpha(Config.md3.background, 0.62)
        readonly property color border: Config.md3.outline_variant
        readonly property color dimText: Config.alpha(Config.md3.on_surface_variant, 0.76)
        readonly property color error: Config.md3.error
        readonly property color panel: Config.alpha(Config.md3.surface_container_high, 0.92)
        readonly property color primary: Config.md3.primary
        readonly property color secondaryText: Config.md3.on_surface_variant
        readonly property color text: Config.md3.on_surface
        readonly property color waitingText: Config.alpha(Config.md3.on_surface_variant, 0.62)
    }
    property var runtimeSettings: ({})
    property string username: Quickshell.env("USER") || "sownteedev"
    property var wallpaperState: ({})
    property bool weatherConsumerAcquired: false

    signal dismissed

    function clockLabelColor(spotlight) {
        var c1 = root.lockscreenColors.secondaryText;
        var c2 = root.lockscreenColors.primary;
        var r = c1.r * (1 - spotlight) + c2.r * spotlight;
        var g = c1.g * (1 - spotlight) + c2.g * spotlight;
        var b = c1.b * (1 - spotlight) + c2.b * spotlight;
        var a = 0.48 * (1 - spotlight) + (0.6 + 0.4 * spotlight) * spotlight;
        return Qt.rgba(r, g, b, a);
    }
    function clockMarkColor(spotlight, isMajor) {
        var c1 = root.lockscreenColors.secondaryText;
        var c2 = root.lockscreenColors.primary;
        var r = c1.r * (1 - spotlight) + c2.r * spotlight;
        var g = c1.g * (1 - spotlight) + c2.g * spotlight;
        var b = c1.b * (1 - spotlight) + c2.b * spotlight;
        var baseAlpha = isMajor ? 0.52 : 0.28;
        var a = baseAlpha * (1 - spotlight) + (0.65 + 0.35 * spotlight) * spotlight;
        return Qt.rgba(r, g, b, a);
    }
    function loadRuntimeSettings() {
        if (!settingsFile.loaded)
            return;
        try {
            var parsed = JSON.parse(settingsFile.text());
            runtimeSettings = parsed || {};
        } catch (error) {
            console.warn("[Lockscreen] Invalid settings.json:", error);
        }
    }
    function loadWallpaperState() {
        if (!wallpaperStateFile.loaded)
            return;
        try {
            var parsed = JSON.parse(wallpaperStateFile.text());
            wallpaperState = parsed || {};
        } catch (error) {
            console.warn("[Lockscreen] Invalid wallpaper state:", error);
        }
    }
    function localFileUrl(path) {
        var value = String(path || "");
        return value.indexOf("file:") === 0 ? value : "file://" + value;
    }
    function pamConfigHasHowdy(contents) {
        var lines = String(contents || "").split("\n");
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            if (line !== "" && line[0] !== "#" && line.indexOf("pam_howdy.so") !== -1)
                return true;
        }
        return false;
    }
    function refreshLockscreenWeather() {
        if (String(Config.apiWeather || "").trim() === "" || String(Config.latLon || "").trim() === "")
            return;
        if (!weatherConsumerAcquired) {
            WeatherService.acquire();
            weatherConsumerAcquired = true;
        }
        // acquire() already starts the first request when this is the first
        // active consumer. Only start it here if no request is in flight.
        if (WeatherService.needsRefresh() && !WeatherService.loading)
            WeatherService.fetchWeather();
    }
    function releaseLockscreenWeather() {
        if (!weatherConsumerAcquired)
            return;
        WeatherService.release();
        weatherConsumerAcquired = false;
    }
    function retryFace() {
        if (pam)
            pam.retryFaceAuthentication();
    }
    function settingValue(name, fallback) {
        var value = runtimeSettings ? runtimeSettings[name] : undefined;
        return value !== undefined && value !== null ? value : fallback;
    }

    Component.onCompleted: {
        StateManager.sessionLocked = true;
        refreshLockscreenWeather();
    }
    Component.onDestruction: {
        releaseLockscreenWeather();
        StateManager.sessionLocked = false;
    }

    FileView {
        id: pamConfigFile

        blockLoading: true
        path: "/etc/pam.d/quickshell"
        printErrors: false
        watchChanges: false
    }
    FileView {
        id: settingsFile

        blockLoading: true
        path: root.cacheRoot + "/settings.json"
        printErrors: false
        watchChanges: true

        onLoadedChanged: {
            if (loaded)
                root.loadRuntimeSettings();
        }
        onTextChanged: {
            if (loaded)
                root.loadRuntimeSettings();
        }
    }
    FileView {
        id: wallpaperStateFile

        blockLoading: true
        path: root.cacheRoot + "/quickshell_wallpaper.txt"
        printErrors: false
        watchChanges: true

        onLoadedChanged: {
            if (loaded)
                root.loadWallpaperState();
        }
        onTextChanged: {
            if (loaded)
                root.loadWallpaperState();
        }
    }
    Timer {
        interval: 16
        repeat: true
        running: true

        onTriggered: {
            var d = new Date();
            root.curH = d.getHours();
            root.curM = d.getMinutes();
            root.curS = d.getSeconds();
            root.curMS = d.getMilliseconds();
        }
    }
    WlSessionLock {
        id: sessionLock

        locked: true // Lock screen immediately on launch

        onLockedChanged: {
            if (!locked) {
                StateManager.sessionLocked = false;
                root.dismissed();
            }
        }
        onSecureStateChanged: {
            if (secure && !root.authenticationGranted)
                pam.beginAuthentication();
        }

        // The surface created for each screen
        WlSessionLockSurface {
            id: lockSurface

            color: root.lockscreenColors.background

            Item {
                id: container

                property real jitterX: 0
                property real jitterY: 0
                readonly property real marginR: 80 * s
                readonly property real s: Responsive.clamp(Math.min(width / 1366, height / 768), 0.35, 2)
                property real slideX: 0
                readonly property real smoothMinAngle: -((root.localTimeMS % 3.6e+06) / 3.6e+06) * 360 - windupOffset * 5
                readonly property real smoothSecAngle: -((root.localTimeMS % 60000) / 60000) * 360 - windupOffset * 10
                property real sparkIntensity: 0
                property bool unlockStarted: false
                // Animation parameters per screen
                property real windupOffset: 0
                property real windupProgress: windupOffset / 150000

                function startLoginSequence() {
                    if (pam.authenticating)
                        return;

                    if (passInput.text.length === 0) {
                        if (root.faceUnlockAvailable && pam.faceFallbackOnly) {
                            errText.text = "";
                            pam.retryFaceAuthentication();
                            passInput.forceActiveFocus();
                        }
                        return;
                    }

                    pam.submitPassword(passInput.text);
                }
                function startUnlockSequence() {
                    if (unlockStarted)
                        return;
                    unlockStarted = true;
                    if (root.enableWindup) {
                        root.isWindup = true;
                        windupAnim.start();
                        boomTriggerTimer.start();
                    } else {
                        sessionLock.locked = false;
                    }
                }

                height: lockSurface.height
                width: lockSurface.width

                Component.onCompleted: {
                    fadeIn.start();
                    if (root.authenticationGranted)
                        Qt.callLater(container.startUnlockSequence);
                }

                Connections {
                    function onAuthenticationGrantedChanged() {
                        if (root.authenticationGranted)
                            container.startUnlockSequence();
                    }

                    target: root
                }
                Timer {
                    interval: 16
                    repeat: true
                    running: root.isWindup

                    onTriggered: {
                        var intensity = container.windupProgress * 32 * container.s;
                        container.jitterX = (Math.random() - 0.5) * intensity;
                        container.jitterY = (Math.random() - 0.5) * intensity;
                        container.sparkIntensity = container.windupProgress > 0.2 ? (container.windupProgress - 0.2) * 2.2 : 0;
                    }
                }
                NumberAnimation {
                    id: windupAnim

                    duration: 1600
                    easing.type: Easing.InQuint
                    from: 0
                    property: "windupOffset"
                    target: container
                    to: 150000
                }
                ParallelAnimation {
                    id: boomSequence

                    onFinished: {
                        sessionLock.locked = false;
                    }

                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutCubic
                        property: "slideX"
                        target: container
                        to: 500 * container.s
                    }
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                        property: "opacity"
                        target: container
                        to: 0
                    }
                }
                Timer {
                    id: boomTriggerTimer

                    interval: 1450

                    onTriggered: {
                        boomSequence.start();
                    }
                }

                // Wallpaper background (blurred)
                Image {
                    id: backgroundImage

                    property bool useBackdrop: true

                    anchors.fill: parent
                    // The generated image is intentionally tiny. Loading it
                    // synchronously prevents a blank/partial first frame while
                    // the session-lock surface is being mapped.
                    asynchronous: false
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    source: root.localFileUrl(useBackdrop ? root.backdropPath : root.fallbackWallpaper)

                    onStatusChanged: {
                        if (status === Image.Error && useBackdrop && root.fallbackWallpaper !== "")
                            useBackdrop = false;
                    }
                }

                // Match Control's MD3 background while keeping the blurred
                // wallpaper visible underneath.
                Rectangle {
                    anchors.fill: parent
                    color: root.lockscreenColors.backgroundOverlay
                }

                // Focus helper
                Timer {
                    interval: 300
                    running: true

                    onTriggered: passInput.forceActiveFocus()
                }
                NumberAnimation {
                    id: fadeIn

                    duration: 350
                    easing.type: Easing.OutCubic
                    from: 0
                    property: "opacity"
                    target: container
                    to: 1
                }

                // Clock analog ticking container
                Item {
                    id: blastContainer

                    anchors.fill: parent
                    x: container.jitterX - container.slideX
                    y: container.jitterY

                    Item {
                        id: clockContainer

                        readonly property real cx: 40 * container.s
                        readonly property real cy: height * 0.5
                        readonly property real minR: 320 * container.s
                        readonly property real secR: 480 * container.s

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: 800 * container.s

                        Item {
                            id: indicatorPill

                            anchors.verticalCenter: parent.verticalCenter
                            height: 90 * container.s
                            width: 330 * container.s
                            x: clockContainer.cx + 230 * container.s
                            z: 1
                            // Invisible spacer maintaining layout between Hour and Date/Weather
                        }
                        Repeater {
                            model: 60

                            delegate: Rectangle {
                                property real randA: Math.random() * 6.28
                                property real randV: 400 * container.s + Math.random() * 900 * container.s

                                color: root.lockscreenColors.primary
                                height: (1 + 12 * container.sparkIntensity) * container.s
                                opacity: container.sparkIntensity * (Math.random() > 0.4 ? 1 : 0.2)
                                radius: width / 2
                                rotation: randA * 180 / Math.PI + 90
                                visible: container.sparkIntensity > 0
                                width: (1 + Math.random() * 2) * container.s
                                x: (clockContainer.cx + 400 * container.s) + Math.cos(randA) * (randV * container.sparkIntensity)
                                y: (clockContainer.cy) + Math.sin(randA) * (randV * container.sparkIntensity)
                                z: 50
                            }
                        }
                        Repeater {
                            model: 60

                            delegate: Item {
                                property real base: index * 6
                                property real disp: (base + container.smoothMinAngle) * Math.PI / 180
                                property bool isMajor: index % 5 == 0
                                property real relAngle: {
                                    var a = (base + container.smoothMinAngle) % 360;
                                    if (a > 180)
                                        a -= 360;

                                    if (a < -180)
                                        a += 360;

                                    return a;
                                }
                                property real spotlight: Math.max(0, 1 - Math.abs(relAngle) / 4)
                                property real tx: clockContainer.cx + clockContainer.minR * Math.cos(disp)
                                property real ty: clockContainer.cy + clockContainer.minR * Math.sin(disp)

                                visible: tx > -600 * container.s && tx < 1800 * container.s
                                z: 10

                                Rectangle {
                                    color: root.clockMarkColor(spotlight, isMajor)
                                    height: isMajor ? 18 * container.s : 10 * container.s
                                    rotation: disp * 180 / Math.PI + 90
                                    scale: 1 + 0.25 * spotlight
                                    width: isMajor ? 2 * container.s : 1 * container.s
                                    x: parent.tx - width / 2
                                    y: parent.ty - height / 2
                                }
                                Text {
                                    property real nRad: clockContainer.minR - 35 * container.s

                                    color: root.clockLabelColor(spotlight)
                                    font.family: root.fontName
                                    font.pixelSize: 22 * container.s
                                    font.weight: Font.ExtraBold
                                    rotation: disp * 180 / Math.PI
                                    scale: 1 + 0.25 * spotlight
                                    text: String(index).padStart(2, '0')
                                    transformOrigin: Item.Center
                                    visible: isMajor
                                    x: clockContainer.cx + nRad * Math.cos(disp) - width / 2
                                    y: clockContainer.cy + nRad * Math.sin(disp) - height / 2
                                }
                            }
                        }
                        Repeater {
                            model: 60

                            delegate: Item {
                                property real base: index * 6
                                property real disp: (base + container.smoothSecAngle) * Math.PI / 180
                                property bool isMajor: index % 5 == 0
                                property real relAngle: {
                                    var a = (base + container.smoothSecAngle) % 360;
                                    if (a > 180)
                                        a -= 360;

                                    if (a < -180)
                                        a += 360;

                                    return a;
                                }
                                property real spotlight: Math.max(0, 1 - Math.abs(relAngle) / 4)
                                property real tx: clockContainer.cx + clockContainer.secR * Math.cos(disp)
                                property real ty: clockContainer.cy + clockContainer.secR * Math.sin(disp)

                                visible: tx > -600 * container.s && tx < 1800 * container.s
                                z: 10

                                Rectangle {
                                    color: root.clockMarkColor(spotlight, isMajor)
                                    height: isMajor ? 13 * container.s : 8 * container.s
                                    rotation: disp * 180 / Math.PI + 90
                                    scale: 1 + 0.25 * spotlight
                                    width: isMajor ? 1.5 * container.s : 1 * container.s
                                    x: parent.tx - width / 2
                                    y: parent.ty - height / 2
                                }
                                Text {
                                    property real nRad: clockContainer.secR - 30 * container.s

                                    color: root.clockLabelColor(spotlight)
                                    font.family: root.fontName
                                    font.pixelSize: 18 * container.s
                                    font.weight: Font.ExtraBold
                                    rotation: disp * 180 / Math.PI
                                    scale: 1 + 0.25 * spotlight
                                    text: String(index).padStart(2, '0')
                                    transformOrigin: Item.Center
                                    visible: isMajor
                                    x: clockContainer.cx + nRad * Math.cos(disp) - width / 2
                                    y: clockContainer.cy + nRad * Math.sin(disp) - height / 2
                                }
                            }
                        }
                        Text {
                            anchors.right: indicatorPill.left
                            anchors.rightMargin: 40 * container.s
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.lockscreenColors.text
                            font.family: root.fontName
                            font.pixelSize: 110 * container.s
                            font.weight: Font.Black
                            text: String(root.clock24h ? root.curH : (root.curH % 12 || 12)).padStart(2, '0')
                        }
                        Column {
                            anchors.left: indicatorPill.right
                            anchors.leftMargin: 110 * container.s
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5 * container.s

                            Row {
                                height: 26 * container.s
                                spacing: 14 * container.s

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.lockscreenColors.secondaryText
                                    font.family: root.fontName
                                    font.letterSpacing: 2 * container.s
                                    font.pixelSize: 20 * container.s
                                    font.weight: Font.ExtraBold
                                    text: Qt.formatDate(new Date(), "dd MMMM yyyy").toUpperCase()
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Config.alpha(root.lockscreenColors.secondaryText, 0.3)
                                    height: 13 * container.s
                                    visible: WeatherService.hasData
                                    width: 1 * container.s
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height
                                    spacing: 6 * container.s
                                    visible: WeatherService.hasData

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 20 * container.s
                                        layer.enabled: true
                                        source: Quickshell.iconPath(WeatherService.icon)
                                        width: 20 * container.s

                                        layer.effect: ColorOverlay {
                                            color: root.lockscreenColors.secondaryText
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.lockscreenColors.secondaryText
                                        font.family: root.fontName
                                        font.letterSpacing: 1 * container.s
                                        font.pixelSize: 16 * container.s
                                        font.weight: Font.Bold
                                        text: WeatherService.formatTemperature(WeatherService.temperature)
                                    }
                                }
                            }
                            Text {
                                color: root.lockscreenColors.text
                                font.family: root.fontName
                                font.letterSpacing: 5 * container.s
                                font.pixelSize: 70 * container.s
                                font.weight: Font.Black
                                text: Qt.formatDate(new Date(), "dddd").toUpperCase()
                            }
                        }
                    }
                }

                // HUD panel containing username and password entry
                Item {
                    id: hudContainer

                    anchors.fill: parent
                    opacity: container.opacity

                    Column {
                        id: ambientPanel

                        anchors.right: parent.right
                        anchors.rightMargin: container.marginR
                        anchors.top: parent.top
                        anchors.topMargin: 38 * container.s
                        width: 370 * container.s

                        transform: Translate {
                            x: container.slideX
                        }

                        Row {
                            anchors.right: parent.right
                            height: 24 * container.s
                            spacing: 16 * container.s

                            Item {
                                id: lockMedia

                                readonly property bool shouldShow: MediaService.playing
                                property var spectrum: CavaService.bars

                                anchors.verticalCenter: parent.verticalCenter
                                height: 36 * container.s
                                opacity: shouldShow ? 1 : 0
                                visible: opacity > 0
                                width: 120 * container.s

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 240
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Canvas {
                                    id: lockMediaCanvas

                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 36 * container.s
                                    opacity: CavaService.available ? CavaService.levelScale : 0.32
                                    width: parent.width

                                    onHeightChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);

                                        var centerY = height * 0.5;
                                        var bars = lockMedia.spectrum || [];
                                        var count = bars.length > 0 ? bars.length : 48;
                                        var gap = width / count;
                                        var baseline = Config.alpha(root.lockscreenColors.secondaryText, 0.16);
                                        var spectrumGradient = ctx.createLinearGradient(0, 0, width, 0);
                                        spectrumGradient.addColorStop(0, Config.alpha(root.lockscreenColors.text, 0.88));
                                        spectrumGradient.addColorStop(0.54, Config.alpha(root.lockscreenColors.primary, 0.48));
                                        spectrumGradient.addColorStop(1, Config.alpha(root.lockscreenColors.primary, 0.08));

                                        ctx.beginPath();
                                        ctx.moveTo(0, centerY);
                                        ctx.lineTo(width, centerY);
                                        ctx.lineWidth = Math.max(1, container.s * 0.75);
                                        ctx.strokeStyle = baseline;
                                        ctx.stroke();

                                        ctx.beginPath();
                                        ctx.lineCap = "round";
                                        ctx.lineWidth = Math.max(1.4, gap * 0.32);
                                        ctx.strokeStyle = spectrumGradient;
                                        for (var index = 0; index < count; ++index) {
                                            var rawLevel = bars.length > index ? Number(bars[index] || 0) * CavaService.levelScale : 0;
                                            var shapedLevel = Math.pow(Math.max(0, Math.min(1, rawLevel)), 0.68);
                                            var amplitude = Math.max(1.2 * container.s, shapedLevel * height * 0.44);
                                            var x = (index + 0.5) * gap;
                                            ctx.moveTo(x, centerY - amplitude);
                                            ctx.lineTo(x, centerY + amplitude);
                                        }
                                        ctx.stroke();
                                    }
                                    onWidthChanged: requestPaint()

                                    Connections {
                                        function onFrameRevisionChanged() {
                                            lockMediaCanvas.requestPaint();
                                        }

                                        target: CavaService
                                    }
                                }
                            }
                            WifiSignalIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.lockscreenColors.secondaryText
                                connected: WifiService.connected
                                connectivityIssue: WifiService.connectivityIssue
                                height: 16 * container.s
                                signalStrength: WifiService.activeSignal
                                visible: WifiService.connectionType !== "ethernet"
                                width: 16 * container.s
                            }
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16 * container.s
                                layer.enabled: true
                                source: Quickshell.iconPath(WifiService.iconName)
                                visible: WifiService.connectionType === "ethernet"
                                width: 16 * container.s

                                layer.effect: ColorOverlay {
                                    color: root.lockscreenColors.secondaryText
                                }
                            }
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16 * container.s
                                layer.enabled: true
                                source: Quickshell.iconPath(UPower.displayDevice ? UPower.displayDevice.iconName : "")
                                visible: UPower.displayDevice ? UPower.displayDevice.isLaptopBattery : false
                                width: 16 * container.s

                                layer.effect: ColorOverlay {
                                    color: root.lockscreenColors.secondaryText
                                }
                            }
                        }
                    }
                    LockscreenNotifications {
                        id: lockscreenNotifications

                        anchors.right: parent.right
                        anchors.rightMargin: container.marginR
                        anchors.top: ambientPanel.bottom
                        anchors.topMargin: 8 * container.s
                        maximumHeight: Math.max(0, loginPanel.y - lockscreenNotifications.y - 12 * container.s)
                        width: 220 * container.s
                        z: 100

                        transform: Translate {
                            x: container.slideX
                        }
                    }
                    Column {
                        id: loginPanel

                        property real shakeOffset: 0

                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 80 * container.s
                        anchors.right: parent.right
                        anchors.rightMargin: container.marginR
                        spacing: 8 * container.s
                        width: 350 * container.s

                        transform: Translate {
                            x: container.slideX + loginPanel.shakeOffset
                        }

                        Item {
                            height: 40 * container.s
                            width: parent.width
                            z: 5000

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7 * container.s

                                Item {
                                    id: faceScanIndicator

                                    readonly property bool scanning: pam.faceState === "scanning"
                                    readonly property bool verified: pam.faceState === "matched" && pam.verifiedMethod === "face"

                                    height: 38 * container.s
                                    visible: scanning || verified
                                    width: (verified ? 38 : 70) * container.s

                                    onScanningChanged: {
                                        if (!scanning) {
                                            faceTurn.yawAngle = 0;
                                            faceTurn.pitchAngle = 0;
                                        }
                                        faceGlyph.requestPaint();
                                    }

                                    Item {
                                        id: faceTurn

                                        property real pitchAngle: 0
                                        property real yawAngle: 0

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 36 * container.s
                                        scale: faceScanIndicator.verified ? 1.06 : 1
                                        width: height

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 220
                                                easing.type: Easing.OutBack
                                            }
                                        }
                                        transform: [
                                            Rotation {
                                                angle: faceTurn.yawAngle
                                                origin.x: faceTurn.width / 2
                                                origin.y: faceTurn.height / 2

                                                axis {
                                                    x: 0
                                                    y: 1
                                                    z: 0
                                                }
                                            },
                                            Rotation {
                                                angle: faceTurn.pitchAngle
                                                origin.x: faceTurn.width / 2
                                                origin.y: faceTurn.height / 2

                                                axis {
                                                    x: 1
                                                    y: 0
                                                    z: 0
                                                }
                                            }
                                        ]

                                        onPitchAngleChanged: faceGlyph.requestPaint()
                                        onYawAngleChanged: faceGlyph.requestPaint()

                                        Canvas {
                                            id: faceGlyph

                                            readonly property color lineColor: faceScanIndicator.verified ? root.lockscreenColors.primary : root.lockscreenColors.secondaryText
                                            property real morphProgress: verified ? 1.0 : 0.0
                                            readonly property bool verified: faceScanIndicator.verified

                                            anchors.fill: parent

                                            Behavior on morphProgress {
                                                NumberAnimation {
                                                    duration: 350
                                                    easing.type: Easing.InOutCubic
                                                }
                                            }

                                            onHeightChanged: requestPaint()
                                            onLineColorChanged: requestPaint()
                                            onMorphProgressChanged: requestPaint()
                                            onPaint: {
                                                var ctx = getContext("2d");
                                                var scale = width / 36;
                                                var lookX = Math.max(-1, Math.min(1, faceTurn.yawAngle / 18)) * 1.2 * scale;
                                                var lookY = Math.max(-1, Math.min(1, faceTurn.pitchAngle / 12)) * 0.8 * scale;
                                                ctx.clearRect(0, 0, width, height);
                                                ctx.lineCap = "round";
                                                ctx.lineJoin = "round";
                                                ctx.lineWidth = Math.max(1, 1.35 * scale);
                                                ctx.strokeStyle = lineColor;
                                                ctx.fillStyle = lineColor;

                                                ctx.beginPath();
                                                ctx.moveTo(2 * scale, 9 * scale);
                                                ctx.lineTo(2 * scale, 3 * scale);
                                                ctx.lineTo(8 * scale, 3 * scale);
                                                ctx.moveTo(28 * scale, 3 * scale);
                                                ctx.lineTo(34 * scale, 3 * scale);
                                                ctx.lineTo(34 * scale, 9 * scale);
                                                ctx.moveTo(34 * scale, 27 * scale);
                                                ctx.lineTo(34 * scale, 33 * scale);
                                                ctx.lineTo(28 * scale, 33 * scale);
                                                ctx.moveTo(8 * scale, 33 * scale);
                                                ctx.lineTo(2 * scale, 33 * scale);
                                                ctx.lineTo(2 * scale, 27 * scale);
                                                ctx.stroke();

                                                ctx.beginPath();
                                                ctx.moveTo(18 * scale, 5 * scale);
                                                ctx.bezierCurveTo(11 * scale, 5 * scale, 8 * scale, 10 * scale, 9 * scale, 18 * scale);
                                                ctx.bezierCurveTo(10 * scale, 27 * scale, 14 * scale, 31 * scale, 18 * scale, 31 * scale);
                                                ctx.bezierCurveTo(22 * scale, 31 * scale, 26 * scale, 27 * scale, 27 * scale, 18 * scale);
                                                ctx.bezierCurveTo(28 * scale, 10 * scale, 25 * scale, 5 * scale, 18 * scale, 5 * scale);
                                                ctx.stroke();

                                                if (morphProgress < 1.0) {
                                                    ctx.save();
                                                    ctx.globalAlpha = 1.0 - morphProgress;
                                                    var scaleDown = 1.0 - (morphProgress * 0.5);

                                                    ctx.translate(18 * scale, 18 * scale);
                                                    ctx.scale(scaleDown, scaleDown);
                                                    ctx.translate(-18 * scale, -18 * scale);

                                                    ctx.beginPath();
                                                    ctx.arc(14.2 * scale + lookX, 16.2 * scale + lookY, 1.15 * scale, 0, Math.PI * 2);
                                                    ctx.arc(21.8 * scale + lookX, 16.2 * scale + lookY, 1.15 * scale, 0, Math.PI * 2);
                                                    ctx.fill();

                                                    ctx.beginPath();
                                                    ctx.moveTo(18 * scale + lookX * 0.35, 18 * scale);
                                                    ctx.lineTo(17.4 * scale + lookX * 0.35, 22 * scale + lookY * 0.3);
                                                    ctx.lineTo(19 * scale + lookX * 0.35, 22.3 * scale + lookY * 0.3);
                                                    ctx.moveTo(14.7 * scale, 25.5 * scale);
                                                    ctx.quadraticCurveTo(18 * scale, 27.4 * scale, 21.3 * scale, 25.5 * scale);
                                                    ctx.stroke();

                                                    ctx.restore();
                                                }

                                                if (morphProgress > 0.0) {
                                                    ctx.save();
                                                    ctx.lineWidth = Math.max(1.8, 2.2 * scale);

                                                    var p1x = 12.5 * scale;
                                                    var p1y = 18.5 * scale;
                                                    var p2x = 16.7 * scale;
                                                    var p2y = 22.7 * scale;
                                                    var p3x = 24.2 * scale;
                                                    var p3y = 14.3 * scale;

                                                    var L1 = 5.94;
                                                    var L2 = 11.23;
                                                    var LTotal = L1 + L2;

                                                    var currentLength = morphProgress * LTotal;

                                                    ctx.beginPath();
                                                    ctx.moveTo(p1x, p1y);
                                                    if (currentLength <= L1) {
                                                        var t1 = currentLength / L1;
                                                        ctx.lineTo(p1x + (p2x - p1x) * t1, p1y + (p2y - p1y) * t1);
                                                    } else {
                                                        ctx.lineTo(p2x, p2y);
                                                        var t2 = (currentLength - L1) / L2;
                                                        ctx.lineTo(p2x + (p3x - p2x) * t2, p2y + (p3y - p2y) * t2);
                                                    }
                                                    ctx.stroke();
                                                    ctx.restore();
                                                }
                                            }
                                            onVerifiedChanged: requestPaint()
                                            onWidthChanged: requestPaint()
                                        }
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: root.lockscreenColors.primary
                                            height: Math.max(1, 1.2 * container.s)
                                            opacity: 0.82
                                            radius: height / 2
                                            visible: faceScanIndicator.scanning
                                            width: 27 * container.s

                                            SequentialAnimation on y {
                                                loops: Animation.Infinite
                                                running: faceScanIndicator.scanning

                                                NumberAnimation {
                                                    duration: 900
                                                    easing.type: Easing.InOutSine
                                                    from: 5 * container.s
                                                    to: 29 * container.s
                                                }
                                                NumberAnimation {
                                                    duration: 900
                                                    easing.type: Easing.InOutSine
                                                    from: 29 * container.s
                                                    to: 5 * container.s
                                                }
                                            }
                                        }
                                        SequentialAnimation {
                                            loops: Animation.Infinite
                                            running: faceScanIndicator.scanning

                                            PauseAnimation {
                                                duration: 160
                                            }
                                            NumberAnimation {
                                                duration: 540
                                                easing.type: Easing.InOutSine
                                                property: "yawAngle"
                                                target: faceTurn
                                                to: -18
                                            }
                                            NumberAnimation {
                                                duration: 980
                                                easing.type: Easing.InOutSine
                                                property: "yawAngle"
                                                target: faceTurn
                                                to: 18
                                            }
                                            NumberAnimation {
                                                duration: 480
                                                easing.type: Easing.InOutSine
                                                property: "yawAngle"
                                                target: faceTurn
                                                to: 0
                                            }
                                            NumberAnimation {
                                                duration: 420
                                                easing.type: Easing.InOutSine
                                                property: "pitchAngle"
                                                target: faceTurn
                                                to: -11
                                            }
                                            NumberAnimation {
                                                duration: 760
                                                easing.type: Easing.InOutSine
                                                property: "pitchAngle"
                                                target: faceTurn
                                                to: 11
                                            }
                                            NumberAnimation {
                                                duration: 380
                                                easing.type: Easing.InOutSine
                                                property: "pitchAngle"
                                                target: faceTurn
                                                to: 0
                                            }
                                            PauseAnimation {
                                                duration: 180
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.lockscreenColors.secondaryText
                                        font.family: root.fontName
                                        font.letterSpacing: 1.6 * container.s
                                        font.pixelSize: 8.5 * container.s
                                        font.weight: Font.DemiBold
                                        text: pam.faceAttempts + "/" + pam.maxFaceAttempts
                                        visible: faceScanIndicator.scanning
                                    }
                                }
                                Item {
                                    id: passwordPromptIcon

                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 24 * container.s
                                    visible: pam.faceState === "password"
                                    width: height

                                    IconImage {
                                        anchors.centerIn: parent
                                        height: 17 * container.s
                                        layer.enabled: true
                                        opacity: 0.88
                                        source: Quickshell.iconPath("changes-prevent-symbolic")
                                        width: height

                                        layer.effect: ColorOverlay {
                                            color: root.lockscreenColors.secondaryText
                                        }
                                    }
                                }
                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 24 * container.s
                                    visible: pam.faceState === "matched" && pam.verifiedMethod === "password"
                                    width: height

                                    IconImage {
                                        anchors.centerIn: parent
                                        height: 17 * container.s
                                        layer.enabled: true
                                        source: Quickshell.iconPath("changes-allow-symbolic")
                                        width: height

                                        layer.effect: ColorOverlay {
                                            color: root.lockscreenColors.primary
                                        }
                                    }
                                }
                            }
                        }
                        Item {
                            height: 30 * container.s
                            width: parent.width

                            TextMetrics {
                                id: passMetrics

                                font.family: root.fontName
                                font.letterSpacing: 0
                                font.pixelSize: 14 * container.s
                                text: "●"
                            }
                            TextInput {
                                id: passInput

                                property bool wasClicked: false

                                anchors.fill: parent
                                color: "transparent"
                                cursorVisible: false
                                echoMode: TextInput.Password
                                focus: true
                                font.family: root.fontName
                                font.letterSpacing: (18 * container.s) - passMetrics.advanceWidth
                                font.pixelSize: 14 * container.s
                                horizontalAlignment: TextInput.AlignRight
                                passwordCharacter: "●"
                                selectedTextColor: "transparent"
                                selectionColor: "transparent"
                                verticalAlignment: TextInput.AlignVCenter

                                cursorDelegate: Item {
                                    height: 0
                                    width: 0
                                }

                                Keys.onReturnPressed: {
                                    container.startLoginSequence();
                                }
                                onTextChanged: {
                                    if (pam.hasError) {
                                        pam.hasError = false;
                                        errText.text = "";
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    layoutDirection: Qt.LeftToRight
                                    spacing: 0

                                    Repeater {
                                        model: 64

                                        Item {
                                            height: 12 * container.s
                                            opacity: index < passInput.text.length ? 1 : 0
                                            width: (index < passInput.text.length) ? (18 * container.s) : 0

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 250
                                                    easing.type: Easing.InOutQuad
                                                }
                                            }
                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 150
                                                    easing.type: Easing.OutQuad
                                                }
                                            }

                                            Text {
                                                anchors.right: parent.right
                                                anchors.rightMargin: (18 * container.s - width) / 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: root.lockscreenColors.dimText
                                                font.family: root.fontName
                                                font.pixelSize: 14 * container.s
                                                text: "●"
                                            }
                                        }
                                    }
                                }
                                Text {
                                    id: waitingKeyText

                                    property real pulseOpacity: 0.4

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.lockscreenColors.waitingText
                                    font.family: root.fontName
                                    font.letterSpacing: 2 * container.s
                                    font.pixelSize: 10 * container.s
                                    opacity: passInput.text.length === 0 ? pulseOpacity : 0
                                    text: "WAITING FOR KEY"

                                    SequentialAnimation on pulseOpacity {
                                        loops: Animation.Infinite
                                        running: passInput.text.length === 0

                                        NumberAnimation {
                                            duration: 700
                                            easing.type: Easing.InOutSine
                                            from: 0.18
                                            to: 0.78
                                        }
                                        NumberAnimation {
                                            duration: 700
                                            easing.type: Easing.InOutSine
                                            from: 0.78
                                            to: 0.18
                                        }
                                    }
                                }
                                Rectangle {
                                    id: needleCursor

                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.lockscreenColors.text
                                    height: 12 * container.s
                                    visible: passInput.focus && (passInput.text.length > 0 || passInput.wasClicked)
                                    width: 1.5 * container.s
                                    x: passInput.cursorRectangle.x

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutQuad
                                        }
                                    }

                                    SequentialAnimation {
                                        loops: Animation.Infinite
                                        running: needleCursor.visible

                                        NumberAnimation {
                                            duration: 450
                                            from: 1
                                            property: "opacity"
                                            target: needleCursor
                                            to: 0.1
                                        }
                                        NumberAnimation {
                                            duration: 450
                                            from: 0.1
                                            property: "opacity"
                                            target: needleCursor
                                            to: 1
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.ArrowCursor

                                onClicked: {
                                    passInput.forceActiveFocus();
                                    passInput.wasClicked = true;
                                }
                            }
                        }
                        Item {
                            height: 24 * container.s
                            width: parent.width

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                color: root.lockscreenColors.secondaryText
                                font.family: root.fontName
                                font.letterSpacing: 5 * container.s
                                font.pixelSize: 14 * container.s
                                font.weight: Font.ExtraBold
                                text: root.username.toUpperCase()
                            }
                        }
                        Text {
                            id: errText

                            color: root.lockscreenColors.error
                            font.family: root.fontName
                            font.letterSpacing: 2 * container.s
                            font.pixelSize: 10 * container.s
                            height: 15 * container.s
                            horizontalAlignment: Text.AlignRight
                            text: ""
                            verticalAlignment: Text.AlignBottom
                            width: parent.width
                        }
                    }
                }

                // Handle PAM events relative to this screen's visuals
                Connections {
                    function onCompleted(result) {
                        if (result === PamResult.Success) {
                            container.startUnlockSequence();
                        } else {
                            errText.text = "ACCESS DENIED";
                            passInput.text = "";
                            passInput.forceActiveFocus();
                            shake.start();
                        }
                    }
                    function onError(error) {
                        errText.text = "AUTHENTICATION ERROR";
                        passInput.text = "";
                        passInput.forceActiveFocus();
                        shake.start();
                    }

                    target: pam
                }
                SequentialAnimation {
                    id: shake

                    NumberAnimation {
                        duration: 50
                        easing.type: Easing.InOutSine
                        from: 0
                        property: "shakeOffset"
                        target: loginPanel
                        to: 10 * container.s
                    }
                    NumberAnimation {
                        duration: 50
                        easing.type: Easing.InOutSine
                        property: "shakeOffset"
                        target: loginPanel
                        to: -10 * container.s
                    }
                    NumberAnimation {
                        duration: 50
                        easing.type: Easing.InOutSine
                        property: "shakeOffset"
                        target: loginPanel
                        to: 0
                    }
                }
                IdleDimShade {
                    anchors.fill: parent
                    z: 100000
                }
            }
        }
    }
    Timer {
        id: faceRetryTimer

        interval: 900

        onTriggered: {
            if (!root.faceUnlockAvailable || pam.faceFallbackOnly || pam.faceAttempts >= pam.maxFaceAttempts)
                return;
            if (pam.passwordToSubmit !== "")
                return;
            if (pam.active)
                pam.abort();
            pam.beginAuthentication();
        }
    }

    // PAM Authentication Manager (Global session-wide service)
    PamContext {
        id: pam

        property bool authenticating: false
        property int faceAttempts: 0
        property bool faceFallbackOnly: true
        property string faceState: "idle"
        property string faceStatus: ""
        property bool hasError: false
        readonly property int maxFaceAttempts: Math.max(1, Math.min(3, Number(root.settingValue("lockFaceMaxAttempts", 3))))
        property bool passwordAttempt: false
        property string passwordToSubmit: ""
        property string verifiedMethod: ""

        function beginAuthentication() {
            if (pam.active)
                return;

            var useFace = root.faceUnlockAvailable && !faceFallbackOnly && faceAttempts < maxFaceAttempts;
            pam.config = useFace ? "quickshell" : "login";
            if (useFace) {
                verifiedMethod = "";
                faceAttempts += 1;
                faceState = "scanning";
                faceStatus = "LOOK AT CAMERA · " + faceAttempts + "/" + maxFaceAttempts;
            } else {
                faceState = root.faceUnlockAvailable ? "password" : "idle";
                faceStatus = root.faceUnlockAvailable ? "ENTER PASSWORD" : "";
            }
            pam.start();
        }
        function retryFaceAuthentication() {
            if (!root.faceUnlockAvailable || root.authenticationGranted)
                return;
            faceRetryTimer.stop();
            if (pam.active)
                pam.abort();
            authenticating = false;
            faceAttempts = 0;
            faceFallbackOnly = false;
            passwordAttempt = false;
            passwordToSubmit = "";
            verifiedMethod = "";
            hasError = false;
            pam.config = "quickshell";
            beginAuthentication();
        }
        function submitPassword(password) {
            hasError = false;
            authenticating = true;
            passwordAttempt = true;
            passwordToSubmit = password;
            verifiedMethod = "";
            faceFallbackOnly = true;
            faceRetryTimer.stop();
            if (pam.active)
                pam.abort();
            pam.config = "login";
            pam.start();
        }

        config: root.faceUnlockAvailable ? "quickshell" : "login"

        onCompleted: result => {
            var usedPassword = passwordAttempt;
            authenticating = false;
            passwordToSubmit = "";
            if (result === PamResult.Success) {
                faceRetryTimer.stop();
                verifiedMethod = usedPassword ? "password" : "face";
                faceState = root.faceUnlockAvailable ? "matched" : "idle";
                faceStatus = root.faceUnlockAvailable ? (usedPassword ? "PASSWORD VERIFIED" : "FACE VERIFIED") : "";
                root.authenticationGranted = true;
            } else {
                verifiedMethod = "";
                hasError = true;
                if (usedPassword || faceAttempts >= maxFaceAttempts) {
                    faceFallbackOnly = true;
                    faceState = root.faceUnlockAvailable ? "password" : "idle";
                    faceStatus = root.faceUnlockAvailable ? "ENTER PASSWORD" : "";
                } else if (root.faceUnlockAvailable) {
                    faceState = "scanning";
                    faceStatus = "RETRYING FACE SCAN · " + (faceAttempts + 1) + "/" + maxFaceAttempts;
                    faceRetryTimer.restart();
                }
            }
            passwordAttempt = false;
        }
        onError: error => {
            authenticating = false;
        }
        onPamMessage: {
            var lowerMessage = String(pam.message || "").toLowerCase();
            if (!passwordAttempt && lowerMessage.indexOf("attempting facial authentication") !== -1) {
                faceState = "scanning";
                faceStatus = "LOOK AT CAMERA · " + faceAttempts + "/" + maxFaceAttempts;
            } else if (!passwordAttempt && lowerMessage.indexOf("identified face") !== -1) {
                verifiedMethod = "face";
                faceState = "matched";
                faceStatus = "FACE VERIFIED";
            }

            if (pam.responseRequired) {
                if (passwordToSubmit !== "") {
                    faceRetryTimer.stop();
                    pam.respond(passwordToSubmit);
                    passwordToSubmit = "";
                } else {
                    if (root.faceUnlockAvailable && !faceFallbackOnly && faceAttempts < maxFaceAttempts) {
                        faceState = "scanning";
                        faceStatus = "RETRYING FACE SCAN · " + (faceAttempts + 1) + "/" + maxFaceAttempts;
                        faceRetryTimer.restart();
                    } else {
                        faceFallbackOnly = true;
                        faceState = root.faceUnlockAvailable ? "password" : "idle";
                        faceStatus = root.faceUnlockAvailable ? "ENTER PASSWORD" : "";
                    }
                }
            }
        }
    }
}
