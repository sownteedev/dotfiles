import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import quickshell
import "../../service"

ShellRoot {
    id: root

    readonly property color bgColor: isLight ? "#ffffff" : Config.md3.background
    readonly property color blastColor: isLight ? "#000000" : Config.md3.on_surface
    // Time
    property int curH: new Date().getHours()
    property int curM: new Date().getMinutes()
    property int curMS: new Date().getMilliseconds()
    property int curS: new Date().getSeconds()
    readonly property color dimText: isLight ? "#666666" : Config.md3.on_surface_variant
    readonly property bool enableWindup: true
    // Fonts
    readonly property string fontName: Config.fontName
    readonly property color inputWaitColor: isLight ? "#bbbbbb" : Config.md3.surface_container
    readonly property bool isLight: themeMode === "light"
    // State
    property bool isWindup: false
    readonly property real localTimeMS: (curH * 3.6e+06) + (curM * 60000) + (curS * 1000) + curMS
    readonly property color mainText: isLight ? "#000000" : Config.md3.on_surface
    readonly property string lockMarkerPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-wallpaper-lock.active"
    readonly property color pillBorder: isLight ? (root.isWindup ? "#aaaaaa" : "#cccccc") : (root.isWindup ? Config.md3.surface_container_highest : Config.md3.surface_container)
    readonly property color pillColor: isLight ? "#e8e8e8" : Config.md3.surface
    readonly property color pillInnerLine: isLight ? (root.isWindup ? "#000000" : "#bbbbbb") : (root.isWindup ? Config.md3.on_surface : Config.md3.surface_container_high)
    readonly property color sparkColor: isLight ? "#000000" : Config.md3.on_surface
    readonly property color subColor: isLight ? "#666666" : Config.md3.outline
    // Config
    readonly property string themeMode: "dark"
    readonly property color userItemInactive: isLight ? "#cccccc" : Config.md3.surface_container_high
    property string username: Quickshell.env("USER") || "sownteedev"

    Component.onCompleted: {
        // Lockscreen is launched as a separate Quickshell process. Starting
        // WallpaperService here also starts its own mpvpaper instance, which
        // replaces the desktop-owned player and then dies again on unlock.
        // The lock screen already uses the generated /tmp/backdrop-lock.png.
        ThemeService.reloadTheme();
    }
    Component.onDestruction: {
        lockMarker.running = false;
        Quickshell.execDetached(["rm", "-f", lockMarkerPath]);
    }

    Process {
        id: lockMarker

        command: ["python3", "-c", "import pathlib,signal,sys; p=pathlib.Path(sys.argv[1]); p.touch(); done=lambda *_:(p.unlink(missing_ok=True),sys.exit(0)); signal.signal(signal.SIGTERM,done); signal.signal(signal.SIGINT,done); signal.pause()", root.lockMarkerPath]
        running: true
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
                lockMarker.running = false;
                Quickshell.execDetached(["rm", "-f", root.lockMarkerPath]);
                Qt.quit();
            }
        }

        // The surface created for each screen
        WlSessionLockSurface {
            id: lockSurface

            color: "#000000"

            Item {
                id: container

                property real jitterX: 0
                property real jitterY: 0
                readonly property real marginR: 80 * s
                readonly property real s: height / 768
                property real slideX: 0
                readonly property real smoothMinAngle: -((root.localTimeMS % 3.6e+06) / 3.6e+06) * 360 - windupOffset * 5
                readonly property real smoothSecAngle: -((root.localTimeMS % 60000) / 60000) * 360 - windupOffset * 10
                property real sparkIntensity: 0
                // Animation parameters per screen
                property real windupOffset: 0
                property real windupProgress: windupOffset / 150000

                function startLoginSequence() {
                    if (passInput.text.length === 0 || pam.authenticating)
                        return;

                    pam.submitPassword(passInput.text);
                }

                height: lockSurface.height
                width: lockSurface.width

                Component.onCompleted: {
                    fadeIn.start();
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
                        Qt.quit();
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
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: "file:///tmp/backdrop-lock.png"

                    onStatusChanged: {
                        if (status === Image.Error)
                            source = "file://" + Config.wallpaper;
                    }
                }

                // Dark overlay
                Rectangle {
                    anchors.fill: parent
                    color: root.isLight ? '#44ffffff' : '#45000000'
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

                        Rectangle {
                            id: indicatorPill

                            anchors.verticalCenter: parent.verticalCenter
                            border.color: root.pillBorder
                            border.width: 1 * container.s
                            color: root.pillColor
                            height: 90 * container.s
                            radius: 45 * container.s
                            width: 330 * container.s
                            x: clockContainer.cx + 230 * container.s
                            z: 1

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.pillInnerLine
                                height: 35 * container.s
                                width: 1 * container.s
                                x: 170 * container.s
                            }
                        }
                        Repeater {
                            model: 60

                            delegate: Rectangle {
                                property real randA: Math.random() * 6.28
                                property real randV: 400 * container.s + Math.random() * 900 * container.s

                                color: root.sparkColor
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
                                    color: root.isLight ? Qt.rgba(0, 0, 0, spotlight > 0 ? 1 : (isMajor ? 0.8 : 0.6)) : Qt.rgba(1, 1, 1, spotlight > 0 ? 1 : (isMajor ? 0.3 : 0.15))
                                    height: isMajor ? 18 * container.s : 10 * container.s
                                    rotation: disp * 180 / Math.PI + 90
                                    width: isMajor ? 2 * container.s : 1 * container.s
                                    x: parent.tx - width / 2
                                    y: parent.ty - height / 2
                                }
                                Text {
                                    property real nRad: clockContainer.minR - 35 * container.s

                                    color: root.isLight ? Qt.rgba(0, 0, 0, spotlight > 0 ? (0.6 + 0.4 * spotlight) : 0.6) : Qt.rgba(1, 1, 1, spotlight > 0 ? (0.4 + spotlight * 0.6) : 0.25)
                                    font.family: root.fontName
                                    font.pixelSize: 22 * container.s
                                    font.weight: spotlight > 0.5 ? Font.ExtraBold : Font.ExtraBold
                                    rotation: disp * 180 / Math.PI
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
                                    color: root.isLight ? Qt.rgba(0, 0, 0, spotlight > 0 ? 1 : (isMajor ? 0.8 : 0.6)) : Qt.rgba(1, 1, 1, spotlight > 0 ? 1 : (isMajor ? 0.3 : 0.15))
                                    height: isMajor ? 13 * container.s : 8 * container.s
                                    rotation: disp * 180 / Math.PI + 90
                                    width: isMajor ? 1.5 * container.s : 1 * container.s
                                    x: parent.tx - width / 2
                                    y: parent.ty - height / 2
                                }
                                Text {
                                    property real nRad: clockContainer.secR - 30 * container.s

                                    color: root.isLight ? Qt.rgba(0, 0, 0, spotlight > 0 ? (0.6 + 0.4 * spotlight) : 0.6) : Qt.rgba(1, 1, 1, spotlight > 0 ? (0.4 + spotlight * 0.6) : 0.25)
                                    font.family: root.fontName
                                    font.pixelSize: 18 * container.s
                                    font.weight: spotlight > 0.5 ? Font.ExtraBold : Font.ExtraBold
                                    rotation: disp * 180 / Math.PI
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
                            color: root.mainText
                            font.family: root.fontName
                            font.pixelSize: 110 * container.s
                            font.weight: Font.Black
                            text: String(Config.clock24h ? root.curH : (root.curH % 12 || 12)).padStart(2, '0')
                        }
                        Column {
                            anchors.left: indicatorPill.right
                            anchors.leftMargin: 110 * container.s
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5 * container.s

                            Text {
                                color: root.subColor
                                font.family: root.fontName
                                font.letterSpacing: 3 * container.s
                                font.pixelSize: 20 * container.s
                                font.weight: Font.Medium
                                text: Qt.formatDate(new Date(), "dd MMM yyyy").toUpperCase()
                            }
                            Text {
                                color: root.mainText
                                font.family: root.fontName
                                font.letterSpacing: 8 * container.s
                                font.pixelSize: 50 * container.s
                                font.weight: Font.ExtraBold
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
                        id: loginPanel

                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 80 * container.s
                        anchors.right: parent.right
                        anchors.rightMargin: container.marginR
                        spacing: 8 * container.s
                        width: 350 * container.s

                        transform: Translate {
                            x: container.slideX
                        }

                        Item {
                            height: 32 * container.s
                            width: parent.width
                            z: 5000

                            Text {
                                id: userNameDisp

                                anchors.right: parent.right
                                anchors.rightMargin: 0
                                color: "transparent"
                                font.family: root.fontName
                                font.letterSpacing: 5 * container.s
                                font.pixelSize: 18 * container.s
                                font.weight: Font.Bold
                                text: root.username.toUpperCase()
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
                                text: "✦"
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
                                font.letterSpacing: (22 * container.s) - passMetrics.advanceWidth
                                font.pixelSize: 14 * container.s
                                horizontalAlignment: TextInput.AlignRight
                                passwordCharacter: "✦"
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
                                            width: (index < passInput.text.length) ? (22 * container.s) : 0

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
                                                anchors.rightMargin: (22 * container.s - width) / 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: root.dimText
                                                font.family: root.fontName
                                                font.pixelSize: 20 * container.s
                                                text: "✦"
                                            }
                                        }
                                    }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.inputWaitColor
                                    font.family: root.fontName
                                    font.letterSpacing: 4 * container.s
                                    font.pixelSize: 10 * container.s
                                    opacity: passInput.text.length === 0 ? 0.4 : 0
                                    text: "WAITING FOR KEY"

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 400
                                            easing.type: Easing.InOutSine
                                        }
                                    }
                                }
                                Rectangle {
                                    id: needleCursor

                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.mainText
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
                            height: 40 * container.s
                            width: parent.width

                            Text {
                                id: loginBtn

                                anchors.right: parent.right
                                anchors.rightMargin: btnMa.containsMouse ? 25 * container.s : 0
                                color: passInput.text.length > 0 ? (btnMa.containsMouse ? root.mainText : root.dimText) : "transparent"
                                font.family: root.fontName
                                font.letterSpacing: 4 * container.s
                                font.pixelSize: 11 * container.s
                                font.weight: Font.Bold
                                opacity: passInput.text.length > 0 ? 1 : 0
                                text: pam.authenticating ? "CHECKING KEY" : "ENTER KEY"

                                Behavior on anchors.rightMargin {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            Text {
                                anchors.left: loginBtn.right
                                anchors.leftMargin: 8 * container.s
                                anchors.verticalCenter: loginBtn.verticalCenter
                                color: root.mainText
                                font.pixelSize: 10 * container.s
                                opacity: (btnMa.containsMouse && passInput.text.length > 0) ? 1 : 0
                                text: "✦"

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }
                            }
                            MouseArea {
                                id: btnMa

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: {
                                    container.startLoginSequence();
                                }
                            }
                        }
                        Text {
                            id: errText

                            color: Config.md3.error
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
                            if (root.enableWindup) {
                                root.isWindup = true;
                                windupAnim.start();
                                boomTriggerTimer.start();
                            } else {
                                sessionLock.locked = false;
                                Qt.quit();
                            }
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
                        from: container.marginR
                        property: "anchors.rightMargin"
                        target: loginPanel
                        to: container.marginR + 10 * container.s
                    }
                    NumberAnimation {
                        duration: 50
                        easing.type: Easing.InOutSine
                        property: "anchors.rightMargin"
                        target: loginPanel
                        to: container.marginR - 10 * container.s
                    }
                    NumberAnimation {
                        duration: 50
                        easing.type: Easing.InOutSine
                        property: "anchors.rightMargin"
                        target: loginPanel
                        to: container.marginR
                    }
                }
            }
        }
    }

    // PAM Authentication Manager (Global session-wide service)
    PamContext {
        id: pam

        property bool authenticating: false
        property bool hasError: false
        property string passwordToSubmit: ""

        function submitPassword(password) {
            hasError = false;
            authenticating = true;
            passwordToSubmit = password;
            if (pam.active) {
                if (pam.responseRequired) {
                    pam.respond(password);
                    passwordToSubmit = "";
                }
            } else {
                pam.start();
            }
        }

        Component.onCompleted: {
            pam.start();
        }
        onCompleted: result => {
            authenticating = false;
            passwordToSubmit = "";
            if (result !== PamResult.Success) {
                hasError = true;
                pam.start();
            }
        }
        onError: error => {
            authenticating = false;
            passwordToSubmit = "";
            hasError = true;
            pam.start();
        }
        onPamMessage: {
            if (pam.responseRequired) {
                if (passwordToSubmit !== "") {
                    pam.respond(passwordToSubmit);
                    passwordToSubmit = "";
                }
            }
        }
    }
}
