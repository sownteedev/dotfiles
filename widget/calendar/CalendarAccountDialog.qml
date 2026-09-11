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
    function providerContainerColor(value) {
        if (value === "microsoft")
            return Config.md3.secondary_container;
        if (value === "icloud")
            return Config.md3.tertiary_container;
        return Config.md3.primary_container;
    }
    function providerDescription(value) {
        if (value === "microsoft")
            return qsTr("Connect through Microsoft identity and choose the calendars you want to display.");
        if (value === "icloud")
            return qsTr("Connect to iCloud Calendar securely with an Apple app-specific password.");
        return qsTr("Connect through Google OAuth and keep all selected calendars in one timeline.");
    }
    function providerLabel(value) {
        if (value === "microsoft")
            return qsTr("Microsoft 365");
        if (value === "icloud")
            return qsTr("iCloud");
        return qsTr("Google");
    }
    function providerOnContainerColor(value) {
        if (value === "microsoft")
            return Config.md3.on_secondary_container;
        if (value === "icloud")
            return Config.md3.on_tertiary_container;
        return Config.md3.on_primary_container;
    }
    function providerSetupAction(value) {
        if (value === "microsoft")
            return qsTr("Open Microsoft Entra");
        if (value === "icloud")
            return qsTr("Open Apple Account");
        return qsTr("Open Google Cloud");
    }
    function providerSetupTitle(value) {
        if (value === "microsoft")
            return qsTr("Microsoft account details");
        if (value === "icloud")
            return qsTr("iCloud CalDAV details");
        return qsTr("Google OAuth details");
    }
    function providerSetupUrl(value) {
        if (value === "microsoft")
            return "https://entra.microsoft.com/";
        if (value === "icloud")
            return "https://account.apple.com/";
        return "https://console.cloud.google.com/auth/clients";
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
    WheelHandler {
        blocking: true
        target: null
    }
    MouseArea {
        anchors.fill: parent
        enabled: !CalendarService.accountActionBusy

        onClicked: root.close()
        onWheel: event => event.accepted = true
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
        border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.42 : 0.24)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.995 : 0.985)
        height: Math.min(root.provider === "icloud" ? 700 : 570, parent.height - 32)
        radius: 26
        scale: root.opened ? 1 : 0.96
        transformOrigin: Item.Center
        width: Math.min(600, parent.width - 32)

        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(190)
                easing.type: Easing.OutCubic
            }
        }

        WheelHandler {
            blocking: true
            target: null
        }
        MouseArea {
            anchors.fill: parent

            onWheel: event => event.accepted = true
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 11

                Rectangle {
                    Layout.preferredHeight: 48
                    Layout.preferredWidth: 48
                    color: Config.md3.primary_container
                    radius: 16

                    IconImage {
                        anchors.centerIn: parent
                        height: 25
                        layer.enabled: true
                        source: Quickshell.iconPath("appointment-new-symbolic")
                        width: 25

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_primary_container
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        text: qsTr("Add calendar account")
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 13
                        text: qsTr("All connected calendars appear in the same timeline")
                    }
                }
                SettingsActionButton {
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 40
                    enabled: !CalendarService.accountActionBusy
                    iconName: "window-close-symbolic"
                    iconOnly: true
                    text: qsTr("Close")

                    onClicked: root.close()
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.72 : 0.5)
                radius: 18

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: ["google", "microsoft", "icloud"]

                        Rectangle {
                            id: providerButton

                            required property string modelData
                            readonly property bool selected: root.provider === modelData

                            Accessible.name: root.providerLabel(modelData)
                            Accessible.role: Accessible.Button
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            activeFocusOnTab: true
                            border.color: selected ? Config.alpha(Config.md3.primary, 0.42) : activeFocus ? Config.alpha(Config.md3.primary, 0.58) : "transparent"
                            border.width: 1
                            color: selected ? Config.md3.primary_container : providerMouse.containsMouse || activeFocus ? Config.alpha(Config.md3.on_surface, 0.075) : "transparent"
                            radius: 14

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
                                spacing: 9

                                CalendarProviderIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 21
                                    provider: providerButton.modelData
                                    tint: providerButton.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                                    width: 21
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: providerButton.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
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
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    text: root.providerSetupTitle(root.provider)
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.providerDescription(root.provider)
                    wrapMode: Text.Wrap
                }
            }
            Flickable {
                Layout.fillHeight: true
                Layout.fillWidth: true
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                contentHeight: accountFormLoader.status === Loader.Ready && accountFormLoader.item ? accountFormLoader.item.implicitHeight : 0
                contentWidth: width
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height

                Loader {
                    id: accountFormLoader

                    asynchronous: false
                    sourceComponent: root.provider === "icloud" ? icloudForm : oauthForm
                    width: parent.width
                }
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.error_container, 0.72)
                implicitHeight: errorContent.implicitHeight + 18
                radius: 14
                visible: root.errorMessage !== ""

                RowLayout {
                    id: errorContent

                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 9

                    IconImage {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: 18
                        layer.enabled: true
                        source: Quickshell.iconPath("dialog-warning-symbolic")

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_error_container
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_error_container
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        text: root.errorMessage
                        wrapMode: Text.Wrap
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.outline_variant, 0.26)
                implicitHeight: 1
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SettingsActionButton {
                    Layout.preferredHeight: 38
                    enabled: !CalendarService.accountActionBusy
                    iconName: "external-link-symbolic"
                    text: root.providerSetupAction(root.provider)

                    onClicked: Qt.openUrlExternally(root.providerSetupUrl(root.provider))
                }
                Item {
                    Layout.fillWidth: true
                }
                SettingsActionButton {
                    Layout.preferredHeight: 44
                    enabled: !CalendarService.accountActionBusy
                    iconName: "window-close-symbolic"
                    text: qsTr("Cancel")

                    onClicked: root.close()
                }
                SettingsActionButton {
                    Layout.preferredHeight: 44
                    enabled: root.readyToSubmit && !CalendarService.accountActionBusy
                    iconName: CalendarService.accountActionBusy ? "content-loading-symbolic" : "link-symbolic"
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

            AccountField {
                Layout.fillWidth: true
                label: root.provider === "microsoft" ? qsTr("Microsoft application ID") : qsTr("Google client ID")
                placeholder: root.provider === "microsoft" ? qsTr("Enter application (client) ID") : qsTr("Enter OAuth client ID")
                text: root.clientId

                onTextChanged: root.clientId = text
            }
            AccountField {
                Layout.fillWidth: true
                echoMode: TextInput.Password
                label: qsTr("Client secret (optional)")
                placeholder: qsTr("Leave empty for a public desktop client")
                text: root.clientSecret
                visible: root.provider === "google"

                onTextChanged: root.clientSecret = text
            }
            AccountField {
                Layout.fillWidth: true
                label: qsTr("Tenant")
                placeholder: qsTr("common, organizations, or your tenant ID")
                text: root.tenant
                visible: root.provider === "microsoft"

                onTextChanged: root.tenant = text
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(root.providerContainerColor(root.provider), Config.lightTheme ? 0.72 : 0.56)
                implicitHeight: oauthNote.implicitHeight + 26
                radius: 16

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
                            color: root.providerOnContainerColor(root.provider)
                        }
                    }
                    Text {
                        id: oauthNote

                        Layout.fillWidth: true
                        color: root.providerOnContainerColor(root.provider)
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

            AccountField {
                Layout.fillWidth: true
                label: qsTr("Apple ID email")
                placeholder: qsTr("name@icloud.com")
                text: root.email

                onTextChanged: root.email = text
            }
            AccountField {
                Layout.fillWidth: true
                echoMode: TextInput.Password
                label: qsTr("App-specific password")
                placeholder: qsTr("Enter the password generated by Apple")
                text: root.icloudPassword

                onTextChanged: root.icloudPassword = text
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 13
                font.weight: Font.DemiBold
                text: qsTr("Optional details")
            }
            AccountField {
                Layout.fillWidth: true
                label: qsTr("CalDAV username")
                placeholder: qsTr("Defaults to your Apple ID email")
                text: root.icloudUsername

                onTextChanged: root.icloudUsername = text
            }
            AccountField {
                Layout.fillWidth: true
                label: qsTr("Account name")
                placeholder: qsTr("Personal iCloud")
                text: root.displayName

                onTextChanged: root.displayName = text
            }
            AccountField {
                Layout.fillWidth: true
                label: qsTr("CalDAV server")
                placeholder: qsTr("https://caldav.icloud.com/")
                text: root.icloudServer

                onTextChanged: root.icloudServer = text
            }
        }
    }

    component AccountField: FormTextField {
        backgroundColor: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.72 : 0.38)
        fieldHeight: 52
        fieldRadius: 14
        focusedBorderColor: Config.alpha(root.providerColor(root.provider), 0.68)
        inputFontPixelSize: 14
        inputFontWeight: Font.Medium
        labelFontPixelSize: 13
        labelFontWeight: Font.DemiBold
        normalBorderColor: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.38 : 0.24)
        placeholderFontPixelSize: 14
        placeholderFontWeight: Font.Medium
    }
}
