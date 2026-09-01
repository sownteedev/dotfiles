import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root

    property bool capsLockActive: false
    required property string defaultUser

    function clearSecret() {
        secretField.clear();
        secretField.forceActiveFocus();
    }
    function submit() {
        if (GreeterSession.working || secretField.text.length === 0)
            return;
        if (GreeterSession.waitingForResponse)
            GreeterSession.respond(secretField.text);
        else
            GreeterSession.start(userField.text, secretField.text);
        secretField.clear();
    }
    function updateCapsLock(event, keyPressed) {
        if (event.key === Qt.Key_CapsLock) {
            if (keyPressed)
                capsLockActive = !capsLockActive;
            return;
        }
        capsLockActive = (event.modifiers & Qt.CapsLockModifier) !== 0;
    }

    implicitHeight: root.defaultUser === "" ? 460 : 392
    implicitWidth: 448

    Component.onCompleted: {
        if (root.defaultUser === "")
            userField.forceActiveFocus();
        else
            secretField.forceActiveFocus();
    }

    Connections {
        function onInputResetRequested() {
            root.clearSecret();
        }

        target: GreeterSession
    }
    RectangularShadow {
        anchors.fill: card
        blur: 38
        color: GreeterTheme.withAlpha(GreeterTheme.shadow, GreeterTheme.isDark ? 0.46 : 0.25)
        offset.y: 16
        radius: card.radius
        spread: -6
    }
    Rectangle {
        id: card

        anchors.fill: parent
        border.color: GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.44)
        border.width: 1
        color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainer, GreeterTheme.isDark ? 0.95 : 0.98)
        opacity: 0
        radius: 34
        scale: 0.96

        ParallelAnimation {
            running: true

            OpacityAnimator {
                duration: 240
                easing.type: Easing.OutCubic
                from: 0
                target: card
                to: 1
            }
            ScaleAnimator {
                duration: 280
                easing.type: Easing.OutCubic
                from: 0.96
                target: card
                to: 1
            }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 18

                GreeterAvatar {
                    Layout.preferredHeight: 88
                    Layout.preferredWidth: 88
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        color: GreeterTheme.surfaceVariantText
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: qsTr("Welcome back")
                    }
                    Text {
                        Layout.fillWidth: true
                        color: GreeterTheme.surfaceText
                        elide: Text.ElideRight
                        font.family: "Inter"
                        font.pixelSize: 25
                        font.weight: Font.DemiBold
                        text: userField.text || qsTr("Sign in")
                    }
                }
            }
            TextField {
                id: userField

                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 54 : 0
                color: GreeterTheme.surfaceText
                font.family: "Inter"
                font.pixelSize: 16
                leftPadding: 18
                placeholderText: qsTr("User name")
                placeholderTextColor: GreeterTheme.surfaceVariantText
                rightPadding: 18
                text: root.defaultUser
                visible: root.defaultUser === ""

                background: Rectangle {
                    border.color: userField.activeFocus ? GreeterTheme.primary : GreeterTheme.withAlpha(GreeterTheme.outline, 0.72)
                    border.width: userField.activeFocus ? 2 : 1
                    color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHighest, 0.7)
                    radius: 17

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }

                onAccepted: secretField.forceActiveFocus()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        Layout.fillWidth: true
                        color: GreeterTheme.surfaceVariantText
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: GreeterSession.prompt || qsTr("Password")
                    }
                    Rectangle {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: layoutText.implicitWidth + 16
                        color: GreeterTheme.withAlpha(GreeterTheme.primary, 0.14)
                        radius: 8

                        Text {
                            id: layoutText

                            anchors.centerIn: parent
                            color: GreeterTheme.primary
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            text: GreeterSession.keyboardLayoutLabel
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: capsText.implicitWidth + 16
                        color: GreeterTheme.withAlpha(GreeterTheme.error, 0.16)
                        radius: 8
                        visible: root.capsLockActive

                        Text {
                            id: capsText

                            anchors.centerIn: parent
                            color: GreeterTheme.error
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            text: qsTr("CAPS")
                        }
                    }
                }
                TextField {
                    id: secretField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    color: "transparent"
                    echoMode: TextInput.Password
                    enabled: !GreeterSession.working
                    font.family: "Inter"
                    font.pixelSize: 17
                    leftPadding: 50
                    placeholderText: activeFocus ? "" : qsTr("Enter your password")
                    placeholderTextColor: GreeterTheme.withAlpha(GreeterTheme.surfaceVariantText, 0.72)
                    rightPadding: 18
                    selectByMouse: true
                    selectedTextColor: "transparent"
                    selectionColor: "transparent"

                    background: Rectangle {
                        border.color: secretField.activeFocus ? GreeterTheme.primary : GreeterTheme.withAlpha(GreeterTheme.outline, 0.72)
                        border.width: secretField.activeFocus ? 2 : 1
                        color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHighest, 0.7)
                        radius: 17

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 140
                            }
                        }
                    }
                    cursorDelegate: Item {
                        height: 0
                        width: 0
                    }

                    Keys.onPressed: event => root.updateCapsLock(event, true)
                    Keys.onReleased: event => root.updateCapsLock(event, false)
                    onAccepted: root.submit()

                    GreeterPasswordDots {
                        active: secretField.activeFocus
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: secretField.leftPadding
                        anchors.right: parent.right
                        anchors.rightMargin: secretField.rightPadding
                        anchors.top: parent.top
                        characterCount: secretField.text.length
                        cursorColor: GreeterTheme.primary
                        dotColor: GreeterTheme.surfaceText
                        error: GreeterSession.message.toLowerCase().indexOf("fail") >= 0
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: secretField.activeFocus ? GreeterTheme.primary : GreeterTheme.surfaceVariantText
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 18
                        text: "󰌾"
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                color: GreeterSession.message.toLowerCase().indexOf("fail") >= 0 ? GreeterTheme.error : GreeterTheme.surfaceVariantText
                font.family: "Inter"
                font.pixelSize: 13
                text: GreeterSession.message
                visible: text !== ""
                wrapMode: Text.Wrap
            }
            Button {
                id: submitButton

                Accessible.name: qsTr("Sign in")
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                enabled: !GreeterSession.working && secretField.text.length > 0

                background: Rectangle {
                    color: submitButton.down ? GreeterTheme.withAlpha(GreeterTheme.primary, 0.78) : submitButton.hovered ? GreeterTheme.withAlpha(GreeterTheme.primary, 0.9) : GreeterTheme.primary
                    opacity: submitButton.enabled ? 1 : 0.4
                    radius: 17

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                }
                contentItem: RowLayout {
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        color: GreeterTheme.primaryText
                        font.family: "Inter"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        text: GreeterSession.working ? qsTr("Signing in…") : qsTr("Sign in")
                    }
                    Text {
                        color: GreeterTheme.primaryText
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 18
                        text: GreeterSession.working ? "󰔟" : "󰁔"
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }

                onClicked: root.submit()
            }
            ComboBox {
                id: sessionPicker

                Accessible.name: qsTr("Desktop session")
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                currentIndex: GreeterSession.selectedSessionIndex
                enabled: !GreeterSession.working && count > 1
                model: GreeterSession.sessions
                opacity: GreeterSession.working ? 0.55 : 1
                textRole: "name"

                background: Rectangle {
                    border.color: sessionPicker.activeFocus ? GreeterTheme.primary : GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.5)
                    border.width: sessionPicker.activeFocus ? 2 : 1
                    color: sessionPicker.pressed ? GreeterTheme.surfaceContainerHighest : sessionPicker.hovered ? GreeterTheme.surfaceContainerHigh : GreeterTheme.surfaceContainerLow
                    radius: 15

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                }
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: sessionPicker.count > 1 ? 38 : 15
                    spacing: 10

                    Text {
                        color: GreeterTheme.primary
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 17
                        text: "󰍹"
                    }
                    Text {
                        Layout.fillWidth: true
                        color: GreeterTheme.surfaceText
                        elide: Text.ElideRight
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        text: sessionPicker.displayText
                    }
                }
                delegate: ItemDelegate {
                    id: sessionDelegate

                    required property int index
                    required property var modelData

                    height: 44
                    highlighted: sessionPicker.highlightedIndex === index
                    width: ListView.view ? ListView.view.width : sessionPicker.width

                    background: Rectangle {
                        color: sessionDelegate.highlighted ? GreeterTheme.withAlpha(GreeterTheme.primary, 0.16) : "transparent"
                        radius: 11
                    }
                    contentItem: Text {
                        color: GreeterTheme.surfaceText
                        elide: Text.ElideRight
                        font.family: "Inter"
                        font.pixelSize: 13
                        text: sessionDelegate.modelData.name
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                indicator: Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: GreeterTheme.surfaceVariantText
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 14
                    text: "󰅀"
                    visible: sessionPicker.count > 1
                }
                popup: Popup {
                    height: Math.min(sessionPicker.count * 44, 220) + topPadding + bottomPadding
                    padding: 6
                    width: sessionPicker.width
                    y: -height - 8
                    z: 100

                    background: Rectangle {
                        border.color: GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.54)
                        border.width: 1
                        color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHigh, 0.98)
                        radius: 16
                    }
                    contentItem: ListView {
                        clip: true
                        currentIndex: sessionPicker.highlightedIndex
                        model: sessionPicker.popup.visible ? sessionPicker.delegateModel : null

                        ScrollIndicator.vertical: ScrollIndicator {
                        }
                    }
                }

                onActivated: index => GreeterSession.selectSession(index)
            }
        }
    }
}
