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
    function providerIconSource(value) {
        if (value === "microsoft")
            return "file://" + Config.sownteeshellDir + "/assets/icons/calendar-microsoft.svg";
        if (value === "icloud")
            return "file://" + Config.sownteeshellDir + "/assets/icons/calendar-icloud.svg";
        return Quickshell.iconPath("goa-account-google-symbolic", "x-office-calendar-symbolic");
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
        Md3NumberAnimation {
            role: opened ? "enter" : "exit"
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
        height: Math.min(root.provider === "icloud" ? 704 : 590, parent.height - 32)
        radius: Md3.shape.extraLarge
        scale: root.opened ? 1 : 0.96
        transformOrigin: Item.Center
        width: Math.min(600, parent.width - 32)

        Behavior on height {
            enabled: root.opened

            Md3NumberAnimation {
                role: "spatial"
            }
        }
        Behavior on scale {
            Md3NumberAnimation {
                role: opened ? "spatial" : "exit"
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
            anchors.margins: Md3.spacing.md
            spacing: Md3.spacing.md

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                spacing: 14

                Rectangle {
                    Layout.preferredHeight: 46
                    Layout.preferredWidth: 46
                    color: Config.alpha(root.providerColor(root.provider), 0.16)
                    radius: 14

                    Behavior on color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }

                    Md3Icon {
                        anchors.centerIn: parent
                        color: root.providerColor(root.provider)
                        filled: true
                        name: "appointment-new-symbolic"
                        size: 24

                        Behavior on color {
                            Md3ColorAnimation {
                                role: "state"
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.titleLarge.letterSpacing
                        font.pixelSize: 20
                        font.weight: 600
                        lineHeight: Md3.typeScale.titleLarge.lineHeight
                        lineHeightMode: Text.FixedHeight
                        text: qsTr("Add calendar account")
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                        font.pixelSize: Md3.typeScale.bodyMedium.size
                        font.weight: Font.Normal
                        lineHeight: Md3.typeScale.bodyMedium.lineHeight
                        lineHeightMode: Text.FixedHeight
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
            SettingsSegmentedControl {
                id: providerSelector

                Accessible.name: qsTr("Calendar provider")
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                backgroundColor: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.72 : 0.5)
                fontPixelSize: Md3.typeScale.labelLarge.size
                iconSize: 20
                minimumSegmentWidth: 0
                options: [
                    {
                        "iconSource": root.providerIconSource("google"),
                        "label": root.providerLabel("google"),
                        "value": "google"
                    },
                    {
                        "iconSource": root.providerIconSource("microsoft"),
                        "label": root.providerLabel("microsoft"),
                        "value": "microsoft"
                    },
                    {
                        "iconSource": root.providerIconSource("icloud"),
                        "label": root.providerLabel("icloud"),
                        "value": "icloud"
                    }
                ]
                selectedValue: root.provider
                selectionColor: root.providerContainerColor(root.provider)
                selectionContentColor: root.providerOnContainerColor(root.provider)
                showOptionIcons: true

                onSelected: value => root.provider = value
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                    font.pixelSize: Md3.typeScale.titleMedium.size
                    font.weight: Font.DemiBold
                    lineHeight: Md3.typeScale.titleMedium.lineHeight
                    lineHeightMode: Text.FixedHeight
                    text: root.providerSetupTitle(root.provider)
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                    font.pixelSize: Md3.typeScale.bodyMedium.size
                    font.weight: Md3.typeScale.bodyMedium.weight
                    lineHeight: Md3.typeScale.bodyMedium.lineHeight
                    lineHeightMode: Text.FixedHeight
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
                radius: Md3.shape.large
                visible: root.errorMessage !== ""

                RowLayout {
                    id: errorContent

                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 9

                    Md3Icon {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: 18
                        color: Config.md3.on_error_container
                        filled: true
                        name: "dialog-warning-symbolic"
                        size: 18
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_error_container
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                        font.pixelSize: Md3.typeScale.bodyMedium.size
                        font.weight: Md3.typeScale.bodyMedium.weight
                        lineHeight: Md3.typeScale.bodyMedium.lineHeight
                        lineHeightMode: Text.FixedHeight
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

                    onClicked: Quickshell.execDetached(DefaultAppsService.openUrl(root.providerSetupUrl(root.provider)))
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
                radius: Md3.shape.large

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Md3Icon {
                        Layout.preferredHeight: 20
                        Layout.preferredWidth: 20
                        color: root.providerOnContainerColor(root.provider)
                        filled: true
                        name: "dialog-information-symbolic"
                        size: 20
                    }
                    Text {
                        id: oauthNote

                        Layout.fillWidth: true
                        color: root.providerOnContainerColor(root.provider)
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                        font.pixelSize: Md3.typeScale.bodyMedium.size
                        font.weight: Md3.typeScale.bodyMedium.weight
                        lineHeight: Md3.typeScale.bodyMedium.lineHeight
                        lineHeightMode: Text.FixedHeight
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
                font.letterSpacing: Md3.typeScale.titleSmall.letterSpacing
                font.pixelSize: Md3.typeScale.titleSmall.size
                font.weight: Md3.typeScale.titleSmall.weight
                lineHeight: Md3.typeScale.titleSmall.lineHeight
                lineHeightMode: Text.FixedHeight
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
        fieldRadius: Md3.shape.large
        focusedBorderColor: Config.alpha(root.providerColor(root.provider), 0.68)
        inputFontPixelSize: Md3.typeScale.bodyLarge.size
        inputFontWeight: Font.Medium
        labelFontPixelSize: Md3.typeScale.labelLarge.size
        labelFontWeight: Md3.typeScale.labelLarge.emphasizedWeight
        normalBorderColor: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.38 : 0.24)
        placeholderFontPixelSize: Md3.typeScale.bodyLarge.size
        placeholderFontWeight: Font.Medium
    }
}
