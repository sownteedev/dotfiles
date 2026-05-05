import QtQuick
import Qt5Compat.GraphicalEffects
import QtMultimedia
import Qt.labs.folderlistmodel

Item {
    id: root
    width: 1920
    height: 1080
    readonly property real s: Screen.height / 1080

    // Quickshell
    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined

    // Colors
    readonly property color textPrimary:   "#fffdf5"
    readonly property color textSecondary: "#a89e8d"
    readonly property color accent:        "#f7c594"
    readonly property color glassBg:       Qt.rgba(1, 1, 1, 0.035)

    // State
    property int  userIndex:    (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property int  sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property bool loginError:   false
    property bool userMenuOpen: false

    // Fonts
    FolderListModel { id: fontFolder; folder: Qt.resolvedUrl("font"); nameFilters: ["*.ttf", "*.otf"] }
    FontLoader      { id: mainFont;  source: fontFolder.count > 0 ? "font/" + fontFolder.get(0, "fileName") : "" }

    // Helpers
    ListView { id: sessionHelper; model: typeof sessionModel !== "undefined" ? sessionModel : null; currentIndex: root.sessionIndex; opacity: 0; width: 1; height: 1; z: -100; delegate: Item { property string sName: model.name || "" } }
    ListView { id: userHelper;    model: typeof userModel !== "undefined" ? userModel : null;    currentIndex: root.userIndex;    opacity: 0; width: 1; height: 1; z: -100; delegate: Item { property string uName: model.realName || model.name || ""; property string uLogin: model.name || "" } }

    function login() {
        var n = (userHelper.currentItem && userHelper.currentItem.uName !== "") ? userHelper.currentItem.uLogin : (typeof userModel !== "undefined" ? userModel.lastUser : "")
        if (typeof sddm !== "undefined") sddm.login(n, passInput.text, root.sessionIndex)
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            root.loginError = true
            errText.text = "ACCESS DENIED"
            passInput.text = ""
            errorShake.start()
            passInput.forceActiveFocus()
        }
    }

    Timer { 
        interval: 300
        running: true
        onTriggered: passInput.forceActiveFocus() 
    }

    // Environment
    Rectangle { anchors.fill: parent; color: "#0a0a09"; z: -2000 }
    MediaPlayer { id: player; source: "bg.mp4"; videoOutput: bgVideo; loops: MediaPlayer.Infinite; Component.onCompleted: player.play() }
    VideoOutput { id: bgVideo; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop; z: -1000 }

    Rectangle {
        anchors.fill: parent
        z: -800
        opacity: 0.18
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: "#33f7c594" }
        }
    }

    // Effect
    Repeater {
        model: 24
        delegate: Item {
            id: mote
            property real sx: Math.random() * root.width * 0.7 + root.width * 0.1
            property real sy: Math.random() * root.height
            property real dr: (Math.random() - 0.5) * 40
            property real dur: 14000 + Math.random() * 16000
            property real sz: (1.5 + Math.random() * 2.5) * s
            x: sx
            y: sy
            width: sz
            height: sz
            opacity: 0
            z: -500
            Rectangle { 
                anchors.fill: parent
                radius: width/2
                color: "#fff0d4"
                opacity: 0.12 
            }
            SequentialAnimation {
                running: true
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: mote; property: "y"; to: mote.sy - 100; duration: mote.dur; easing.type: Easing.InOutSine }
                    NumberAnimation { target: mote; property: "x"; to: mote.sx + mote.dr; duration: mote.dur; easing.type: Easing.InOutSine }
                    SequentialAnimation { 
                        NumberAnimation { target: mote; property: "opacity"; to: 0.4; duration: mote.dur * 0.4 }
                        NumberAnimation { target: mote; property: "opacity"; to: 0; duration: mote.dur * 0.6 } 
                    }
                }
            }
        }
    }

    // Interface
    Item {
        id: uiContainer
        anchors.fill: parent; z: 10
        readonly property real leftPadding: 160 * s

        // Clock
        Column {
            id: clockArea
            anchors.left: parent.left
            anchors.leftMargin: uiContainer.leftPadding
            anchors.top: parent.top
            anchors.topMargin: 150 * s
            spacing: 2 * s
            Text {
                id: clockText
                text: Qt.formatTime(new Date(), "HH:mm")
                font.family: mainFont.name
                font.pixelSize: 104 * s
                font.weight: Font.DemiBold
                color: root.textPrimary
                opacity: 0.95
                layer.enabled: true
                layer.effect: DropShadow { color: "#aa000000"; radius: 10; samples: 24; verticalOffset: 6 }
                Timer { 
                    interval: 60000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm") 
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.88; duration: 5000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.95; duration: 5000; easing.type: Easing.InOutSine }
                }
            }
            Text {
                id: dateText
                text: Qt.formatDate(new Date(), "dddd / MMMM d").toUpperCase()
                font.family: mainFont.name
                font.pixelSize: 14 * s
                font.letterSpacing: 8 * s
                color: root.textSecondary
                anchors.left: parent.left
                anchors.leftMargin: 6 * s
            }
        }

        // Login
        Item {
            id: loginWrapper
            anchors.left: parent.left
            anchors.leftMargin: uiContainer.leftPadding
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 120 * s
            width: 380 * s
            height: loginContent.implicitHeight

            Column {
                id: loginContent
                anchors.fill: parent
                spacing: 40 * s
                
                Column {
                    spacing: 4 * s; width: parent.width
                    Text { text: "CURRENT OPERATIVE"; font.family: mainFont.name; font.pixelSize: 10 * s; font.letterSpacing: 2 * s; color: root.textSecondary; opacity: 0.55 }
                    Text {
                        id: userNameDisplay
                        text: ((userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName : (typeof userModel !== "undefined" && userModel.lastUser ? userModel.lastUser : "UNAUTHENTICATED")).toUpperCase()
                        font.family: mainFont.name
                        font.pixelSize: 40 * s
                        font.weight: Font.Bold
                        font.letterSpacing: 1 * s
                        color: uMa.containsMouse ? root.accent : root.textPrimary
                        Behavior on color { ColorAnimation { duration: 300 } }
                        MouseArea { 
                            id: uMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (typeof userModel !== "undefined" && userModel.rowCount() > 0) root.userMenuOpen = !root.userMenuOpen }
                        }
                    }
                }

                Item {
                    width: parent.width; height: 50 * s
                    Rectangle { 
                        anchors.fill: parent
                        color: Qt.rgba(1, 1, 1, 0.03)
                        radius: 4 * s
                        border.color: passInput.activeFocus ? Qt.rgba(0.97, 0.77, 0.58, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1 
                    }
                    TextInput {
                        id: passInput
                        anchors.fill: parent
                        anchors.leftMargin: 15 * s
                        anchors.rightMargin: 80 * s
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password; passwordCharacter: "·"
                        font.family: mainFont.name
                        font.pixelSize: 22 * s
                        font.letterSpacing: 10 * s
                        color: root.textPrimary
                        clip: true
                        focus: true
                        cursorVisible: false
                        cursorDelegate: Item { width: 0; height: 0 }
                        onAccepted: root.login()
                        onTextEdited: {
                            root.loginError = false
                            errText.text = ""
                        }
                        property bool wasClicked: false
                        
                        Text { 
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ENTER ACCESS KEY"
                            font.family: mainFont.name
                            font.pixelSize: 12 * s
                            font.letterSpacing: 4 * s
                            color: root.textSecondary
                            opacity: (passInput.text.length === 0 && !passInput.wasClicked) ? 0.35 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 300 } } 
                        }
                        
                        Rectangle {
                            id: cur
                            width: 8 * s
                            height: 8 * s
                            radius: 4 * s
                            color: root.accent
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, passInput.cursorRectangle.x)
                            visible: passInput.focus && (passInput.text.length > 0 || passInput.wasClicked)
                            layer.enabled: true
                            layer.effect: DropShadow { color: root.accent; radius: 8; samples: 16 }
                            SequentialAnimation { 
                                loops: Animation.Infinite
                                running: cur.visible
                                NumberAnimation { target: cur; property: "opacity"; from: 1; to: 0.15; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { target: cur; property: "opacity"; from: 0.15; to: 1; duration: 700; easing.type: Easing.InOutSine } 
                            }
                        }
                    }

                    Text {
                        id: enterBtn
                        anchors.right: parent.right; anchors.rightMargin: 15 * s; anchors.verticalCenter: parent.verticalCenter
                        text: "GO"; font.family: mainFont.name; font.pixelSize: 11 * s; font.letterSpacing: 3 * s; font.weight: Font.Bold
                        color: eMa.containsMouse ? root.accent : root.textPrimary
                        opacity: passInput.text.length > 0 ? 0.8 : 0.0
                        scale: passInput.text.length > 0 ? 1.0 : 0.8
                        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuart } }
                        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                        MouseArea { id: eMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
                    }

                    MouseArea { 
                        anchors.fill: parent
                        enabled: passInput.text.length === 0
                        onClicked: { passInput.forceActiveFocus(); passInput.wasClicked = true } 
                    }
                }
                
                Text {
                    id: errText
                    width: parent.width
                    height: 15 * s
                    verticalAlignment: Text.AlignBottom
                    text: ""
                    color: "#f06060"
                    font.family: mainFont.name
                    font.pixelSize: 12 * s
                    font.letterSpacing: 2 * s
                }
            }

            SequentialAnimation {
                id: errorShake
                property real base: uiContainer.leftPadding
                NumberAnimation { target: loginWrapper; property: "x"; to: errorShake.base + 15 * s; duration: 45 }
                NumberAnimation { target: loginWrapper; property: "x"; to: errorShake.base - 15 * s; duration: 45 }
                NumberAnimation { target: loginWrapper; property: "x"; to: errorShake.base + 10 * s; duration: 45 }
                NumberAnimation { target: loginWrapper; property: "x"; to: errorShake.base - 10 * s; duration: 45 }
                NumberAnimation { target: loginWrapper; property: "x"; to: errorShake.base; duration: 45 }
                onStopped: root.loginError = false
            }

            // User Menu
            Item {
                id: userMenu
                anchors.left: parent.left
                anchors.bottom: loginWrapper.top
                anchors.bottomMargin: 40 * s
                width: 340 * s
                height: menuLayout.implicitHeight

                visible: opacity > 0
                opacity: root.userMenuOpen ? 1 : 0
                scale: root.userMenuOpen ? 1 : 0.98
                transform: Translate { y: root.userMenuOpen ? 0 : 15 * s }
                
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutQuart } }
                Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
                Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }

                Rectangle {
                    anchors.fill: parent
                    color: root.glassBg
                    radius: 4 * s
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    layer.enabled: true
                    layer.effect: DropShadow { color: "#aa000000"; radius: 25; samples: 32; verticalOffset: 12 }
                }

                Column {
                    id: menuLayout
                    width: parent.width
                    topPadding: 20 * s
                    bottomPadding: 15 * s
                    leftPadding: 20 * s
                    rightPadding: 20 * s
                    spacing: 0

                    Item {
                        width: parent.width - 40 * s; height: 25 * s
                        Row {
                            spacing: 10 * s; anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: 3 * s; height: 10 * s; color: root.accent; radius: 1; anchors.verticalCenter: parent.verticalCenter }
                            Text { 
                                text: "OPERATIVE DIRECTORY // 0" + (typeof userModel !== "undefined" ? userModel.rowCount() : "0")
                                font.family: mainFont.name; font.pixelSize: 8 * s; font.letterSpacing: 3 * s; font.weight: Font.DemiBold
                                color: root.accent; opacity: 0.8
                            }
                        }
                    }

                    Rectangle { width: parent.width - 40 * s; height: 1; color: root.accent; opacity: 0.12; anchors.topMargin: 2 * s }

                    Item { width: parent.width; height: 10 * s } 

                    Column {
                        width: parent.width - 40 * s
                        spacing: 6 * s
                        
                        Repeater {
                            model: typeof userModel !== "undefined" ? userModel : null
                            delegate: Item {
                                width: parent.width
                                height: 42 * s
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2 * s
                                    color: root.accent
                                    opacity: (itemMa.containsMouse || index === root.userIndex) ? 0.08 : 0.02
                                    border.color: (itemMa.containsMouse || index === root.userIndex) ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                    Behavior on opacity { NumberAnimation { duration: 250 } }
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 15 * s
                                    spacing: 15 * s
                                    
                                    Item {
                                        width: 10 * s; height: 10 * s; anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: (index === root.userIndex) ? 5 * s : 3 * s
                                            height: width; radius: width/2
                                            color: (index === root.userIndex) ? root.accent : root.textSecondary
                                            opacity: (index === root.userIndex) ? 1.0 : 0.4
                                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                                        }
                                    }

                                    Text {
                                        text: (model.realName || model.name || "UNKNOWN").toUpperCase()
                                        font.family: mainFont.name; font.pixelSize: 14 * s; font.letterSpacing: 2 * s
                                        color: (index === root.userIndex) ? root.accent : (itemMa.containsMouse ? root.textPrimary : root.textSecondary)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: 250 } }
                                    }
                                }

                                MouseArea { 
                                    id: itemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.userIndex = index; root.userMenuOpen = false } 
                                }
                            }
                        }
                    }
                }
            }
        }

        // Actions
        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 140 * s
            anchors.left: parent.left
            anchors.leftMargin: uiContainer.leftPadding
            spacing: 80 * s
            height: 30 * s
            Row {
                spacing: 60 * s
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: [ { label: "SHUTDOWN", act: 1 }, { label: "REBOOT", act: 0 } ]
                    delegate: Text {
                        text: modelData.label
                        font.family: mainFont.name
                        font.pixelSize: 14 * s
                        font.letterSpacing: 2 * s
                        anchors.verticalCenter: parent.verticalCenter
                        color: pMa.containsMouse ? root.accent : root.textSecondary
                        Behavior on color { ColorAnimation { duration: 250 } }
                        MouseArea { 
                            id: pMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof sddm !== "undefined") {
                                    modelData.act === 0 ? sddm.reboot() : sddm.powerOff() 
                                }
                            }
                        }
                    }
                }
            }

            // Session
            Item {
                visible: !root.isQuickshell
                width: sessLayout.implicitWidth
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    id: sessLayout; spacing: 15 * s; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { 
                        width: 6 * s; height: 6 * s; radius: 3 * s; color: root.accent; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -2 * s; opacity: 0.8 
                        SequentialAnimation on opacity { 
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 1500 }
                            NumberAnimation { to: 0.8; duration: 1500 } 
                        }
                    }
                    Text {
                        id: sessText
                        text: (sessionHelper.currentItem && sessionHelper.currentItem.sName ? sessionHelper.currentItem.sName : "SESSION").toUpperCase()
                        font.family: mainFont.name
                        font.pixelSize: 14 * s
                        font.letterSpacing: 2 * s
                        anchors.verticalCenter: parent.verticalCenter
                        color: sMa.containsMouse ? root.accent : root.textSecondary
                        Behavior on color { ColorAnimation { duration: 250 } }
                        transform: Translate { id: sessTrans; x: 0 }
                    }
                }
                MouseArea { 
                    id: sMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (typeof sessionModel !== "undefined" && sessionModel.rowCount() > 0) toggleAnim.start() }
                }
                SequentialAnimation {
                    id: toggleAnim
                    ParallelAnimation { 
                        NumberAnimation { target: sessText; property: "opacity"; to: 0; duration: 150 }
                        NumberAnimation { target: sessTrans; property: "x"; to: 10 * s; duration: 150 } 
                    }
                    ScriptAction { script: { root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount() } }
                    ParallelAnimation { 
                        NumberAnimation { target: sessText; property: "opacity"; to: 1; duration: 200 }
                        NumberAnimation { target: sessTrans; property: "x"; to: 0; duration: 200 } 
                    }
                }
            }
        }
    }

    MouseArea { 
        anchors.fill: parent
        z: -10
        visible: root.userMenuOpen
        onClicked: root.userMenuOpen = false 
    }
}
