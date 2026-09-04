import "../../"
import "../../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    required property var account
    readonly property bool allVisible: visibleCalendarCount === calendars.length && calendars.length > 0
    property var calendars: []
    property bool loading: false
    readonly property bool partiallyVisible: visibleCalendarCount > 0 && !allVisible
    readonly property color providerColor: providerAccent(account ? String(account.provider || "") : "")
    property bool removeArmed: false
    readonly property int visibleCalendarCount: countVisibleCalendars()

    signal accountRemoveRequested(string accountId)
    signal accountVisibilityRequested(string accountId, bool visible)
    signal calendarVisibilityRequested(string calendarId, bool visible)

    function countVisibleCalendars() {
        var count = 0;
        for (var index = 0; index < calendars.length; ++index) {
            if (calendars[index] && calendars[index].visible !== false)
                count += 1;
        }
        return count;
    }
    function providerAccent(provider) {
        if (provider === "microsoft")
            return Config.md3.secondary;
        if (provider === "caldav")
            return Config.md3.tertiary;
        return Config.md3.primary;
    }
    function providerLabel(provider) {
        if (provider === "microsoft")
            return qsTr("Microsoft 365");
        if (provider === "caldav")
            return qsTr("iCloud");
        return qsTr("Google");
    }
    function providerOnColor(provider) {
        if (provider === "microsoft")
            return Config.md3.on_secondary;
        if (provider === "caldav")
            return Config.md3.on_tertiary;
        return Config.md3.on_primary;
    }
    function statusColor() {
        if (account && (account.needsReauth === true || String(account.lastError || "") !== ""))
            return Config.md3.error;
        if (loading)
            return Config.md3.tertiary;
        return Config.md3.primary;
    }
    function statusText() {
        if (!account)
            return qsTr("Unavailable");
        if (account.needsReauth === true)
            return qsTr("Reconnect required");
        if (String(account.lastError || "") !== "")
            return qsTr("Sync issue");
        if (loading)
            return qsTr("Syncing…");
        var value = new Date(account.lastSyncAt || "");
        if (!isNaN(value.getTime()))
            return qsTr("Synced %1").arg(Qt.formatTime(value, "HH:mm"));
        return qsTr("Waiting for sync");
    }

    color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.82 : 0.58)
    implicitHeight: cardContent.implicitHeight + 20
    radius: 18

    ColumnLayout {
        id: cardContent

        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 8

            Rectangle {
                id: accountToggle

                Accessible.name: qsTr("Filter %1 calendars").arg(root.providerLabel(String(root.account.provider || "")))
                Accessible.role: Accessible.CheckBox
                Layout.preferredHeight: 22
                Layout.preferredWidth: 22
                activeFocusOnTab: true
                border.color: root.allVisible || root.partiallyVisible ? root.providerColor : Config.alpha(Config.md3.on_surface, 0.34)
                border.width: 2
                color: root.allVisible || root.partiallyVisible ? root.providerColor : "transparent"
                radius: 7

                Keys.onReturnPressed: event => {
                    root.accountVisibilityRequested(String(root.account.id || ""), !root.allVisible);
                    event.accepted = true;
                }
                Keys.onSpacePressed: event => {
                    root.accountVisibilityRequested(String(root.account.id || ""), !root.allVisible);
                    event.accepted = true;
                }

                Text {
                    anchors.centerIn: parent
                    color: root.providerOnColor(String(root.account.provider || ""))
                    font.family: Config.fontName
                    font.pixelSize: root.partiallyVisible ? 15 : 12
                    font.weight: Font.Black
                    text: root.partiallyVisible ? "−" : "✓"
                    visible: root.allVisible || root.partiallyVisible
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        accountToggle.forceActiveFocus();
                        root.accountVisibilityRequested(String(root.account.id || ""), !root.allVisible);
                    }
                }
            }
            Rectangle {
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                color: Config.alpha(root.providerColor, 0.14)
                radius: 13

                CalendarProviderIcon {
                    anchors.centerIn: parent
                    height: 21
                    provider: String(root.account.provider || "")
                    tint: root.providerColor
                    width: 21
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    text: String(root.account.displayName || root.account.email || root.providerLabel(String(root.account.provider || "")))
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Rectangle {
                        Layout.preferredHeight: 6
                        Layout.preferredWidth: 6
                        color: root.statusColor()
                        radius: 3
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        text: root.statusText()
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: providerText.implicitWidth + 14
                color: Config.alpha(root.providerColor, 0.11)
                radius: 12

                Text {
                    id: providerText

                    anchors.centerIn: parent
                    color: root.providerColor
                    font.family: Config.fontName
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    text: root.providerLabel(String(root.account.provider || ""))
                }
            }
            Item {
                Layout.fillWidth: true
            }
            SettingsActionButton {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                enabled: !root.loading
                iconName: root.removeArmed ? "dialog-warning-symbolic" : "user-trash-symbolic"
                iconOnly: true
                text: root.removeArmed ? qsTr("Click again to remove") : qsTr("Remove account")

                onClicked: {
                    if (root.removeArmed) {
                        root.removeArmed = false;
                        removeArmTimer.stop();
                        root.accountRemoveRequested(String(root.account.id || ""));
                    } else {
                        root.removeArmed = true;
                        removeArmTimer.restart();
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            color: Config.alpha(Config.md3.on_surface, 0.065)
            implicitHeight: 1
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: root.calendars

                Rectangle {
                    id: calendarRow

                    readonly property color accentColor: modelData.color ? String(modelData.color) : root.providerColor
                    readonly property bool checked: modelData.visible !== false
                    required property var modelData

                    Accessible.name: String(modelData.name || qsTr("Calendar"))
                    Accessible.role: Accessible.CheckBox
                    Layout.fillWidth: true
                    activeFocusOnTab: true
                    color: calendarMouse.containsMouse || activeFocus ? Config.alpha(Config.md3.on_surface, 0.055) : "transparent"
                    implicitHeight: 38
                    radius: 11

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(110)
                        }
                    }

                    Keys.onReturnPressed: event => {
                        root.calendarVisibilityRequested(String(calendarRow.modelData.id || ""), !calendarRow.checked);
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: event => {
                        root.calendarVisibilityRequested(String(calendarRow.modelData.id || ""), !calendarRow.checked);
                        event.accepted = true;
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 7
                        spacing: 9

                        Rectangle {
                            Layout.preferredHeight: 17
                            Layout.preferredWidth: 17
                            border.color: calendarRow.checked ? calendarRow.accentColor : Config.alpha(Config.md3.on_surface, 0.32)
                            border.width: 2
                            color: calendarRow.checked ? calendarRow.accentColor : "transparent"
                            radius: 5

                            Text {
                                anchors.centerIn: parent
                                color: Config.md3.on_primary
                                font.family: Config.fontName
                                font.pixelSize: 11
                                font.weight: Font.Black
                                text: "✓"
                                visible: calendarRow.checked
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: calendarRow.checked ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.48)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            text: String(calendarRow.modelData.name || qsTr("Calendar"))
                        }
                        IconImage {
                            Layout.preferredHeight: 14
                            Layout.preferredWidth: 14
                            layer.enabled: true
                            source: Quickshell.iconPath("changes-prevent-symbolic")
                            visible: calendarRow.modelData.readOnly === true

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface_variant
                            }
                        }
                    }
                    MouseArea {
                        id: calendarMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            calendarRow.forceActiveFocus();
                            root.calendarVisibilityRequested(String(calendarRow.modelData.id || ""), !calendarRow.checked);
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 11
                text: qsTr("No calendars were found for this account.")
                visible: root.calendars.length === 0
                wrapMode: Text.Wrap
            }
        }
    }
    Timer {
        id: removeArmTimer

        interval: 3000
        repeat: false

        onTriggered: root.removeArmed = false
    }
}
