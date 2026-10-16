import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var connection
    property bool disconnectArmed: false
    required property string providerName

    Layout.fillWidth: true
    spacing: 6

    SettingsControlRow {
        controlWidth: connectButton.implicitWidth + (disconnectButton.visible ? disconnectButton.implicitWidth + 4 : 0)
        label: root.connection.connected ? qsTr("Connected: %1").arg(root.connection.accountLabel) : qsTr("%1 account").arg(root.providerName)
        note: root.connection.connected ? qsTr("Website session connected to this shell. API keys and SteamCMD stay separate.") : qsTr("Sign in in a separate window to save to your account. The private session stays on this computer.")
        showDivider: false

        SettingsActionButton {
            id: connectButton

            Layout.fillWidth: true
            activeFocusOnTab: true
            border.color: activeFocus ? Config.md3.on_primary : "transparent"
            enabled: !root.connection.busy
            iconName: "avatar-default-symbolic"
            primary: true
            spinning: root.connection.busy
            text: root.connection.busy ? qsTr("Please wait...") : root.connection.connected ? qsTr("Reconnect") : qsTr("Connect %1").arg(root.providerName)

            onClicked: root.connection.connectAccount()
        }
        SettingsActionButton {
            id: disconnectButton

            activeFocusOnTab: true
            enabled: !root.connection.busy
            iconName: root.disconnectArmed ? "checkmark-symbolic" : "user-offline-symbolic"
            iconOnly: true
            text: root.disconnectArmed ? qsTr("Confirm disconnect") : qsTr("Disconnect from this shell")
            visible: root.connection.connected

            onClicked: {
                if (root.disconnectArmed) {
                    root.disconnectArmed = false;
                    root.connection.disconnectAccount();
                } else {
                    root.disconnectArmed = true;
                    disarmTimer.restart();
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        color: root.connection.errorMessage ? Config.md3.error : Config.md3.on_surface_variant
        font.family: Config.fontName
        font.pixelSize: Md3.typeScale.bodyMedium.size
        text: root.disconnectArmed ? qsTr("Click the checkmark to remove this shell's stored website session. Your collections and subscriptions will not be deleted.") : root.connection.errorMessage || root.connection.statusMessage
        visible: text !== ""
        wrapMode: Text.Wrap
    }
    Timer {
        id: disarmTimer

        interval: 6000

        onTriggered: root.disconnectArmed = false
    }
}
