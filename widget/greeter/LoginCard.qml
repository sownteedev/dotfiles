import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root

    property bool capsLockActive: false
    required property string defaultUser
    readonly property bool isActualError: {
        var msg = GreeterSession.message.trim().toLowerCase();
        if (msg === "" || msg.indexOf("preview mode") >= 0 || msg.indexOf("opening") >= 0 || msg.indexOf("starting") >= 0 || msg.indexOf("checking") >= 0)
            return false;
        return msg.indexOf("fail") >= 0 || msg.indexOf("error") >= 0 || msg.indexOf("lost") >= 0 || msg.indexOf("denied") >= 0;
    }
    readonly property bool sessionPickerOpen: sessionMenu.visible

    signal inputActivity

    function clearSecret() {
        secretField.clear();
        root.focusInput();
    }
    function focusInput() {
        if (!enabled || !visible)
            return;
        if (userField.text === "")
            userField.forceActiveFocus();
        else
            secretField.forceActiveFocus();
    }
    function openSessionPicker(sourceItem) {
        if (GreeterSession.sessions.length <= 1)
            return;
        sessionMenu.parent = sourceItem;
        sessionMenu.x = Math.round((sourceItem.width - sessionMenu.width) / 2);
        sessionMenu.y = -sessionMenu.height - 6;
        sessionMenu.open();
    }
    function submit() {
        if (GreeterSession.working || secretField.text.length === 0)
            return;
        if (!GreeterSession.greetdAvailable) {
            // In preview mode: simulate smooth login animation without error text
            GreeterSession.launching = true;
            simulatedUnlock.restart();
            return;
        }
        if (GreeterSession.waitingForResponse)
            GreeterSession.respond(secretField.text);
        else
            GreeterSession.start(userField.text, secretField.text);
        secretField.clear();
    }
    function updateCapsLock(event, keyPressed) {
        if (event.key === Qt.Key_CapsLock && keyPressed)
            capsLockActive = !capsLockActive;
    }

    implicitHeight: cardContent.implicitHeight + 56
    implicitWidth: 400

    Component.onCompleted: root.focusInput()
    onIsActualErrorChanged: {
        if (isActualError)
            shakeAnimation.restart();
    }

    Timer {
        id: simulatedUnlock

        interval: 1000

        onTriggered: {
            GreeterSession.launching = false;
            secretField.clear();
        }
    }
    Connections {
        function onInputResetRequested() {
            root.clearSecret();
        }

        target: GreeterSession
    }
    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation {
            duration: 45
            easing.type: Easing.InOutQuad
            from: 0
            property: "x"
            target: cardTranslate
            to: -10
        }
        NumberAnimation {
            duration: 50
            easing.type: Easing.InOutQuad
            from: -10
            property: "x"
            target: cardTranslate
            to: 10
        }
        NumberAnimation {
            duration: 45
            easing.type: Easing.InOutQuad
            from: 10
            property: "x"
            target: cardTranslate
            to: -7
        }
        NumberAnimation {
            duration: 45
            easing.type: Easing.InOutQuad
            from: -7
            property: "x"
            target: cardTranslate
            to: 7
        }
        NumberAnimation {
            duration: 40
            easing.type: Easing.InOutQuad
            from: 7
            property: "x"
            target: cardTranslate
            to: 0
        }
    }
    RectangularShadow {
        anchors.fill: card
        blur: 32
        color: GreeterTheme.withAlpha(GreeterTheme.shadow, GreeterTheme.isDark ? 0.2 : 0.1)
        offset.y: 8
        radius: card.radius
        spread: -2
    }
    Rectangle {
        id: card

        anchors.fill: parent
        border.color: root.isActualError ? GreeterTheme.withAlpha(GreeterTheme.error, 0.6) : GreeterTheme.withAlpha(GreeterTheme.outlineVariant, GreeterTheme.isDark ? 0.22 : 0.35)
        border.width: 1
        color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainer, 0.96)
        opacity: 0
        radius: 28
        scale: 0.96

        gradient: Gradient {
            GradientStop {
                color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHigh, 0.98)
                position: 0
            }
            GradientStop {
                color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainer, 0.98)
                position: 1
            }
        }
        transform: Translate {
            id: cardTranslate
        }

        ParallelAnimation {
            running: true

            OpacityAnimator {
                duration: 260
                easing.type: Easing.OutCubic
                from: 0
                target: card
                to: 1
            }
            ScaleAnimator {
                duration: 300
                easing.type: Easing.OutCubic
                from: 0.96
                target: card
                to: 1
            }
        }
        ColumnLayout {
            id: cardContent

            anchors.fill: parent
            anchors.margins: 28
            spacing: 24

            // Avatar & Identity Header Block
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                spacing: 16

                GreeterAvatar {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 52
                    Layout.preferredWidth: 52
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        color: GreeterTheme.surfaceText
                        elide: Text.ElideRight
                        font.family: "Inter Variable"
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        text: root.defaultUser !== "" ? root.defaultUser : userField.text !== "" ? userField.text : qsTr("User")
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        color: GreeterTheme.surfaceVariantText
                        elide: Text.ElideRight
                        font.family: "Inter Variable"
                        font.letterSpacing: 0.2
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: "@" + GreeterSession.hostName
                        visible: GreeterSession.hostName !== ""
                    }
                }
            }

            // Username input (only shown if no default user configured)
            TextField {
                id: userField

                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 48 : 0
                color: GreeterTheme.surfaceText
                font.family: "Inter Variable"
                font.pixelSize: 14
                leftPadding: 16
                placeholderText: qsTr("User name")
                placeholderTextColor: GreeterTheme.surfaceVariantText
                rightPadding: 16
                text: root.defaultUser
                visible: root.defaultUser === ""

                background: Rectangle {
                    border.color: userField.activeFocus ? GreeterTheme.primary : GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.45)
                    border.width: userField.activeFocus ? 2 : 1
                    color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHighest, 0.55)
                    radius: 14
                }

                onAccepted: secretField.forceActiveFocus()
                onTextEdited: root.inputActivity()
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    id: passwordCapsule

                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    border.color: root.isActualError ? GreeterTheme.error : secretField.activeFocus ? GreeterTheme.withAlpha(GreeterTheme.primary, 0.55) : GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.25)
                    border.width: 1
                    color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerLowest, 0.65)
                    radius: 18

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        // Leading Lock Icon
                        Text {
                            color: GreeterTheme.surfaceVariantText
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            text: "󰌾"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }
                        }

                        // Main Password Field
                        Item {
                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            TextField {
                                id: secretField

                                anchors.fill: parent
                                color: "transparent"
                                echoMode: TextInput.Password
                                enabled: !GreeterSession.working
                                font.family: "Inter Variable"
                                font.pixelSize: 16
                                leftPadding: 4
                                placeholderText: activeFocus ? "" : qsTr("Enter password…")
                                placeholderTextColor: GreeterTheme.withAlpha(GreeterTheme.surfaceVariantText, 0.6)
                                rightPadding: 6
                                selectByMouse: true
                                selectedTextColor: "transparent"
                                selectionColor: "transparent"

                                background: Item {
                                }
                                cursorDelegate: Item {
                                    height: 0
                                    width: 0
                                }

                                Keys.onEscapePressed: {
                                    secretField.clear();
                                    GreeterSession.cancel();
                                }
                                Keys.onPressed: event => {
                                    root.inputActivity();
                                    root.updateCapsLock(event, true);
                                }
                                Keys.onReleased: event => root.updateCapsLock(event, false)
                                onAccepted: root.submit()
                                onTextEdited: root.inputActivity()
                            }
                            GreeterPasswordDots {
                                active: secretField.activeFocus
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                characterCount: secretField.text.length
                                cursorColor: GreeterTheme.primary
                                dotColor: root.isActualError ? GreeterTheme.error : GreeterTheme.surfaceText
                                error: root.isActualError
                            }
                        }

                        // Caps Lock Warning Pill
                        Rectangle {
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: capsText.implicitWidth + 14
                            color: GreeterTheme.withAlpha(GreeterTheme.error, 0.22)
                            radius: 8
                            visible: root.capsLockActive

                            Text {
                                id: capsText

                                anchors.centerIn: parent
                                color: GreeterTheme.error
                                font.family: "Inter Variable"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                text: qsTr("CAPS")
                            }
                        }
                        Item {
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: layoutText.implicitWidth + 4

                            Text {
                                id: layoutText

                                anchors.centerIn: parent
                                color: GreeterTheme.surfaceVariantText
                                font.family: "Inter Variable"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                text: GreeterSession.keyboardLayoutLabel
                            }
                        }
                    }
                }
                Rectangle {
                    id: submitCircle

                    readonly property bool ready: secretField.text.length > 0 && !GreeterSession.working

                    Layout.preferredHeight: 56
                    Layout.preferredWidth: 56
                    color: ready ? (submitMouse.pressed ? Qt.darker(GreeterTheme.primary, 1.15) : submitMouse.containsMouse ? Qt.lighter(GreeterTheme.primary, 1.08) : GreeterTheme.primary) : GreeterTheme.withAlpha(GreeterTheme.surfaceText, 0.08)
                    radius: 18
                    scale: submitMouse.pressed && ready ? 0.96 : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutBack
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: submitCircle.ready ? GreeterTheme.primaryText : GreeterTheme.withAlpha(GreeterTheme.surfaceVariantText, 0.4)
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 22
                        text: GreeterSession.working ? "󰔟" : "󰁔"

                        RotationAnimation on rotation {
                            duration: 800
                            from: 0
                            loops: Animation.Infinite
                            running: GreeterSession.working
                            to: 360
                        }
                    }
                    MouseArea {
                        id: submitMouse

                        anchors.fill: parent
                        cursorShape: submitCircle.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                        hoverEnabled: true

                        onClicked: {
                            if (submitCircle.ready)
                                root.submit();
                        }
                    }
                }
            }

            // Real Error Message Badge
            Rectangle {
                Layout.fillWidth: true
                border.color: GreeterTheme.withAlpha(GreeterTheme.error, 0.45)
                border.width: 1
                color: GreeterTheme.withAlpha(GreeterTheme.error, 0.16)
                implicitHeight: errorContent.implicitHeight + 20
                radius: 12
                visible: root.isActualError

                RowLayout {
                    id: errorContent

                    anchors.left: parent.left
                    anchors.margins: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        color: GreeterTheme.error
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        text: "󰅚"
                    }
                    Text {
                        Layout.fillWidth: true
                        color: GreeterTheme.error
                        font.family: "Inter Variable"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: GreeterSession.message
                        wrapMode: Text.Wrap
                    }
                }
            }

            // MD3 Assist Chip for Session Selection
            Rectangle {
                id: sessionChip

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                border.color: sessionMouse.containsMouse ? GreeterTheme.withAlpha(GreeterTheme.primary, 0.5) : GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.35)
                border.width: 1
                color: sessionMouse.containsMouse ? GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHighest, 0.75) : GreeterTheme.withAlpha(GreeterTheme.surfaceContainerLow, 0.6)
                radius: 19
                visible: GreeterSession.sessions.length > 1

                Behavior on color {
                    ColorAnimation {
                        duration: 130
                    }
                }

                RowLayout {
                    id: sessionRow

                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        color: GreeterTheme.primary
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 15
                        text: "󰍹"
                    }
                    Text {
                        color: GreeterTheme.surfaceVariantText
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 13
                        text: "󰅀"
                        visible: GreeterSession.sessions.length > 1
                    }
                }
                MouseArea {
                    id: sessionMouse

                    anchors.fill: parent
                    cursorShape: GreeterSession.sessions.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    hoverEnabled: true

                    onClicked: root.openSessionPicker(sessionChip)
                }
            }
        }
        Popup {
            id: sessionMenu

            padding: 6
            width: 180

            background: Rectangle {
                border.color: GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.5)
                border.width: 1
                color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHigh, 0.96)
                radius: 14
            }
            contentItem: Column {
                spacing: 2

                Repeater {
                    model: GreeterSession.sessions

                    Rectangle {
                        id: sessionItem

                        required property int index
                        required property var modelData
                        readonly property bool selected: index === GreeterSession.selectedSessionIndex

                        color: selected ? GreeterTheme.withAlpha(GreeterTheme.primary, 0.18) : itemMouse.containsMouse ? GreeterTheme.withAlpha(GreeterTheme.onSurface, 0.08) : "transparent"
                        height: 34
                        radius: 8
                        width: parent.width

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                color: sessionItem.selected ? GreeterTheme.primary : GreeterTheme.surfaceVariantText
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 14
                                text: "󰍹"
                            }
                            Text {
                                Layout.fillWidth: true
                                color: sessionItem.selected ? GreeterTheme.primary : GreeterTheme.surfaceText
                                elide: Text.ElideRight
                                font.family: "Inter Variable"
                                font.pixelSize: 12
                                font.weight: sessionItem.selected ? Font.Bold : Font.Medium
                                text: sessionItem.modelData.name
                            }
                            Text {
                                color: GreeterTheme.primary
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 13
                                text: "󰄬"
                                visible: sessionItem.selected
                            }
                        }
                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                GreeterSession.selectSession(sessionItem.index);
                                sessionMenu.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
