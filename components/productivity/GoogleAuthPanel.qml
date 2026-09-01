import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../service"
import ".."

Item {
    id: root

    enabled: GoogleService.authPanelVisible
    opacity: GoogleService.authPanelVisible ? 1 : 0
    visible: GoogleService.authPanelVisible || opacity > 0
    z: 100

    Behavior on opacity {
        NumberAnimation {
            duration: 180
        }
    }

    onVisibleChanged: {
        if (!visible)
            clientSecret.text = "";
    }

    Rectangle {
        anchors.fill: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.08)
        border.width: 1
        color: Config.md3.surface
        radius: 20

        Flickable {
            anchors.fill: parent
            anchors.margins: 22
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: Math.max(height, authContent.implicitHeight)
            contentWidth: width

            ColumnLayout {
                id: authContent

                spacing: 18
                width: parent.width

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredHeight: 46
                        Layout.preferredWidth: 46
                        color: Config.alpha(Config.md3.primary, 0.15)
                        radius: 14

                        IconImage {
                            anchors.centerIn: parent
                            height: 25
                            layer.enabled: true
                            source: Quickshell.iconPath("internet-services-symbolic")
                            width: 25

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
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            text: "Connect Google"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 15
                            text: "Authorize Calendar and Tasks"
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    text: "Create an OAuth Desktop client in Google Cloud, enable the Calendar and Tasks APIs, then enter its credentials below. Authentication opens in your browser and returns through localhost."
                    wrapMode: Text.Wrap
                }
                FormTextField {
                    id: clientId

                    Layout.fillWidth: true
                    enabled: !GoogleService.authenticating
                    inputFontPixelSize: 14
                    inputFontWeight: Font.Medium
                    label: "Client ID"
                    labelFontPixelSize: 16
                    labelFontWeight: Font.DemiBold
                    placeholder: "…apps.googleusercontent.com"
                    placeholderFontPixelSize: 14
                    placeholderFontWeight: Font.Medium
                    text: GoogleService.authClientIdDraft

                    onTextChanged: GoogleService.authClientIdDraft = text
                }
                FormTextField {
                    id: clientSecret

                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    enabled: !GoogleService.authenticating
                    inputFontPixelSize: 14
                    inputFontWeight: Font.Medium
                    label: "Client Secret"
                    labelFontPixelSize: 16
                    labelFontWeight: Font.DemiBold
                    placeholder: "Enter client secret"
                    placeholderFontPixelSize: 14
                    placeholderFontWeight: Font.Medium

                    onAccepted: connectButton.trigger()
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.primary
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: GoogleService.authStatus
                    visible: GoogleService.authStatus !== ""
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    text: GoogleService.authError
                    visible: GoogleService.authError !== ""
                    wrapMode: Text.Wrap
                }
                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 8
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        id: cloudButton

                        Accessible.name: qsTr("Open Google Cloud Console")
                        Accessible.role: Accessible.Button
                        Layout.fillWidth: true
                        Layout.minimumWidth: 150
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 210
                        activeFocusOnTab: true
                        border.color: activeFocus ? Config.md3.primary : Config.alpha(Config.md3.outline_variant, 0.46)
                        border.width: 1
                        color: cloudMouse.pressed ? Config.alpha(Config.md3.primary, 0.16) : cloudMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container
                        radius: 14

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animationDuration(130)
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(130)
                            }
                        }

                        Accessible.onPressAction: cloudMouse.clicked(null)
                        Keys.onReturnPressed: event => {
                            cloudMouse.clicked(null);
                            event.accepted = true;
                        }
                        Keys.onSpacePressed: event => {
                            cloudMouse.clicked(null);
                            event.accepted = true;
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 9

                            Rectangle {
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: 30
                                color: Config.alpha(Config.md3.primary, 0.14)
                                radius: 10

                                IconImage {
                                    anchors.centerIn: parent
                                    height: 19
                                    layer.enabled: true
                                    source: Quickshell.iconPath("goa-account-google-symbolic", "internet-services-symbolic")
                                    width: 19

                                    layer.effect: ColorOverlay {
                                        color: Config.md3.primary
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                text: qsTr("Google Cloud Console")
                            }
                            IconImage {
                                Layout.preferredHeight: 16
                                Layout.preferredWidth: 16
                                layer.enabled: true
                                source: Quickshell.iconPath("external-link-symbolic")

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_surface_variant
                                }
                            }
                        }
                        MouseArea {
                            id: cloudMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                cloudButton.forceActiveFocus();
                                Quickshell.execDetached(["xdg-open", "https://console.cloud.google.com/apis/credentials"]);
                            }
                        }
                    }
                    Rectangle {
                        id: cancelButton

                        Accessible.name: qsTr("Cancel")
                        Accessible.role: Accessible.Button
                        Layout.minimumWidth: 68
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 82
                        activeFocusOnTab: true
                        border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.72) : "transparent"
                        border.width: 1
                        color: cancelMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.12) : cancelMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent"
                        radius: 14

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animationDuration(130)
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(130)
                            }
                        }

                        Accessible.onPressAction: cancelMouse.clicked(null)
                        Keys.onReturnPressed: event => {
                            cancelMouse.clicked(null);
                            event.accepted = true;
                        }
                        Keys.onSpacePressed: event => {
                            cancelMouse.clicked(null);
                            event.accepted = true;
                        }

                        Text {
                            anchors.centerIn: parent
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            text: qsTr("Cancel")
                        }
                        MouseArea {
                            id: cancelMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                cancelButton.forceActiveFocus();
                                GoogleService.cancelAuthentication();
                            }
                        }
                    }
                    Rectangle {
                        id: connectButton

                        property bool ready: clientId.text.trim() !== "" && clientSecret.text.trim() !== "" && !GoogleService.authenticating

                        function trigger() {
                            if (!ready)
                                return;
                            var secret = clientSecret.text;
                            GoogleService.startAuthentication(clientId.text, secret);
                            clientSecret.text = "";
                        }

                        Accessible.name: GoogleService.authenticating ? qsTr("Waiting for Google authentication") : qsTr("Connect")
                        Accessible.role: Accessible.Button
                        Layout.minimumWidth: 96
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 112
                        activeFocusOnTab: ready
                        border.color: activeFocus ? Config.alpha(Config.md3.on_primary, 0.78) : "transparent"
                        border.width: 1
                        color: ready ? (connectMouse.pressed ? Qt.darker(Config.md3.primary, 1.12) : connectMouse.containsMouse ? Qt.lighter(Config.md3.primary, 1.08) : Config.md3.primary) : Config.alpha(Config.md3.on_surface, 0.10)
                        radius: 14

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animationDuration(130)
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(130)
                            }
                        }

                        Accessible.onPressAction: trigger()
                        Keys.onReturnPressed: event => {
                            trigger();
                            event.accepted = true;
                        }
                        Keys.onSpacePressed: event => {
                            trigger();
                            event.accepted = true;
                        }

                        Text {
                            anchors.centerIn: parent
                            color: connectButton.ready ? Config.md3.on_primary : Config.md3.outline
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            text: GoogleService.authenticating ? qsTr("Waiting…") : qsTr("Connect")
                        }
                        MouseArea {
                            id: connectMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: connectButton.ready
                            hoverEnabled: true

                            onClicked: {
                                connectButton.forceActiveFocus();
                                connectButton.trigger();
                            }
                        }
                    }
                }
            }
        }
    }
}
