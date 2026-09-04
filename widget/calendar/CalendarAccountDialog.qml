import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property string clientId: ""
    property string clientSecret: ""
    property string displayName: ""
    property string email: ""
    property string errorMessage: ""
    property string icloudPassword: ""
    property string icloudServer: ""
    property string icloudUsername: ""
    property bool opened: false
    property string provider: "google"
    readonly property bool readyToSubmit: {
        if (provider === "icloud")
            return email.trim() !== "" && icloudPassword !== "";
        return clientId.trim() !== "";
    }
    property string tenant: "common"

    signal closed

    function close() {
        if (CalendarService.accountActionBusy)
            return;
        opened = false;
        errorMessage = "";
        closed();
    }
    function finishSubmission(success, message) {
        clientSecret = "";
        icloudPassword = "";
        if (success) {
            opened = false;
            closed();
        } else {
            errorMessage = String(message || qsTr("Could not connect this account."));
        }
    }
    function open() {
        resetForm();
        opened = true;
    }
    function providerColor(value) {
        if (value === "microsoft")
            return Config.md3.secondary;
        if (value === "icloud")
            return Config.md3.tertiary;
        return Config.md3.primary;
    }
    function providerLabel(value) {
        if (value === "microsoft")
            return qsTr("Microsoft 365");
        if (value === "icloud")
            return qsTr("iCloud");
        return qsTr("Google");
    }
    function resetForm() {
        provider = "google";
        clientId = "";
        clientSecret = "";
        tenant = "common";
        email = "";
        icloudUsername = "";
        icloudPassword = "";
        displayName = "";
        icloudServer = "";
        errorMessage = "";
    }
    function submit() {
        if (!readyToSubmit || CalendarService.accountActionBusy)
            return;
        errorMessage = "";
        if (provider === "microsoft") {
            CalendarService.addMicrosoft(clientId, tenant, (success, message) => root.finishSubmission(success, message));
        } else if (provider === "icloud") {
            CalendarService.addIcloud(email, icloudUsername, icloudPassword, icloudServer, displayName, (success, message) => root.finishSubmission(success, message));
        } else {
            CalendarService.addGoogle(clientId, clientSecret, (success, message) => root.finishSubmission(success, message));
        }
    }

    enabled: opened
    opacity: opened ? 1 : 0
    visible: opened || opacity > 0
    z: 90

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animationDuration(160)
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Config.alpha(Config.md3.scrim, Config.lightTheme ? 0.25 : 0.44)
    }
    MouseArea {
        anchors.fill: parent
        enabled: !CalendarService.accountActionBusy

        onClicked: root.close()
    }
    ShellShadow {
        active: root.opened
        componentShadow: true
        cornerRadius: dialogCard.radius
        target: dialogCard
    }
    Rectangle {
        id: dialogCard

        anchors.centerIn: parent
        color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.985 : 0.97)
        height: Math.min(680, parent.height - 40)
        radius: 26
        scale: root.opened ? 1 : 0.96
        transformOrigin: Item.Center
        width: Math.min(540, parent.width - 40)

        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(190)
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 11

                Rectangle {
                    Layout.preferredHeight: 44
                    Layout.preferredWidth: 44
                    color: Config.alpha(root.providerColor(root.provider), 0.15)
                    radius: 15

                    CalendarProviderIcon {
                        anchors.centerIn: parent
                        height: 24
                        provider: root.provider
                        tint: root.providerColor(root.provider)
                        width: 24
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        text: qsTr("Add calendar account")
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 12
                        text: qsTr("All connected calendars appear in the same timeline")
                    }
                }
                SettingsActionButton {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: 38
                    enabled: !CalendarService.accountActionBusy
                    iconName: "window-close-symbolic"
                    iconOnly: true
                    text: qsTr("Close")

                    onClicked: root.close()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: ["google", "microsoft", "icloud"]

                    Rectangle {
                        id: providerButton

                        readonly property color accentColor: root.providerColor(modelData)
                        required property string modelData
                        readonly property bool selected: root.provider === modelData

                        Accessible.name: root.providerLabel(modelData)
                        Accessible.role: Accessible.Button
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        activeFocusOnTab: true
                        border.color: selected ? Config.alpha(accentColor, 0.46) : "transparent"
                        border.width: 1
                        color: selected ? Config.alpha(accentColor, 0.14) : providerMouse.containsMouse || activeFocus ? Config.alpha(Config.md3.on_surface, 0.06) : Config.alpha(Config.md3.on_surface, 0.035)
                        radius: 15

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(120)
                            }
                        }

                        Keys.onReturnPressed: event => {
                            root.provider = modelData;
                            event.accepted = true;
                        }
                        Keys.onSpacePressed: event => {
                            root.provider = modelData;
                            event.accepted = true;
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7

                            CalendarProviderIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 19
                                provider: providerButton.modelData
                                tint: providerButton.selected ? providerButton.accentColor : Config.md3.on_surface_variant
                                width: 19
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                color: providerButton.selected ? providerButton.accentColor : Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                text: root.providerLabel(providerButton.modelData)
                            }
                        }
                        MouseArea {
                            id: providerMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                providerButton.forceActiveFocus();
                                root.provider = providerButton.modelData;
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.07)
                implicitHeight: 1
            }
            Flickable {
                Layout.fillHeight: true
                Layout.fillWidth: true
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                contentHeight: accountFormLoader.status === Loader.Ready && accountFormLoader.item ? accountFormLoader.item.implicitHeight : 0
                contentWidth: width

                Loader {
                    id: accountFormLoader

                    asynchronous: false
                    sourceComponent: root.provider === "icloud" ? icloudForm : oauthForm
                    width: parent.width
                }
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.error
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.Medium
                text: root.errorMessage
                visible: text !== ""
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.provider === "icloud" ? qsTr("Use an Apple app-specific password.") : qsTr("Your browser opens to complete OAuth securely.")
                    wrapMode: Text.Wrap
                }
                SettingsActionButton {
                    enabled: !CalendarService.accountActionBusy
                    text: qsTr("Cancel")

                    onClicked: root.close()
                }
                SettingsActionButton {
                    enabled: root.readyToSubmit && !CalendarService.accountActionBusy
                    iconName: CalendarService.accountActionBusy ? "content-loading-symbolic" : "network-connect"
                    primary: true
                    text: CalendarService.accountActionBusy ? qsTr("Connecting…") : qsTr("Connect")

                    onClicked: root.submit()
                }
            }
        }
    }
    Component {
        id: oauthForm

        ColumnLayout {
            spacing: 12

            FormTextField {
                Layout.fillWidth: true
                label: root.provider === "microsoft" ? qsTr("Microsoft application ID") : qsTr("Google client ID")
                labelFontPixelSize: 13
                placeholder: root.provider === "microsoft" ? qsTr("Enter application (client) ID") : qsTr("Enter OAuth client ID")
                text: root.clientId

                onTextChanged: root.clientId = text
            }
            FormTextField {
                Layout.fillWidth: true
                echoMode: TextInput.Password
                label: qsTr("Client secret (optional)")
                labelFontPixelSize: 13
                placeholder: qsTr("Leave empty for a public desktop client")
                text: root.clientSecret
                visible: root.provider === "google"

                onTextChanged: root.clientSecret = text
            }
            FormTextField {
                Layout.fillWidth: true
                label: qsTr("Tenant")
                labelFontPixelSize: 13
                placeholder: qsTr("common, organizations, or your tenant ID")
                text: root.tenant
                visible: root.provider === "microsoft"

                onTextChanged: root.tenant = text
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(root.providerColor(root.provider), 0.09)
                implicitHeight: oauthNote.implicitHeight + 24
                radius: 15

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    IconImage {
                        Layout.preferredHeight: 20
                        Layout.preferredWidth: 20
                        layer.enabled: true
                        source: Quickshell.iconPath("dialog-information-symbolic")

                        layer.effect: ColorOverlay {
                            color: root.providerColor(root.provider)
                        }
                    }
                    Text {
                        id: oauthNote

                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 12
                        text: root.provider === "microsoft" ? qsTr("The app requests calendar read and write access for the selected Microsoft account.") : qsTr("The app requests calendar event access and read-only calendar-list access.")
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
    Component {
        id: icloudForm

        ColumnLayout {
            spacing: 12

            FormTextField {
                Layout.fillWidth: true
                label: qsTr("Apple ID email")
                labelFontPixelSize: 13
                placeholder: qsTr("name@icloud.com")
                text: root.email

                onTextChanged: root.email = text
            }
            FormTextField {
                Layout.fillWidth: true
                label: qsTr("CalDAV username (optional)")
                labelFontPixelSize: 13
                placeholder: qsTr("Defaults to your Apple ID email")
                text: root.icloudUsername

                onTextChanged: root.icloudUsername = text
            }
            FormTextField {
                Layout.fillWidth: true
                echoMode: TextInput.Password
                label: qsTr("App-specific password")
                labelFontPixelSize: 13
                placeholder: qsTr("Enter the password generated by Apple")
                text: root.icloudPassword

                onTextChanged: root.icloudPassword = text
            }
            FormTextField {
                Layout.fillWidth: true
                label: qsTr("Account name (optional)")
                labelFontPixelSize: 13
                placeholder: qsTr("Personal iCloud")
                text: root.displayName

                onTextChanged: root.displayName = text
            }
            FormTextField {
                Layout.fillWidth: true
                label: qsTr("CalDAV server (optional)")
                labelFontPixelSize: 13
                placeholder: qsTr("https://caldav.icloud.com/")
                text: root.icloudServer

                onTextChanged: root.icloudServer = text
            }
        }
    }
}
