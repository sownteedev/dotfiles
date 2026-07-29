import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../"

PanelWindow {
    id: root

    property var flow: null

    function cancelAuthentication() {
        if (flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
    }
    function focusPasswordInput() {
        if (!visible || !flow || !flow.isResponseRequired)
            return;

        passwordInput.forceActiveFocus(Qt.ActiveWindowFocusReason);
        focusRetry.attempts = 0;
        focusRetry.restart();
    }
    function selectNextIdentity() {
        if (!flow || !flow.identities || flow.identities.length < 2)
            return;

        var selectedIndex = flow.identities.indexOf(flow.selectedIdentity);
        flow.selectedIdentity = flow.identities[(selectedIndex + 1) % flow.identities.length];
    }
    function submitAuthentication() {
        if (!flow || !flow.isResponseRequired)
            return;
        flow.submit(passwordInput.text);
        passwordInput.text = "";
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-polkit"
    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    visible: flow !== null

    onFlowChanged: {
        passwordInput.text = "";
        if (flow)
            Qt.callLater(root.focusPasswordInput);
    }
    onVisibleChanged: {
        if (visible)
            Qt.callLater(root.focusPasswordInput);
        else
            focusRetry.stop();
    }

    Timer {
        id: focusRetry

        property int attempts: 0

        interval: 55
        repeat: true

        onTriggered: {
            if (!root.visible || !root.flow || !root.flow.isResponseRequired) {
                stop();
                return;
            }

            passwordInput.forceActiveFocus(Qt.ActiveWindowFocusReason);
            attempts++;
            if (passwordInput.activeFocus || attempts >= 8)
                stop();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Config.alpha(Config.md3.background, 0.64)

        MouseArea {
            anchors.fill: parent

            // Authentication must be cancelled explicitly to avoid accidental
            // dismissal by clicking outside the card.
            onClicked: passwordInput.forceActiveFocus()
        }
    }
    Rectangle {
        id: card

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.13)
        border.width: 1
        color: Config.alpha(Config.md3.background, 0.98)
        height: content.implicitHeight + 56
        opacity: 0
        radius: 28
        scale: 0.92
        width: Math.min(520, root.width - 48)

        transform: Translate {
            id: shakeTransform
        }

        MouseArea {
            anchors.fill: parent

            onClicked: passwordInput.forceActiveFocus()
        }
        ParallelAnimation {
            running: true

            NumberAnimation {
                duration: 170
                easing.type: Easing.OutCubic
                from: 0
                property: "opacity"
                target: card
                to: 1
            }
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                from: 0.92
                property: "scale"
                target: card
                to: 1
            }
        }
        SequentialAnimation {
            id: failureShake

            NumberAnimation {
                duration: 45
                property: "x"
                target: shakeTransform
                to: -9
            }
            NumberAnimation {
                duration: 70
                property: "x"
                target: shakeTransform
                to: 8
            }
            NumberAnimation {
                duration: 65
                property: "x"
                target: shakeTransform
                to: -5
            }
            NumberAnimation {
                duration: 55
                property: "x"
                target: shakeTransform
                to: 3
            }
            NumberAnimation {
                duration: 45
                property: "x"
                target: shakeTransform
                to: 0
            }
        }
        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.margins: 28
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    Layout.preferredHeight: 56
                    Layout.preferredWidth: 56
                    color: Config.alpha(Config.md3.primary, 0.17)
                    radius: 18

                    IconImage {
                        anchors.centerIn: parent
                        implicitHeight: 29
                        implicitWidth: 29
                        layer.enabled: true
                        source: Quickshell.iconPath(root.flow && root.flow.iconName ? root.flow.iconName : "dialog-password-symbolic")

                        layer.effect: ColorOverlay {
                            color: Config.md3.primary
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 21
                        font.weight: Font.Bold
                        text: "Authentication required"
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        text: root.flow && root.flow.selectedIdentity ? "Authenticate as " + root.flow.selectedIdentity.displayName : "Administrator privileges are required"
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 15
                font.weight: Font.Medium
                text: root.flow ? root.flow.message : ""
                wrapMode: Text.Wrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                border.color: Config.alpha(Config.md3.primary, 0.55)
                border.width: identityMouse.containsMouse ? 1 : 0
                color: Config.md3.surface_container
                radius: 15

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    spacing: 10

                    IconImage {
                        implicitHeight: 19
                        implicitWidth: 19
                        layer.enabled: true
                        source: Quickshell.iconPath("avatar-default-symbolic")

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface_variant
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        text: root.flow && root.flow.selectedIdentity ? root.flow.selectedIdentity.displayName : "Current user"
                    }
                    Text {
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        text: "›"
                        visible: root.flow && root.flow.identities && root.flow.identities.length > 1
                    }
                }
                MouseArea {
                    id: identityMouse

                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: root.flow && root.flow.identities && root.flow.identities.length > 1
                    hoverEnabled: enabled

                    onClicked: root.selectNextIdentity()
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    text: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:$/, "") : "Password"
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    border.color: passwordInput.activeFocus ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.13)
                    border.width: passwordInput.activeFocus ? 1.5 : 1
                    color: Config.md3.background
                    radius: 16

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 10

                        IconImage {
                            implicitHeight: 19
                            implicitWidth: 19
                            layer.enabled: true
                            source: Quickshell.iconPath("changes-prevent-symbolic")

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface_variant
                            }
                        }
                        Item {
                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            TextInput {
                                id: passwordInput

                                anchors.fill: parent
                                clip: true
                                color: Config.md3.on_surface
                                echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                                enabled: root.flow && root.flow.isResponseRequired
                                font.family: Config.fontName
                                font.pixelSize: 16
                                passwordCharacter: "●"
                                selectByMouse: true
                                selectedTextColor: Config.md3.background
                                selectionColor: Config.md3.primary
                                verticalAlignment: TextInput.AlignVCenter

                                Keys.onEnterPressed: event => {
                                    root.submitAuthentication();
                                    event.accepted = true;
                                }
                                Keys.onEscapePressed: event => {
                                    root.cancelAuthentication();
                                    event.accepted = true;
                                }
                                Keys.onReturnPressed: event => {
                                    root.submitAuthentication();
                                    event.accepted = true;
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                color: Config.alpha(Config.md3.on_surface, 0.34)
                                font: passwordInput.font
                                text: root.flow && root.flow.isResponseRequired ? "Enter your password" : "Waiting for authentication…"
                                visible: passwordInput.text === "" && !passwordInput.activeFocus
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                color: root.flow && root.flow.supplementaryIsError || root.flow && root.flow.failed ? Config.md3.error : Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 13
                font.weight: Font.Medium
                text: {
                    if (!root.flow)
                        return "";
                    if (root.flow.supplementaryMessage)
                        return root.flow.supplementaryMessage;
                    if (root.flow.failed)
                        return "Authentication failed. Please try again.";
                    return "";
                }
                visible: text !== ""
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 12

                Item {
                    Layout.fillWidth: true
                }
                Rectangle {
                    Layout.preferredHeight: 46
                    Layout.preferredWidth: 112
                    color: cancelMouse.pressed ? Config.md3.surface_container_high : cancelMouse.containsMouse ? Config.md3.surface_container : Config.md3.background
                    radius: 15

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        text: "Cancel"
                    }
                    MouseArea {
                        id: cancelMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.cancelAuthentication()
                    }
                }
                Rectangle {
                    Layout.preferredHeight: 46
                    Layout.preferredWidth: 138
                    color: authenticateMouse.pressed ? Config.alpha(Config.md3.primary, 0.78) : Config.md3.primary
                    opacity: root.flow && root.flow.isResponseRequired ? 1 : 0.48
                    radius: 15

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        IconImage {
                            implicitHeight: 17
                            implicitWidth: 17
                            layer.enabled: true
                            source: Quickshell.iconPath("object-locked-symbolic")

                            layer.effect: ColorOverlay {
                                color: Config.md3.background
                            }
                        }
                        Text {
                            color: Config.md3.background
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            text: root.flow && root.flow.isResponseRequired ? "Authenticate" : "Waiting…"
                        }
                    }
                    MouseArea {
                        id: authenticateMouse

                        anchors.fill: parent
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.flow && root.flow.isResponseRequired
                        hoverEnabled: enabled

                        onClicked: root.submitAuthentication()
                    }
                }
            }
        }
    }
    Connections {
        function onAuthenticationFailed() {
            passwordInput.text = "";
            failureShake.restart();
            Qt.callLater(root.focusPasswordInput);
        }
        function onInputPromptChanged() {
            passwordInput.text = "";
            if (root.flow && root.flow.isResponseRequired)
                Qt.callLater(root.focusPasswordInput);
        }
        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired)
                Qt.callLater(root.focusPasswordInput);
        }

        enabled: root.flow !== null
        target: root.flow
    }
}
