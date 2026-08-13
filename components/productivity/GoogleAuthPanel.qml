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
                        Layout.fillWidth: true
                        Layout.minimumWidth: 96
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 180
                        color: cloudMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container
                        radius: 12

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: Config.md3.on_surface_variant
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            text: "Google Cloud Console"
                        }
                        MouseArea {
                            id: cloudMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: Quickshell.execDetached(["xdg-open", "https://console.cloud.google.com/apis/credentials"])
                        }
                    }
                    Rectangle {
                        Layout.minimumWidth: 68
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 82
                        color: cancelMouse.containsMouse ? Config.md3.surface_container_high : "transparent"
                        radius: 12

                        Text {
                            anchors.centerIn: parent
                            color: Config.md3.on_surface_variant
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

                            onClicked: GoogleService.cancelAuthentication()
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

                        Layout.minimumWidth: 96
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 112
                        color: ready ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.10)
                        opacity: ready ? 1 : 0.65
                        radius: 12

                        Text {
                            anchors.centerIn: parent
                            color: connectButton.ready ? Config.md3.background : Config.md3.outline
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            text: GoogleService.authenticating ? "Waiting…" : "Connect"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: connectButton.ready
                            hoverEnabled: true

                            onClicked: connectButton.trigger()
                        }
                    }
                }
            }
        }
    }
}
