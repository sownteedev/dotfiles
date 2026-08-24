import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../"
import "../../components"

PanelWindow {
    id: root

    property bool cancelPending: false
    property var flow: null
    readonly property bool passwordHasError: !!(flow && (flow.supplementaryIsError || flow.failed))
    property bool submitPending: false

    function cancelAuthentication() {
        if (!flow || flow.isCompleted || cancelPending)
            return;

        cancelPending = true;
        passwordInput.text = "";
        flow.cancelAuthenticationRequest();
    }
    function focusPasswordInput() {
        if (!visible || !flow || !flow.isResponseRequired)
            return;

        passwordInput.forceActiveFocus(Qt.ActiveWindowFocusReason);
        focusRetry.attempts = 0;
        focusRetry.restart();
    }
    function moveToFocusedScreen() {
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;
    }
    function selectNextIdentity() {
        if (!flow || cancelPending || submitPending || !flow.identities || flow.identities.length < 2)
            return;

        var selectedIndex = flow.identities.indexOf(flow.selectedIdentity);
        passwordInput.text = "";
        flow.selectedIdentity = flow.identities[(selectedIndex + 1) % flow.identities.length];
    }
    function submitAuthentication() {
        if (!flow || !flow.isResponseRequired || submitPending || cancelPending)
            return;
        submitPending = true;
        flow.submit(passwordInput.text);
        passwordInput.text = "";
    }

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-polkit"
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    visible: flow !== null

    Component.onCompleted: moveToFocusedScreen()
    onFlowChanged: {
        cancelPending = false;
        submitPending = false;
        failureShake.stop();
        shakeTransform.x = 0;
        passwordInput.text = "";
        if (flow)
            moveToFocusedScreen();
        Qt.callLater(function () {
            cardFlickable.contentY = 0;
            if (root.flow)
                root.focusPasswordInput();
        });
    }
    onVisibleChanged: {
        if (visible)
            Qt.callLater(root.focusPasswordInput);
        else {
            focusRetry.stop();
            cancelPending = false;
            submitPending = false;
            passwordInput.text = "";
        }
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
    ShellShadow {
        active: root.visible
        cornerRadius: card.radius
        opacity: card.opacity
        scale: card.scale
        target: card

        transform: Translate {
            x: shakeTransform.x
        }
    }
    Rectangle {
        id: card

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.13)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container_low, 0.98)
        height: Responsive.fit(content.implicitHeight + (root.height < 620 ? 36 : 56), root.height - 48, 240)
        opacity: 0
        radius: Math.min(root.width < 600 ? 22 : 28, width / 2, height / 2)
        scale: 0.92
        width: Responsive.fit(520, root.width - (root.width < 600 ? 24 : 48), 280)

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
        Flickable {
            id: cardFlickable

            readonly property real contentInset: root.height < 620 || root.width < 600 ? 18 : 28

            anchors.fill: parent
            anchors.margins: contentInset
            boundsBehavior: Flickable.StopAtBounds
            clip: contentHeight > height
            contentHeight: content.implicitHeight
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            ColumnLayout {
                id: content

                spacing: root.height < 620 ? 14 : 18
                width: cardFlickable.width

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredHeight: 52
                        Layout.preferredWidth: 52
                        color: Config.md3.primary_container
                        radius: 17

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 27
                            implicitWidth: 27
                            layer.enabled: true
                            source: Quickshell.iconPath(root.flow && root.flow.iconName ? root.flow.iconName : "dialog-password-symbolic")

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_primary_container
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
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            text: qsTr("Authentication required")
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface_variant
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            text: root.flow && root.flow.selectedIdentity ? qsTr("Authenticate as %1").arg(root.flow.selectedIdentity.displayName) : qsTr("Administrator privileges are required")
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
                    Layout.preferredHeight: 62
                    color: identityMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container
                    radius: 17

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(140)
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        spacing: 10

                        ProfileAvatar {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 40
                            sourcePath: Config.profileImage
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: root.flow && root.flow.selectedIdentity ? root.flow.selectedIdentity.displayName : qsTr("Current user")
                        }
                        IconImage {
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("go-next-symbolic")
                            visible: root.flow && root.flow.identities && root.flow.identities.length > 1

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface_variant
                            }
                        }
                    }
                    MouseArea {
                        id: identityMouse

                        anchors.fill: parent
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.flow && !root.cancelPending && !root.submitPending && root.flow.identities && root.flow.identities.length > 1
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
                        text: root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:$/, "") : qsTr("Password")
                    }
                    Item {
                        id: passwordFieldContainer

                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        Rectangle {
                            id: passwordField

                            anchors.fill: parent
                            border.color: root.passwordHasError ? Config.alpha(Config.md3.error, 0.78) : root.submitPending ? Config.alpha(Config.md3.primary, 0.5) : passwordInput.activeFocus ? Config.alpha(Config.md3.primary, 0.58) : Config.alpha(Config.md3.on_surface, 0.1)
                            border.width: 1
                            color: root.passwordHasError ? Config.alpha(Config.md3.error_container, 0.3) : Config.md3.surface_container
                            radius: 17
                            scale: passwordInput.activeFocus ? 1.003 : 1

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Config.animationDuration(160)
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(180)
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animationDuration(180)
                                    easing.type: Easing.OutCubic
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 12
                                spacing: 11

                                IconImage {
                                    id: passwordIcon

                                    implicitHeight: 20
                                    implicitWidth: 20
                                    layer.enabled: true
                                    source: Quickshell.iconPath(root.passwordHasError ? "dialog-error-symbolic" : "changes-prevent-symbolic")

                                    layer.effect: ColorOverlay {
                                        color: root.passwordHasError ? Config.md3.error : passwordInput.activeFocus || root.submitPending ? Config.md3.primary : Config.md3.on_surface_variant
                                    }
                                }
                                Item {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    clip: true

                                    TextInput {
                                        id: passwordInput

                                        anchors.fill: parent
                                        color: root.flow && root.flow.responseVisible ? Config.md3.on_surface : "transparent"
                                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                                        enabled: root.flow && root.flow.isResponseRequired && !root.submitPending && !root.cancelPending
                                        font.family: Config.fontName
                                        font.pixelSize: 16
                                        passwordCharacter: "●"
                                        selectByMouse: true
                                        selectedTextColor: root.flow && root.flow.responseVisible ? Config.md3.background : "transparent"
                                        selectionColor: root.flow && root.flow.responseVisible ? Config.md3.primary : "transparent"
                                        verticalAlignment: TextInput.AlignVCenter

                                        cursorDelegate: Rectangle {
                                            color: root.passwordHasError ? Config.md3.error : Config.md3.primary
                                            radius: 1
                                            visible: root.flow && root.flow.responseVisible
                                            width: 2

                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                running: passwordInput.activeFocus && Config.animationDuration(480) > 0

                                                NumberAnimation {
                                                    duration: Config.animationDuration(480)
                                                    easing.type: Easing.InOutSine
                                                    to: 0.28
                                                }
                                                NumberAnimation {
                                                    duration: Config.animationDuration(480)
                                                    easing.type: Easing.InOutSine
                                                    to: 1
                                                }
                                            }
                                        }

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
                                    AnimatedPasswordDots {
                                        active: passwordInput.activeFocus
                                        anchors.fill: parent
                                        characterCount: passwordInput.text.length
                                        error: root.passwordHasError
                                        revealed: root.flow && root.flow.responseVisible
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Config.alpha(Config.md3.on_surface, 0.38)
                                        font: passwordInput.font
                                        opacity: passwordInput.text === "" && !passwordInput.activeFocus ? 1 : 0
                                        text: root.flow && root.flow.isResponseRequired ? qsTr("Enter your password") : qsTr("Waiting for authentication…")
                                        visible: opacity > 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Config.animationDuration(130)
                                            }
                                        }
                                    }
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
                            return qsTr("Authentication failed. Please try again.");
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
                        Layout.preferredWidth: card.width < 400 ? 96 : 112
                        color: cancelMouse.pressed ? Config.md3.surface_container_highest : cancelMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container
                        radius: 15

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(140)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            text: root.cancelPending ? qsTr("Canceling…") : qsTr("Cancel")
                        }
                        MouseArea {
                            id: cancelMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.cancelPending
                            hoverEnabled: true

                            onClicked: root.cancelAuthentication()
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 46
                        Layout.preferredWidth: card.width < 400 ? 132 : 154
                        color: authenticateMouse.pressed && !root.submitPending ? Config.alpha(Config.md3.primary, 0.78) : Config.md3.primary
                        opacity: root.submitPending ? 0.9 : root.flow && root.flow.isResponseRequired ? 1 : 0.48
                        radius: 15

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(140)
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animationDuration(140)
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            AnimatedSpinner {
                                color: Config.md3.background
                                height: 18
                                lineWidth: 2.2
                                running: root.submitPending
                                visible: root.submitPending
                                width: 18
                            }
                            IconImage {
                                implicitHeight: 17
                                implicitWidth: 17
                                layer.enabled: true
                                source: Quickshell.iconPath("object-locked-symbolic")
                                visible: !root.submitPending

                                layer.effect: ColorOverlay {
                                    color: Config.md3.background
                                }
                            }
                            Text {
                                color: Config.md3.background
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                text: root.submitPending ? qsTr("Verifying…") : root.flow && root.flow.isResponseRequired ? qsTr("Authenticate") : qsTr("Waiting…")
                            }
                        }
                        MouseArea {
                            id: authenticateMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: root.flow && root.flow.isResponseRequired && !root.submitPending && !root.cancelPending
                            hoverEnabled: enabled

                            onClicked: root.submitAuthentication()
                        }
                    }
                }
            }
        }
    }
    Connections {
        function onAuthenticationFailed() {
            root.submitPending = false;
            passwordInput.text = "";
            failureShake.restart();
            Qt.callLater(root.focusPasswordInput);
        }
        function onInputPromptChanged() {
            passwordInput.text = "";
            if (root.flow && root.flow.isResponseRequired) {
                root.submitPending = false;
                Qt.callLater(root.focusPasswordInput);
            }
        }
        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired) {
                root.submitPending = false;
                Qt.callLater(root.focusPasswordInput);
            }
        }

        enabled: root.flow !== null
        target: root.flow
    }
}
