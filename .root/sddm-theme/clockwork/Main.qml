import QtQuick
import QtQuick.Window
import Qt.labs.folderlistmodel
import SddmComponents 2.0

// Theme
Rectangle {
    id: root
    readonly property real s: Screen.height / 768
    width: Screen.width
    height: Screen.height
    color: root.bgColor

    // Quickshell
    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined

    // Config
    readonly property bool enableWindup: config.enableWindup === "true"
    readonly property bool isLight: false

    readonly property color bgColor: "#000000"
    readonly property color mainText: "#ffffff"
    readonly property color dimText: "#666666"
    readonly property color subColor: "#555555"
    readonly property color pillColor: "#080808"
    readonly property color pillBorder: root.isWindup ? "#444444" : "#1a1a1a"
    readonly property color pillInnerLine: root.isWindup ? "#ffffff" : "#222222"
    readonly property color sparkColor: "#ffffff"
    readonly property color userItemInactive: "#444444"
    readonly property color inputWaitColor: "#333333"

    // State
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property bool userMenuOpen: false
    property bool authenticating: false
    property bool isWindup: false
    property real uiOpacity: 0
    property real slideX: 0
    readonly property real marginR: 80 * s

    // Time
    property int curH: new Date().getHours()
    property int curM: new Date().getMinutes()
    property int curS: new Date().getSeconds()
    property int curMS: new Date().getMilliseconds()
    readonly property real localTimeMS: (curH * 3600000) + (curM * 60000) + (curS * 1000) + curMS

    FrameAnimation {
        running: true

        onTriggered: {
            var d = new Date()
            root.curH = d.getHours()
            root.curM = d.getMinutes()
            root.curS = d.getSeconds()
            root.curMS = d.getMilliseconds()
        }
    }

    // Animation
    property real windupOffset: 0
    property real windupProgress: windupOffset / 150000
    property real jitterX: 0
    property real jitterY: 0
    property real sparkIntensity: 0.0

    Timer {
        interval: 16
        running: root.isWindup
        repeat: true
        onTriggered: {
            var intensity = root.windupProgress * 32 * s
            root.jitterX = (Math.random() - 0.5) * intensity
            root.jitterY = (Math.random() - 0.5) * intensity
            root.sparkIntensity = root.windupProgress > 0.2 ? (root.windupProgress - 0.2) * 2.2 : 0
        }
    }

    NumberAnimation {
        id: windupAnim
        target: root
        property: "windupOffset"
        from: 0
        to: 150000
        duration: 1600
        easing.type: Easing.InQuint
    }

    ParallelAnimation {
        id: boomSequence
        NumberAnimation {
            target: root
            property: "slideX"
            to: 500 * root.s
            duration: 350
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "uiOpacity"
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    readonly property real smoothSecAngle: -((localTimeMS % 60000) / 60000.0) * 360.0 - windupOffset * 10.0
    readonly property real smoothMinAngle: -((localTimeMS % 3600000) / 3600000.0) * 360.0 - windupOffset * 5.0

    // Fonts
    FolderListModel {
        id: fontFolder
        folder: Qt.resolvedUrl("font")
        nameFilters: ["*.ttf", "*.otf"]
    }
    FontLoader {
        id: outfitFont
        source: fontFolder.count > 0 ? "font/" + fontFolder.get(0, "fileName") : ""
    }
    // Models
    ListView {
        id: userHelper
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: root.userIndex
        width: 1
        height: 1
        opacity: 0
        delegate: Item {
            property string uName: model.realName || model.name || ""
            property string uLogin: model.name || ""
        }
    }
    ListView {
        id: sessionHelper
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: root.sessionIndex
        width: 1
        height: 1
        opacity: 0
        delegate: Item {
            property string sName: model.name || ""
        }
    }

    // Focus
    Timer { interval: 300; running: true; onTriggered: passInput.forceActiveFocus() }

    Component.onCompleted: {
        fadeIn.start()
    }
    NumberAnimation {
        id: fadeIn
        target: root
        property: "uiOpacity"
        to: 1
        duration: 350
        easing.type: Easing.OutCubic
    }

    // Core
    Item {
        id: blastContainer
        anchors.fill: parent
        opacity: root.uiOpacity
        x: root.jitterX - root.slideX
        y: root.jitterY

        Item {
            id: clockContainer
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 800 * s
            height: parent.height
            readonly property real cx: 40 * s 
            readonly property real cy: height * 0.5
            readonly property real minR: 320 * s 
            readonly property real secR: 480 * s 

            Rectangle {
                id: indicatorPill
                z: 1
                x: clockContainer.cx + 230 * s
                anchors.verticalCenter: parent.verticalCenter
                width: 330 * s
                height: 90 * s
                radius: 45 * s
                color: root.pillColor
                border.color: root.pillBorder
                border.width: 1 * s
                Rectangle {
                    x: 170 * s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1 * s
                    height: 35 * s
                    color: root.pillInnerLine
                }
            }

            Repeater {
                model: 60
                delegate: Rectangle {
                    z: 50
                    property real randA: Math.random() * 6.28
                    property real randV: 400 * s + Math.random() * 900 * s
                    x: (clockContainer.cx + 400 * s) + Math.cos(randA) * (randV * root.sparkIntensity)
                    y: (clockContainer.cy) + Math.sin(randA) * (randV * root.sparkIntensity)
                    width: (1 + Math.random() * 2) * s
                    height: (1 + 12 * root.sparkIntensity) * s 
                    rotation: randA * 180 / Math.PI + 90
                    radius: width / 2
                    color: root.sparkColor
                    opacity: root.sparkIntensity * (Math.random() > 0.4 ? 1.0 : 0.2)
                    visible: root.sparkIntensity > 0
                }
            }

            Item {
                id: minuteRing
                anchors.fill: parent
                z: 10

                transform: Rotation {
                    origin.x: clockContainer.cx
                    origin.y: clockContainer.cy
                    angle: root.smoothMinAngle
                }

                Repeater {
                    model: 60

                    delegate: Item {
                        property real base: index * 6
                        property real disp: base * Math.PI / 180
                        property bool isMajor: index % 5 === 0

                        Rectangle {
                            x: clockContainer.cx + clockContainer.minR * Math.cos(parent.disp) - width / 2
                            y: clockContainer.cy + clockContainer.minR * Math.sin(parent.disp) - height / 2
                            width: parent.isMajor ? 2 * s : 1 * s
                            height: parent.isMajor ? 18 * s : 10 * s
                            color: parent.isMajor ? "#4dffffff" : "#26ffffff"
                            rotation: parent.base + 90
                        }

                        Text {
                            readonly property real nRad: clockContainer.minR - 35 * s
                            visible: parent.isMajor
                            x: clockContainer.cx + nRad * Math.cos(parent.disp) - width / 2
                            y: clockContainer.cy + nRad * Math.sin(parent.disp) - height / 2
                            text: String(index).padStart(2, '0')
                            font.family: outfitFont.name
                            font.pixelSize: 22 * s
                            font.weight: Font.ExtraBold
                            color: "#40ffffff"
                            rotation: parent.base
                            transformOrigin: Item.Center
                        }
                    }
                }
            }

            Item {
                id: secondRing
                anchors.fill: parent
                z: 10

                transform: Rotation {
                    origin.x: clockContainer.cx
                    origin.y: clockContainer.cy
                    angle: root.smoothSecAngle
                }

                Repeater {
                    model: 60

                    delegate: Item {
                        property real base: index * 6
                        property real disp: base * Math.PI / 180
                        property bool isMajor: index % 5 === 0

                        Rectangle {
                            x: clockContainer.cx + clockContainer.secR * Math.cos(parent.disp) - width / 2
                            y: clockContainer.cy + clockContainer.secR * Math.sin(parent.disp) - height / 2
                            width: parent.isMajor ? 1.5 * s : 1 * s
                            height: parent.isMajor ? 13 * s : 8 * s
                            color: parent.isMajor ? "#4dffffff" : "#26ffffff"
                            rotation: parent.base + 90
                        }

                        Text {
                            readonly property real nRad: clockContainer.secR - 30 * s
                            visible: parent.isMajor
                            x: clockContainer.cx + nRad * Math.cos(parent.disp) - width / 2
                            y: clockContainer.cy + nRad * Math.sin(parent.disp) - height / 2
                            text: String(index).padStart(2, '0')
                            font.family: outfitFont.name
                            font.pixelSize: 18 * s
                            font.weight: Font.ExtraBold
                            color: "#40ffffff"
                            rotation: parent.base
                            transformOrigin: Item.Center
                        }
                    }
                }
            }

            Rectangle {
                z: 11
                x: clockContainer.cx + clockContainer.minR - width / 2
                y: clockContainer.cy - height / 2
                width: 2 * s
                height: 18 * s
                radius: width / 2
                rotation: 90
                color: root.mainText
            }

            Rectangle {
                z: 11
                x: clockContainer.cx + clockContainer.secR - width / 2
                y: clockContainer.cy - height / 2
                width: 1.5 * s
                height: 13 * s
                radius: width / 2
                rotation: 90
                color: root.mainText
            }

            Text {
                anchors.right: indicatorPill.left
                anchors.rightMargin: 40 * s
                anchors.verticalCenter: parent.verticalCenter
                text: String(root.curH).padStart(2, '0')
                font.family: outfitFont.name
                font.pixelSize: 110 * s
                font.weight: Font.Black
                color: root.mainText
            }
            Column {
                anchors.left: indicatorPill.right
                anchors.leftMargin: 110 * s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * s
                Text {
                    text: Qt.formatDate(new Date(), "dd MMM yyyy").toUpperCase()
                    font.family: outfitFont.name
                    font.pixelSize: 20 * s
                    font.letterSpacing: 3 * s
                    font.weight: Font.Medium
                    color: root.subColor
                }
                Text {
                    text: Qt.formatDate(new Date(), "dddd").toUpperCase()
                    font.family: outfitFont.name
                    font.pixelSize: 50 * s
                    font.letterSpacing: 8 * s
                    font.weight: Font.ExtraBold
                    color: root.mainText
                }
            }
        }
    }

    // UI
    Item {
        id: hudContainer
        anchors.fill: parent
        opacity: root.uiOpacity
        transform: Translate {
            x: root.slideX
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.marginR
            anchors.top: parent.top
            anchors.topMargin: 50 * s
            spacing: 25 * s
            CwAction {
                visible: !root.isQuickshell
                label: (sessionHelper.currentItem ? sessionHelper.currentItem.sName : "Session")
                onClicked: {
                    if (typeof sessionModel !== "undefined") root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
                }
            }
            Rectangle {
                visible: !root.isQuickshell
                width: 1 * s
                height: 10 * s
                color: root.pillBorder
                anchors.verticalCenter: parent.verticalCenter
            }
            CwAction {
                label: "Reboot"
                onClicked: {
                    if (typeof sddm !== "undefined") sddm.reboot()
                }
            }
            Rectangle {
                width: 1 * s
                height: 10 * s
                color: root.pillBorder
                anchors.verticalCenter: parent.verticalCenter
            }
            CwAction {
                label: "Shutdown"
                onClicked: {
                    if (typeof sddm !== "undefined") sddm.powerOff()
                }
            }
        }
        Column {
            id: loginPanel
            anchors.right: parent.right
            anchors.rightMargin: root.marginR
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 80 * s
            width: 350 * s
            spacing: 8 * s
            Item {
                width: parent.width
                height: 32 * s
                z: 5000
                Item {
                    id: uMenuContainer
                    anchors.bottom: userNameDisp.top
                    anchors.bottomMargin: 15 * s
                    anchors.right: parent.right
                    width: 280 * s
                    height: root.userMenuOpen ? ((typeof userModel !== "undefined" ? userModel.rowCount() : 0) * 30 * s) + 20 * s : 0
                    clip: true
                    Behavior on height {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                    }
                    Column {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        spacing: 6 * s
                        Repeater {
                            model: typeof userModel !== "undefined" ? userModel : null
                            delegate: Item {
                                width: 260 * s
                                height: 26 * s
                                property bool itemHover: uItemMa.containsMouse
                                Text {
                                    id: uItemTxt
                                    text: (model.realName || model.name || "").toUpperCase()
                                    font.family: outfitFont.name
                                    font.pixelSize: 13 * s
                                    font.letterSpacing: 2 * s
                                    color: (root.userIndex === index || itemHover) ? root.mainText : root.userItemInactive
                                    anchors.right: parent.right
                                    anchors.rightMargin: itemHover ? 30 * s : 10 * s
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on anchors.rightMargin {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                                Text {
                                    text: "✦"
                                    anchors.left: uItemTxt.right
                                    anchors.leftMargin: 8 * s
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.mainText
                                    opacity: itemHover ? 1.0 : 0
                                    font.pixelSize: 10 * s
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                                MouseArea {
                                    id: uItemMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.userIndex = index
                                        root.userMenuOpen = false
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    id: userNameDisp
                    anchors.right: parent.right
                    anchors.rightMargin: (uMa.containsMouse || root.userMenuOpen) ? 25 * s : 0
                    text: ((userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName : ((typeof userModel !== "undefined" && userModel.lastUser) ? capitalizeFirst(userModel.lastUser) : "USER")).toUpperCase()
                    font.family: outfitFont.name
                    font.pixelSize: 18 * s
                    font.weight: Font.Bold
                    font.letterSpacing: 8 * s
                    color: (uMa.containsMouse || root.userMenuOpen) ? root.mainText : root.dimText
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on anchors.rightMargin {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Text {
                    text: "✦"
                    anchors.left: userNameDisp.right
                    anchors.leftMargin: 8 * s
                    anchors.verticalCenter: userNameDisp.verticalCenter
                    color: root.mainText
                    opacity: (uMa.containsMouse || root.userMenuOpen) ? 1.0 : 0
                    font.pixelSize: 12 * s
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
                MouseArea {
                    id: uMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.userMenuOpen = !root.userMenuOpen
                    }
                }
            }
            Item {
                width: parent.width
                height: 30 * s

                TextMetrics {
                    id: passMetrics
                    font.family: outfitFont.name
                    font.letterSpacing: 0
                    font.pixelSize: 14 * s
                    text: "✦"
                }

                TextInput {
                    id: passInput
                    property bool wasClicked: false

                    anchors.fill: parent
                    echoMode: TextInput.Password
                    passwordCharacter: "✦"
                    color: "transparent"
                    font.family: outfitFont.name
                    font.pixelSize: 14 * s
                    font.letterSpacing: (22 * s) - passMetrics.advanceWidth
                    horizontalAlignment: TextInput.AlignRight
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    cursorVisible: false
                    selectedTextColor: "transparent"
                    selectionColor: "transparent"

                    cursorDelegate: Item {
                        width: 0
                        height: 0
                    }

                    Keys.onReturnPressed: {
                        startLoginSequence()
                    }

                    onTextChanged: {
                        if (errText.text !== "")
                            errText.text = ""
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Repeater {
                            model: 64

                            Item {
                                width: index < passInput.text.length ? 22 * s : 0
                                height: 12 * s
                                opacity: index < passInput.text.length ? 1 : 0

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.InOutQuad
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: (22 * s - width) / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.dimText
                                    font.family: outfitFont.name
                                    font.pixelSize: 20 * s
                                    text: "✦"
                                }
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WAITING FOR KEY"
                        font.family: outfitFont.name
                        font.pixelSize: 10 * s
                        font.letterSpacing: 4 * s
                        color: root.inputWaitColor
                        
                        opacity: passInput.text.length === 0 ? 0.4 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                    Rectangle {
                        id: needleCursor
                        width: 1.5 * s
                        height: 12 * s
                        color: root.mainText
                        anchors.verticalCenter: parent.verticalCenter
                        x: passInput.cursorRectangle.x
                        visible: passInput.focus && (passInput.text.length > 0 || passInput.wasClicked)

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
                                target: needleCursor
                                property: "opacity"
                                from: 1
                                to: 0.1
                                duration: 450
                            }

                            NumberAnimation {
                                target: needleCursor
                                property: "opacity"
                                from: 0.1
                                to: 1
                                duration: 450
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.ArrowCursor
                    onClicked: {
                        passInput.forceActiveFocus()
                        passInput.wasClicked = true
                    }
                }
            }
            Item {
                width: parent.width
                height: 40 * s
                Text {
                    id: loginBtn
                    anchors.right: parent.right
                    anchors.rightMargin: btnMa.containsMouse ? 25 * s : 0
                    text: root.authenticating ? "CHECKING KEY" : "ENTER KEY"
                    font.family: outfitFont.name
                    font.pixelSize: 11 * s
                    font.letterSpacing: 4 * s
                    font.weight: Font.Bold
                    color: passInput.text.length > 0 ? (btnMa.containsMouse ? root.mainText : root.dimText) : "transparent"
                    opacity: passInput.text.length > 0 ? 1.0 : 0
                    Behavior on anchors.rightMargin {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Text {
                    text: "✦"
                    anchors.left: loginBtn.right
                    anchors.leftMargin: 8 * s
                    anchors.verticalCenter: loginBtn.verticalCenter
                    color: root.mainText
                    opacity: (btnMa.containsMouse && passInput.text.length > 0) ? 1.0 : 0
                    font.pixelSize: 10 * s
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
                MouseArea {
                    id: btnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        startLoginSequence()
                    }
                }
            }
            Text {
                id: errText
                width: parent.width
                height: 15 * s
                verticalAlignment: Text.AlignBottom
                horizontalAlignment: Text.AlignRight
                text: ""
                color: "#ff4444"
                font.family: outfitFont.name
                font.pixelSize: 10 * s
                font.letterSpacing: 2 * s
            }
        }
    }

    Timer {
        id: boomTriggerTimer
        interval: 1450
        onTriggered: {
            boomSequence.start()
        }
    }
    function startLoginSequence() {
        if (passInput.text.length === 0 || root.authenticating)
            return

        doLogin()
    }
    function doLogin() {
        var uname = (userHelper.currentItem && userHelper.currentItem.uLogin) ? userHelper.currentItem.uLogin : (typeof userModel !== "undefined" ? userModel.lastUser : "user")
        if (typeof sddm !== "undefined") {
            root.authenticating = true
            sddm.login(uname, passInput.text, root.sessionIndex)
        }
    }
    function capitalizeFirst(str) {
        if (!str) return ""
        return str.charAt(0).toUpperCase() + str.slice(1)
    }
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginSucceeded() {
            root.authenticating = false
            if (root.enableWindup) {
                isWindup = true
                windupAnim.start()
                boomTriggerTimer.start()
            }
        }
        function onLoginFailed() {
            root.authenticating = false
            isWindup = false
            windupAnim.stop()
            boomTriggerTimer.stop()
            root.windupOffset = 0
            root.slideX = 0
            root.uiOpacity = 1
            root.sparkIntensity = 0
            errText.text = "ACCESS DENIED"
            passInput.text = ""
            passInput.forceActiveFocus()
            shake.start()
        }
    }
    SequentialAnimation {
        id: shake
        NumberAnimation {
            target: loginPanel
            property: "anchors.rightMargin"
            from: root.marginR
            to: root.marginR + 10 * s
            duration: 50
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: loginPanel
            property: "anchors.rightMargin"
            to: root.marginR - 10 * s
            duration: 50
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: loginPanel
            property: "anchors.rightMargin"
            to: root.marginR
            duration: 50
            easing.type: Easing.InOutSine
        }
    }
    component CwAction: Item {
        id: actItem
        width: actTxt.width + 20 * s
        height: 15 * s
        property string label: ""
        signal clicked()
        Text {
            id: actTxt
            anchors.right: parent.right
            anchors.rightMargin: actM.containsMouse ? 15 * s : 0
            text: label.toUpperCase()
            color: actM.containsMouse ? root.mainText : root.dimText
            font.family: outfitFont.name
            font.pixelSize: 10 * s
            font.letterSpacing: 3 * s
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: 200
                }
            }
        }
        Text {
            text: "✦"
            anchors.left: actTxt.right
            anchors.leftMargin: 4 * s
            anchors.verticalCenter: actTxt.verticalCenter
            color: root.mainText
            opacity: actM.containsMouse ? 1.0 : 0
            font.pixelSize: 8 * s
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }
        MouseArea {
            id: actM
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                actItem.clicked()
            }
            cursorShape: Qt.PointingHandCursor
        }
    }
}
