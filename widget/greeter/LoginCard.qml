import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: root

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
        if (!enabled || !visible || GreeterSession.working || sessionPickerOpen)
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

    implicitHeight: cardContent.implicitHeight + 56
    implicitWidth: 520

    Component.onCompleted: root.focusInput()
    onEnabledChanged: Qt.callLater(root.focusInput)
    onIsActualErrorChanged: {
        if (isActualError)
            shakeAnimation.restart();
    }
    onVisibleChanged: Qt.callLater(root.focusInput)

    TextInput {
        id: secretField

        Accessible.name: qsTr("Password")
        echoMode: TextInput.Password
        enabled: !GreeterSession.working && !GreeterSession.launching
        height: 1
        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
        opacity: 0
        width: 1

        Keys.onPressed: event => {
            root.inputActivity();
            profileAvatar.pulse();
            if (event.key === Qt.Key_Escape) {
                secretField.clear();
                GreeterSession.cancel();
                event.accepted = true;
            } else if (event.key === Qt.Key_Menu) {
                root.openSessionPicker(profileAvatar);
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                event.accepted = true;
            }
        }
        onAccepted: root.submit()
        onTextEdited: root.inputActivity()
    }
    Timer {
        id: simulatedUnlock

        interval: 1000

        onTriggered: {
            GreeterSession.launching = false;
            root.clearSecret();
        }
    }
    Connections {
        function onInputResetRequested() {
            root.clearSecret();
        }
        function onWorkingChanged() {
            if (!GreeterSession.working)
                Qt.callLater(root.focusInput);
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
    Rectangle {
        id: card

        anchors.fill: parent
        color: "transparent"
        opacity: 0
        scale: 0.96

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
                Layout.preferredHeight: profileAvatar.implicitHeight
                spacing: 24

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onTapped: (eventPoint, button) => {
                        root.inputActivity();
                        if (button === Qt.RightButton)
                            root.openSessionPicker(profileAvatar);
                        else
                            root.focusInput();
                    }
                }
                GreeterAvatar {
                    id: profileAvatar

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: Math.min(implicitHeight, root.width * 0.24)
                    Layout.preferredWidth: Layout.preferredHeight
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
                        font.family: "Inter Display"
                        font.letterSpacing: 0.15
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                        text: root.defaultUser !== "" ? root.defaultUser : userField.text !== "" ? userField.text : qsTr("User")
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        color: GreeterTheme.surfaceVariantText
                        elide: Text.ElideRight
                        font.family: "Inter Display"
                        font.letterSpacing: 0.45
                        font.pixelSize: 19
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

            onClosed: root.focusInput()
        }
    }
}
