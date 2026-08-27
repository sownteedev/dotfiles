import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import ".."

Rectangle {
    id: root

    property bool connected: false
    property bool connecting: false
    property string errorMessage: ""
    property bool expanded: false
    property bool saved: false
    property bool secured: false
    property int signalStrength: 0
    property string ssid: ""

    signal activateRequested
    signal clearErrorRequested
    signal connectRequested(string password)
    signal expansionToggleRequested
    signal forgetRequested
    signal qrRequested
    signal settingsRequested

    function submitPassword() {
        if (passwordInput.text.length === 0 || root.connecting)
            return;
        var password = passwordInput.text;
        passwordInput.text = "";
        root.connectRequested(password);
    }

    border.color: connected ? Config.alpha(Config.md3.primary, 0.30) : expanded ? Config.alpha(Config.md3.primary, 0.20) : Config.alpha(Config.md3.on_surface, 0.06)
    border.width: 1
    clip: true
    color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? (rowPointer.containsMouse && !expanded ? 0.66 : 0.56) : (rowPointer.containsMouse && !expanded ? 0.28 : 0.2))
    height: expanded ? 50 + expandedContent.implicitHeight + 16 : 50
    radius: 12
    width: ListView.view ? ListView.view.width : implicitWidth

    Behavior on border.color {
        ColorAnimation {
            duration: 200
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    onExpandedChanged: {
        if (expanded) {
            Qt.callLater(function () {
                if (!root.expanded || !passwordInput.enabled)
                    return;
                passwordInput.forceActiveFocus();
                passwordInput.cursorPosition = passwordInput.length;
            });
        } else {
            passwordInput.text = "";
            passwordField.showPassword = false;
        }
    }

    MouseArea {
        id: rowPointer

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: {
            if (root.connected)
                return;
            if (root.saved || !root.secured)
                root.activateRequested();
            else
                root.expansionToggleRequested();
        }
    }
    RowLayout {
        id: header

        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: parent.top
        height: 50
        spacing: 10

        WifiSignalIcon {
            color: root.connected ? Config.md3.primary : Config.md3.on_surface_variant
            connected: true
            height: 22
            signalStrength: root.signalStrength
            width: 22
        }
        Text {
            Layout.fillWidth: true
            color: root.connected ? Config.md3.primary : Config.md3.on_surface
            elide: Text.ElideRight
            font.family: Config.fontName
            font.pixelSize: 14
            font.weight: root.connected ? Font.Bold : Font.Medium
            renderType: Text.NativeRendering
            text: root.ssid
        }
        Rectangle {
            id: qrButton

            Accessible.name: qsTr("Show Wi-Fi QR code")
            Accessible.role: Accessible.Button
            Layout.preferredHeight: 26
            Layout.preferredWidth: 26
            activeFocusOnTab: visible
            color: activeFocus ? Config.alpha(Config.md3.primary, 0.16) : qrPointer.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : "transparent"
            radius: 8
            visible: root.connected && root.saved

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Accessible.onPressAction: root.qrRequested()
            Keys.onReturnPressed: event => {
                root.qrRequested();
                event.accepted = true;
            }
            Keys.onSpacePressed: event => {
                root.qrRequested();
                event.accepted = true;
            }

            IconImage {
                anchors.centerIn: parent
                height: 18
                layer.enabled: true
                source: Quickshell.iconPath("qrscanner-symbolic")
                width: 18

                layer.effect: ColorOverlay {
                    color: qrPointer.containsMouse ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.52)
                }
            }
            MouseArea {
                id: qrPointer

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: {
                    qrButton.forceActiveFocus();
                    root.qrRequested();
                }
            }
        }
        Item {
            height: 20
            visible: root.saved
            width: 20

            IconImage {
                anchors.centerIn: parent
                height: 18
                layer.enabled: true
                source: Quickshell.iconPath("user-trash-symbolic")
                width: 18

                layer.effect: ColorOverlay {
                    color: forgetPointer.containsMouse ? Config.md3.error : Config.alpha(Config.md3.on_surface, 0.45)
                }
            }
            MouseArea {
                id: forgetPointer

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: root.forgetRequested()
            }
        }
        Item {
            height: 20
            visible: root.saved || root.secured
            width: 20

            IconImage {
                anchors.centerIn: parent
                height: 18
                layer.enabled: true
                source: Quickshell.iconPath(root.saved ? "emblem-system-symbolic" : "network-wireless-encrypted-symbolic")
                width: 18

                layer.effect: ColorOverlay {
                    color: root.saved && settingsPointer.containsMouse ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.45)
                }
            }
            MouseArea {
                id: settingsPointer

                anchors.fill: parent
                cursorShape: root.saved ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true

                onClicked: {
                    if (root.saved)
                        root.settingsRequested();
                }
            }
        }
    }
    ColumnLayout {
        id: expandedContent

        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: header.bottom
        opacity: root.expanded ? 1 : 0
        spacing: 12
        visible: root.expanded

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Rectangle {
            id: passwordField

            property bool showPassword: false

            Layout.fillWidth: true
            border.color: root.errorMessage !== "" ? Config.alpha(Config.md3.error, 0.60) : passwordInput.activeFocus ? Config.alpha(Config.md3.primary, 0.55) : Config.alpha(Config.md3.on_surface, 0.10)
            border.width: 1
            color: Config.alpha(Config.md3.on_surface, 0.05)
            height: 38
            radius: 8

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }

            TextInput {
                id: passwordInput

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: visibilityButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: passwordField.showPassword ? (root.errorMessage !== "" ? Config.md3.error : Config.md3.on_surface) : "transparent"
                echoMode: passwordField.showPassword ? TextInput.Normal : TextInput.Password
                enabled: !root.connecting
                font.family: Config.fontName
                font.pixelSize: 13
                font.weight: Font.Medium
                passwordCharacter: "•"
                selectedTextColor: passwordField.showPassword ? "white" : "transparent"
                selectionColor: passwordField.showPassword ? Config.md3.primary : "transparent"
                verticalAlignment: TextInput.AlignVCenter

                cursorDelegate: Rectangle {
                    color: root.errorMessage !== "" ? Config.md3.error : Config.md3.primary
                    radius: 1
                    visible: passwordField.showPassword
                    width: 2
                }

                onAccepted: root.submitPassword()
                onTextChanged: {
                    if (root.errorMessage !== "")
                        root.clearErrorRequested();
                }
            }
            AnimatedPasswordDots {
                active: passwordInput.activeFocus
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: visibilityButton.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                characterCount: passwordInput.text.length
                error: root.errorMessage !== ""
                revealed: passwordField.showPassword
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: visibilityButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                color: Config.alpha(Config.md3.on_surface, 0.28)
                font.family: Config.fontName
                font.pixelSize: 13
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                text: qsTr("Enter WiFi password")
                visible: passwordInput.text === "" && !passwordInput.activeFocus
            }
            Item {
                id: visibilityButton

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: 24

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath(passwordField.showPassword ? "view-conceal-symbolic" : "view-visible-symbolic")
                    width: 16

                    layer.effect: ColorOverlay {
                        color: visibilityPointer.containsMouse ? Config.md3.on_surface : Config.md3.outline
                    }
                }
                MouseArea {
                    id: visibilityPointer

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: passwordField.showPassword = !passwordField.showPassword
                }
            }
        }
        Text {
            Layout.fillWidth: true
            color: Config.md3.error
            font.family: Config.fontName
            font.pixelSize: 11
            leftPadding: 2
            renderType: Text.NativeRendering
            text: root.errorMessage
            visible: text !== ""
        }
        RowLayout {
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                border.color: Config.alpha("#ffffff", 0.10)
                border.width: 1
                color: root.connecting ? Config.alpha(Config.md3.primary, 0.65) : connectPointer.containsMouse ? Qt.lighter(Config.md3.primary, 1.10) : Config.md3.primary
                height: 30
                radius: 7
                width: 86

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 14
                    layer.enabled: true
                    source: Quickshell.iconPath("process-working-symbolic")
                    visible: root.connecting
                    width: 14

                    layer.effect: ColorOverlay {
                        color: "white"
                    }
                    RotationAnimation on rotation {
                        duration: 900
                        from: 0
                        loops: Animation.Infinite
                        running: root.connecting
                        to: 360
                    }
                }
                Text {
                    anchors.centerIn: parent
                    color: Config.md3.background
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                    text: "Connect"
                    visible: !root.connecting
                }
                MouseArea {
                    id: connectPointer

                    anchors.fill: parent
                    cursorShape: root.connecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.submitPassword()
                }
            }
        }
    }
}
