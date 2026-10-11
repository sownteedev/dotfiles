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
    readonly property string accountError: account ? String(account.lastError || "") : ""
    property bool actionsBusy: false
    readonly property bool allVisible: visibleCalendarCount === calendars.length && calendars.length > 0
    readonly property bool attentionRequired: needsReauth || accountError !== "" || !backendConnected || (account && account.enabled === false)
    property bool backendConnected: true
    property var calendars: []
    readonly property string lastSyncLabel: formatLastSync()
    readonly property string lastSyncShort: formatLastSyncShort()
    property bool loading: false
    readonly property bool needsReauth: account && account.needsReauth === true
    readonly property bool partiallyVisible: visibleCalendarCount > 0 && !allVisible
    readonly property color providerColor: providerAccent(account ? String(account.provider || "") : "")
    property bool removeArmed: false
    readonly property string statusLabel: needsReauth ? qsTr("Sign in again") : !backendConnected ? qsTr("Service disconnected") : account && account.enabled === false ? qsTr("Account disabled") : accountError !== "" ? qsTr("Sync failed") : ""
    readonly property string syncStatus: loading ? qsTr("Syncing…") : attentionRequired ? statusLabel : lastSyncLabel
    readonly property int visibleCalendarCount: countVisibleCalendars()

    signal accountReconnectRequested(var account)
    signal accountRemoveRequested(string accountId)
    signal accountRetryRequested(string accountId)
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
    function formatLastSync() {
        var value = account && account.lastSyncAt ? new Date(account.lastSyncAt) : null;
        if (!value || isNaN(value.getTime()))
            return qsTr("Not synced yet");
        return qsTr("Synced %1").arg(Qt.formatDateTime(value, "d MMM, HH:mm:ss"));
    }
    function formatLastSyncShort() {
        var value = account && account.lastSyncAt ? new Date(account.lastSyncAt) : null;
        if (!value || isNaN(value.getTime()))
            return qsTr("Not synced yet");
        var now = new Date();
        var isToday = value.getDate() === now.getDate() && value.getMonth() === now.getMonth() && value.getFullYear() === now.getFullYear();
        if (isToday)
            return qsTr("Last sync %1").arg(Qt.formatTime(value, "HH:mm"));
        return qsTr("Last sync %1").arg(Qt.formatDateTime(value, "d MMM, HH:mm"));
    }
    function isColorDark(colorValue) {
        var c = Qt.color(colorValue);
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) < 0.6;
    }
    function providerAccent(provider) {
        if (provider === "microsoft")
            return Config.md3.secondary;
        if (provider === "caldav" || provider === "icloud")
            return Config.md3.tertiary;
        return Config.md3.primary;
    }
    function providerLabel(provider) {
        if (provider === "microsoft")
            return qsTr("Microsoft 365");
        if (provider === "caldav" || provider === "icloud")
            return qsTr("iCloud");
        return qsTr("Google");
    }
    function providerOnColor(provider) {
        if (provider === "microsoft")
            return Config.md3.on_secondary;
        if (provider === "caldav" || provider === "icloud")
            return Config.md3.on_tertiary;
        return Config.md3.on_primary;
    }
    function requestSync() {
        if (loading || actionsBusy || !backendConnected || (account && account.enabled === false))
            return;
        if (needsReauth)
            accountReconnectRequested(account);
        else
            accountRetryRequested(String(account.id || ""));
    }

    border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.38 : 0.22)
    border.width: 1
    color: Config.md3.surface_container_low
    implicitHeight: cardContent.implicitHeight + 20
    radius: Md3.shape.large

    Behavior on border.color {
        Md3ColorAnimation {
            role: "state"
        }
    }
    Behavior on color {
        Md3ColorAnimation {
            role: "state"
        }
    }

    onVisibleChanged: {
        if (!visible) {
            removeArmed = false;
            removeArmTimer.stop();
        }
    }

    ColumnLayout {
        id: cardContent

        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 10

            // Avatar & Selection Toggle
            Rectangle {
                id: accountToggle

                Accessible.checked: root.allVisible
                Accessible.name: qsTr("Toggle %1 calendars").arg(root.providerLabel(String(root.account.provider || "")))
                Accessible.role: Accessible.CheckBox
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                activeFocusOnTab: true
                border.color: accountToggle.activeFocus ? Config.md3.primary : accountToggleMouse.containsMouse ? Config.alpha(root.providerColor, 0.45) : Config.alpha(root.providerColor, 0.18)
                border.width: accountToggle.activeFocus ? 2 : 1
                color: accountToggleMouse.containsMouse ? Config.alpha(root.providerColor, 0.18) : Config.alpha(root.providerColor, 0.10)
                radius: Md3.shape.medium

                Behavior on border.color {
                    Md3ColorAnimation {
                        role: "state"
                    }
                }
                Behavior on color {
                    Md3ColorAnimation {
                        role: "state"
                    }
                }

                Keys.onReturnPressed: event => {
                    root.accountVisibilityRequested(String(root.account.id || ""), !root.allVisible);
                    event.accepted = true;
                }
                Keys.onSpacePressed: event => {
                    root.accountVisibilityRequested(String(root.account.id || ""), !root.allVisible);
                    event.accepted = true;
                }

                CalendarProviderIcon {
                    anchors.centerIn: parent
                    height: 20
                    provider: String(root.account.provider || "")
                    tint: root.providerColor
                    width: 20
                }

                // Halo status cutout badge
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -2
                    anchors.right: parent.right
                    anchors.rightMargin: -2
                    border.color: root.color
                    border.width: 2
                    color: root.attentionRequired ? Config.md3.error : (root.allVisible || root.partiallyVisible ? root.providerColor : Config.md3.surface_container_highest)
                    height: 16
                    radius: 8
                    width: 16

                    Behavior on color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }

                    Md3Icon {
                        anchors.centerIn: parent
                        color: root.attentionRequired ? Config.md3.on_error : root.providerOnColor(String(root.account.provider || ""))
                        name: root.attentionRequired ? "dialog-error-symbolic" : "checkmark-symbolic"
                        size: 10
                        visible: root.attentionRequired || root.allVisible
                        weight: 700
                    }
                    Text {
                        anchors.centerIn: parent
                        color: root.providerOnColor(String(root.account.provider || ""))
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        text: "−"
                        visible: !root.attentionRequired && root.partiallyVisible
                    }
                }
                MouseArea {
                    id: accountToggleMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.accountVisibilityRequested(String(root.account.id || ""), !root.allVisible)
                }
                Md3ToolTip {
                    text: root.allVisible ? qsTr("Hide %1 calendars").arg(root.providerLabel(String(root.account.provider || ""))) : qsTr("Show %1 calendars").arg(root.providerLabel(String(root.account.provider || "")))
                    visible: accountToggleMouse.containsMouse
                }
            }

            // Account Info
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleSmall.letterSpacing
                    font.pixelSize: Md3.typeScale.titleSmall.size
                    font.weight: 600
                    text: String(root.account.displayName || root.account.email || root.providerLabel(String(root.account.provider || "")))
                }
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    color: root.attentionRequired && !root.loading ? Config.md3.error : Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                    font.pixelSize: 12
                    font.weight: root.attentionRequired ? 500 : 400
                    text: root.loading ? qsTr("Syncing…") : root.attentionRequired ? root.statusLabel : root.lastSyncShort
                }
            }

            // Actions: Sync & Remove
            RowLayout {
                spacing: 6

                Rectangle {
                    id: syncButton

                    Accessible.name: root.loading ? qsTr("Syncing this account…") : qsTr("Sync account")
                    Accessible.role: Accessible.Button
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: 36
                    activeFocusOnTab: true
                    border.color: syncButton.activeFocus ? Config.md3.primary : (syncMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.35) : Config.alpha(Config.md3.outline_variant, 0.28))
                    border.width: syncButton.activeFocus ? 2 : 1
                    color: root.loading ? Config.alpha(Config.md3.primary, 0.20) : (syncMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.16) : Config.alpha(Config.md3.on_surface, 0.08))
                    enabled: !root.loading && !root.actionsBusy && root.backendConnected && (root.account && root.account.enabled !== false)
                    opacity: enabled || root.loading ? 1 : 0.4
                    radius: Md3.shape.full
                    scale: syncMouse.pressed ? 0.93 : 1

                    Behavior on border.color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }
                    Behavior on color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }
                    Behavior on scale {
                        Md3NumberAnimation {
                            role: "microSpatial"
                        }
                    }

                    Keys.onReturnPressed: event => {
                        root.requestSync();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: event => {
                        root.requestSync();
                        event.accepted = true;
                    }

                    Item {
                        anchors.centerIn: parent
                        height: 20
                        width: 20

                        Md3Icon {
                            id: syncIcon

                            anchors.centerIn: parent
                            color: root.loading || syncMouse.containsMouse ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.85)
                            name: root.needsReauth ? "link-symbolic" : "emblem-synchronizing-symbolic"
                            size: 20

                            Behavior on color {
                                Md3ColorAnimation {
                                    role: "state"
                                }
                            }
                            RotationAnimation on rotation {
                                duration: 1000
                                from: 0
                                loops: Animation.Infinite
                                running: root.loading && root.visible
                                to: 360
                            }
                        }
                    }
                    MouseArea {
                        id: syncMouse

                        anchors.fill: parent
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        hoverEnabled: true

                        onClicked: root.requestSync()
                    }
                    Md3ToolTip {
                        text: root.loading ? qsTr("Syncing this account…") : !root.backendConnected ? root.statusLabel : root.actionsBusy ? qsTr("Sync busy") : root.needsReauth ? qsTr("Sign in again to sync") : root.accountError || qsTr("Sync now (%1)").arg(root.lastSyncLabel)
                        visible: syncMouse.containsMouse
                    }
                }
                Rectangle {
                    id: removeButton

                    function triggerAction() {
                        if (root.removeArmed) {
                            root.removeArmed = false;
                            root.accountRemoveRequested(String(root.account.id || ""));
                        } else {
                            root.removeArmed = true;
                            removeArmTimer.restart();
                        }
                    }

                    Accessible.name: root.removeArmed ? qsTr("Confirm removal") : qsTr("Remove account")
                    Accessible.role: Accessible.Button
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: root.removeArmed ? removeContent.implicitWidth + 24 : 36
                    activeFocusOnTab: true
                    border.color: removeButton.activeFocus ? Config.md3.error : (root.removeArmed ? Config.md3.error : removeMouse.containsMouse ? Config.alpha(Config.md3.error, 0.35) : Config.alpha(Config.md3.outline_variant, 0.28))
                    border.width: removeButton.activeFocus ? 2 : 1
                    clip: true
                    color: root.removeArmed ? Config.md3.error : (removeMouse.containsMouse ? Config.alpha(Config.md3.error, 0.16) : Config.alpha(Config.md3.on_surface, 0.08))
                    radius: Md3.shape.full
                    scale: removeMouse.pressed ? 0.93 : 1

                    Behavior on Layout.preferredWidth {
                        Md3NumberAnimation {
                            role: "microSpatial"
                        }
                    }
                    Behavior on border.color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }
                    Behavior on color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }
                    Behavior on scale {
                        Md3NumberAnimation {
                            role: "microSpatial"
                        }
                    }

                    Keys.onReturnPressed: event => {
                        removeButton.triggerAction();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: event => {
                        removeButton.triggerAction();
                        event.accepted = true;
                    }

                    RowLayout {
                        id: removeContent

                        anchors.centerIn: parent
                        spacing: 6

                        Md3Icon {
                            Layout.alignment: Qt.AlignVCenter
                            color: root.removeArmed ? Config.md3.on_error : (removeMouse.containsMouse ? Config.md3.error : Config.alpha(Config.md3.on_surface, 0.85))
                            name: root.removeArmed ? "dialog-warning-symbolic" : "user-trash-symbolic"
                            size: 20

                            Behavior on color {
                                Md3ColorAnimation {
                                    role: "state"
                                }
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            color: Config.md3.on_error
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.labelMedium.letterSpacing
                            font.pixelSize: Md3.typeScale.labelMedium.size
                            font.weight: 600
                            text: qsTr("Confirm")
                            visible: root.removeArmed
                        }
                    }
                    MouseArea {
                        id: removeMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: removeButton.triggerAction()
                    }
                    Md3ToolTip {
                        text: root.removeArmed ? qsTr("Click again to confirm removal") : qsTr("Remove account")
                        visible: removeMouse.containsMouse
                    }
                }
            }
        }

        // Attention Banner (Appears only if error/reauth needed)
        Rectangle {
            Layout.fillWidth: true
            border.color: Config.alpha(Config.md3.error, 0.25)
            border.width: 1
            color: Config.alpha(Config.md3.error_container, 0.45)
            implicitHeight: attentionRow.implicitHeight + 10
            radius: Md3.shape.small
            visible: root.attentionRequired && !root.loading

            RowLayout {
                id: attentionRow

                anchors.bottomMargin: 4
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                anchors.topMargin: 4
                spacing: 6

                Md3Icon {
                    color: Config.md3.error
                    name: "dialog-warning-symbolic"
                    size: 15
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_error_container
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: Md3.typeScale.labelSmall.size
                    font.weight: 500
                    text: root.statusLabel
                }
                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: bannerActionText.implicitWidth + 14
                    color: Config.md3.error
                    radius: Md3.shape.full

                    Text {
                        id: bannerActionText

                        anchors.centerIn: parent
                        color: Config.md3.on_error
                        font.family: Config.fontName
                        font.pixelSize: Md3.typeScale.labelSmall.size
                        font.weight: 600
                        text: root.needsReauth ? qsTr("Sign in") : qsTr("Retry")
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.requestSync()
                    }
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            color: Config.alpha(Config.md3.outline_variant, 0.22)
            implicitHeight: 1
        }

        // Calendars list
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: root.calendars

                Rectangle {
                    id: calendarRow

                    readonly property color accentColor: modelData.color ? String(modelData.color) : root.providerColor
                    readonly property bool checked: modelData.visible !== false
                    readonly property bool darkAccent: root.isColorDark(accentColor)
                    required property var modelData

                    Accessible.checked: checked
                    Accessible.name: String(modelData.name || qsTr("Calendar"))
                    Accessible.role: Accessible.CheckBox
                    Layout.fillWidth: true
                    activeFocusOnTab: true
                    border.color: calendarRow.activeFocus ? Config.md3.primary : "transparent"
                    border.width: calendarRow.activeFocus ? 1.5 : 0
                    color: calMouse.pressed ? Config.alpha(Config.md3.on_surface, Md3.state.pressed) : calMouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : "transparent"
                    implicitHeight: 34
                    radius: Md3.shape.small

                    Behavior on color {
                        Md3ColorAnimation {
                            role: "state"
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
                        anchors.rightMargin: 8
                        spacing: 10

                        // MD3 Checkbox
                        Rectangle {
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: 18
                            border.color: calendarRow.checked ? calendarRow.accentColor : Config.alpha(calendarRow.accentColor, 0.65)
                            border.width: calendarRow.checked ? 0 : 2
                            color: calendarRow.checked ? calendarRow.accentColor : "transparent"
                            radius: Md3.shape.extraSmall

                            Behavior on border.color {
                                Md3ColorAnimation {
                                    role: "state"
                                }
                            }
                            Behavior on color {
                                Md3ColorAnimation {
                                    role: "state"
                                }
                            }

                            Md3Icon {
                                anchors.centerIn: parent
                                color: calendarRow.darkAccent ? "#ffffff" : "#000000"
                                name: "checkmark-symbolic"
                                size: 12
                                visible: calendarRow.checked
                                weight: 700
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: calendarRow.checked ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.48)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                            font.pixelSize: Md3.typeScale.bodyMedium.size
                            font.weight: calendarRow.checked ? 500 : 400
                            text: String(calendarRow.modelData.name || qsTr("Calendar"))

                            Behavior on color {
                                Md3ColorAnimation {
                                    role: "state"
                                }
                            }
                        }
                        Md3Icon {
                            Layout.preferredHeight: 15
                            Layout.preferredWidth: 15
                            color: Config.alpha(Config.md3.on_surface_variant, 0.6)
                            name: "changes-prevent-symbolic"
                            size: 15
                            visible: calendarRow.modelData.readOnly === true && !calendarRow.modelData.isTaskList

                            Md3ToolTip {
                                text: qsTr("Read-only")
                                visible: lockMouse.containsMouse
                            }
                            MouseArea {
                                id: lockMouse

                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                        Md3Icon {
                            Layout.preferredHeight: 15
                            Layout.preferredWidth: 15
                            color: Config.alpha(calendarRow.accentColor, 0.8)
                            name: "checkbox-checked-symbolic"
                            size: 15
                            visible: calendarRow.modelData.isTaskList === true

                            Md3ToolTip {
                                text: qsTr("Task list")
                                visible: taskMouse.containsMouse
                            }
                            MouseArea {
                                id: taskMouse

                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                    MouseArea {
                        id: calMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.calendarVisibilityRequested(String(calendarRow.modelData.id || ""), !calendarRow.checked)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                font.pixelSize: Md3.typeScale.bodySmall.size
                font.weight: Md3.typeScale.bodySmall.weight
                text: root.loading ? qsTr("Syncing calendars…") : qsTr("No calendars were found for this account.")
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
