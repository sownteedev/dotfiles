import "../../"
import "../../components"
import "lunar.js" as Lunar
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property bool accountActionsBusy: false
    property var accounts: []
    readonly property int attentionCount: accounts.filter(account => account.needsReauth === true || String(account.lastError || "") !== "" || account.enabled === false).length
    property bool backendConnected: true
    property var calendars: []
    readonly property bool compactHeight: height < 520
    property date displayMonth: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    property string errorMessage: ""
    property bool loading: false
    readonly property var monthDays: buildMonthDays()
    property date selectedDate: new Date()
    property var syncingAccounts: ({})
    property date weekStart: new Date()

    signal accountReconnectRequested(var account)
    signal accountRemoveRequested(string accountId)
    signal accountRetryRequested(string accountId)
    signal accountToggled(string accountId, bool visible)
    signal calendarToggled(string calendarId, bool visible)
    signal connectRequested
    signal createRequested
    signal createTaskRequested
    signal dateSelected(var value)
    signal todayRequested

    function addDays(value, amount) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + amount);
    }
    function buildMonthDays() {
        var first = new Date(displayMonth.getFullYear(), displayMonth.getMonth(), 1);
        var mondayOffset = (first.getDay() + 6) % 7;
        var start = addDays(first, -mondayOffset);
        var result = [];
        for (var i = 0; i < 42; ++i) {
            var value = addDays(start, i);
            result.push({
                "date": value,
                "inMonth": value.getMonth() === displayMonth.getMonth()
            });
        }
        return result;
    }
    function calendarsForAccount(accountId) {
        var wanted = String(accountId || "");
        var result = [];
        for (var index = 0; index < calendars.length; ++index) {
            if (String(calendars[index].accountId || "") === wanted)
                result.push(calendars[index]);
        }
        return result;
    }
    function dayDifference(first, second) {
        var firstUtc = Date.UTC(first.getFullYear(), first.getMonth(), first.getDate());
        var secondUtc = Date.UTC(second.getFullYear(), second.getMonth(), second.getDate());
        return Math.round((secondUtc - firstUtc) / 86400000);
    }
    function isInWeek(value) {
        var offset = dayDifference(weekStart, value);
        return offset >= 0 && offset < 7;
    }
    function isSameDay(first, second) {
        return first.getDate() === second.getDate() && first.getMonth() === second.getMonth() && first.getFullYear() === second.getFullYear();
    }

    onSelectedDateChanged: {
        if (selectedDate.getMonth() !== displayMonth.getMonth() || selectedDate.getFullYear() !== displayMonth.getFullYear())
            displayMonth = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1);
    }

    ColumnLayout {
        anchors.bottomMargin: 12
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        anchors.topMargin: 12
        spacing: root.compactHeight ? 12 : 16

        ColumnLayout {
            id: fixedContent

            Layout.fillWidth: true
            spacing: root.compactHeight ? 12 : 16

            SettingsActionButton {
                Layout.fillWidth: true
                Layout.preferredHeight: root.compactHeight ? 44 : 52
                iconName: "list-add-symbolic"
                iconSize: 24
                primary: true
                radius: Md3.shape.full
                text: qsTr("Create")
                textPixelSize: 16
                textWeight: Font.DemiBold

                onClicked: root.createRequested()
            }
            Rectangle {
                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.34 : 0.22)
                border.width: 1
                color: Config.alpha(Config.md3.surface_container_low, Config.lightTheme ? 0.86 : 0.46)
                implicitHeight: monthContent.implicitHeight + 28
                radius: 20

                ColumnLayout {
                    id: monthContent

                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Accessible.name: root.displayMonth.toLocaleString(Qt.locale(), "MMMM yyyy")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.titleSmall.letterSpacing
                            font.pixelSize: Md3.typeScale.titleSmall.size
                            font.weight: 600
                            text: root.displayMonth.toLocaleString(Qt.locale(), monthContent.width < 230 ? "MMM yyyy" : "MMMM yyyy")
                        }
                        SettingsActionButton {
                            Layout.preferredHeight: 32
                            primary: true
                            text: qsTr("Today")

                            onClicked: root.todayRequested()
                        }
                        SettingsActionButton {
                            Accessible.checkable: true
                            Accessible.checked: Config.calendarShowLunar
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: 32
                            activeFocusOnTab: true
                            iconName: "weather-clear-night-symbolic"
                            iconOnly: true
                            iconSize: 18
                            primary: Config.calendarShowLunar
                            text: qsTr("Lunar dates")

                            onClicked: Config.calendarShowLunar = !Config.calendarShowLunar
                        }
                    }
                    Grid {
                        id: monthGrid

                        readonly property real cellWidth: Math.max(0, (width - columnSpacing * 6) / 7)

                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        columnSpacing: 1
                        columns: 7
                        rowSpacing: 2

                        Repeater {
                            model: [qsTr("M"), qsTr("T"), qsTr("W"), qsTr("T"), qsTr("F"), qsTr("S"), qsTr("S")]

                            Text {
                                required property int index
                                required property string modelData

                                color: index >= 5 ? Config.md3.tertiary : Config.alpha(Config.md3.on_surface, 0.58)
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.labelSmall.letterSpacing
                                font.pixelSize: Md3.typeScale.labelSmall.size
                                font.weight: 600
                                height: 18
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                verticalAlignment: Text.AlignVCenter
                                width: monthGrid.cellWidth
                            }
                        }
                        Repeater {
                            model: root.monthDays

                            Item {
                                id: dayCell

                                required property int index
                                readonly property bool isSelected: root.isSameDay(dayCell.value, root.selectedDate)
                                readonly property bool isToday: root.isSameDay(dayCell.value, new Date())
                                readonly property var lunarDate: Config.calendarShowLunar ? Lunar.getLunarDateForDate(dayCell.value) : null
                                readonly property string lunarLabel: lunarDate ? (lunarDate.day === 1 ? `${lunarDate.day}/${lunarDate.month}` : String(lunarDate.day)) : ""
                                readonly property bool lunarSpecial: Boolean(lunarDate && (lunarDate.day === 1 || lunarDate.day === 15))
                                required property var modelData
                                readonly property date value: modelData.date

                                Accessible.name: Config.calendarShowLunar ? qsTr("%1, lunar %2").arg(Qt.formatDate(dayCell.value, Qt.DefaultLocaleLongDate)).arg(dayCell.lunarLabel) : Qt.formatDate(dayCell.value, Qt.DefaultLocaleLongDate)
                                Accessible.role: Accessible.Button
                                height: root.compactHeight ? 25 : 31
                                width: monthGrid.cellWidth

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    color: root.isInWeek(dayCell.value) ? Config.alpha(Config.md3.primary, 0.075) : "transparent"
                                    radius: 10
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    border.color: dayCell.isToday && !dayCell.isSelected ? Config.md3.primary : "transparent"
                                    border.width: dayCell.isToday && !dayCell.isSelected ? 1.5 : 0
                                    color: dayCell.isSelected ? Config.md3.primary : dayCell.isToday ? (dayMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.32) : Config.alpha(Config.md3.primary, 0.20)) : dayMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                                    height: width
                                    radius: width / 2
                                    width: Math.max(0, Math.min(29, dayCell.width - 2, dayCell.height - 2))

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Config.animationDuration(110)
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        color: dayCell.isSelected ? Config.md3.on_primary : dayCell.isToday ? Config.md3.primary : dayCell.modelData.inMonth ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.3)
                                        font.family: Config.fontName
                                        font.letterSpacing: Md3.typeScale.labelMedium.letterSpacing
                                        font.pixelSize: Md3.typeScale.labelMedium.size
                                        font.weight: dayCell.isSelected || dayCell.isToday ? 600 : Md3.typeScale.labelMedium.weight
                                        text: dayCell.value.getDate()
                                    }
                                }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    anchors.top: parent.top
                                    anchors.topMargin: 3
                                    color: dayCell.lunarSpecial ? Config.md3.tertiary : "transparent"
                                    height: 3
                                    radius: 1.5
                                    visible: dayCell.lunarSpecial
                                    width: 3
                                }
                                MouseArea {
                                    id: dayMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: root.dateSelected(dayCell.value)
                                }
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                        font.pixelSize: Md3.typeScale.titleMedium.size
                        font.weight: 600
                        text: qsTr("Calendars")
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                        font.pixelSize: Md3.typeScale.bodySmall.size
                        font.weight: Md3.typeScale.bodySmall.weight
                        text: !root.backendConnected ? qsTr("Calendar service disconnected") : root.loading ? qsTr("Loading accounts…") : root.attentionCount > 0 ? qsTr("%1 accounts · %2 need attention").arg(root.accounts.length).arg(root.attentionCount) : root.accounts.length === 1 ? qsTr("1 account") : qsTr("%1 accounts").arg(root.accounts.length)
                    }
                }
                SettingsActionButton {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: 36
                    color: "transparent"
                    enabled: !root.loading
                    iconName: "contact-new-symbolic"
                    iconOnly: true
                    iconSize: 18
                    tooltipText: qsTr("Add calendar account")

                    onClicked: root.connectRequested()
                }
            }
        }
        Flickable {
            id: accountsFlickable

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumHeight: 0
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: accountsContent.implicitHeight
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            ColumnLayout {
                id: accountsContent

                spacing: 16
                width: accountsFlickable.width

                Repeater {
                    model: root.accounts

                    CalendarAccountCard {
                        required property var modelData

                        Layout.fillWidth: true
                        account: modelData
                        actionsBusy: root.accountActionsBusy
                        backendConnected: root.backendConnected
                        calendars: root.calendarsForAccount(modelData.id)
                        loading: Boolean(root.syncingAccounts && root.syncingAccounts[String(modelData.id || "")])

                        onAccountReconnectRequested: account => root.accountReconnectRequested(account)
                        onAccountRemoveRequested: accountId => root.accountRemoveRequested(accountId)
                        onAccountRetryRequested: accountId => root.accountRetryRequested(accountId)
                        onAccountVisibilityRequested: (accountId, visible) => root.accountToggled(accountId, visible)
                        onCalendarVisibilityRequested: (calendarId, visible) => root.calendarToggled(calendarId, visible)
                    }
                }
                Rectangle {
                    Accessible.ignored: true
                    Layout.fillWidth: true
                    border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.38 : 0.22)
                    border.width: 1
                    color: Config.md3.surface_container_low
                    implicitHeight: 88
                    radius: Md3.shape.large
                    visible: root.loading && root.accounts.length === 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Rectangle {
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: 36
                            color: Config.md3.surface_container_highest
                            radius: 12
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 10
                                color: Config.md3.surface_container_highest
                                radius: 5
                            }
                            Rectangle {
                                Layout.preferredHeight: 8
                                Layout.preferredWidth: 72
                                color: Config.md3.surface_container_high
                                radius: 4
                            }
                        }
                    }
                }
                Rectangle {
                    id: localTasksCard

                    Accessible.checked: Config.calendarShowLocalTasks
                    Accessible.name: qsTr("Local tasks")
                    Accessible.role: Accessible.CheckBox
                    Layout.fillWidth: true
                    activeFocusOnTab: true
                    border.color: localTasksCard.activeFocus ? Config.md3.primary : Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.38 : 0.22)
                    border.width: localTasksCard.activeFocus ? 2 : 1
                    color: Config.md3.surface_container_low
                    implicitHeight: 56
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

                    Keys.onReturnPressed: event => {
                        Config.calendarShowLocalTasks = !Config.calendarShowLocalTasks;
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: event => {
                        Config.calendarShowLocalTasks = !Config.calendarShowLocalTasks;
                        event.accepted = true;
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Config.alpha(Config.md3.on_surface, localTasksMouse.pressed ? Md3.state.pressed : localTasksMouse.containsMouse ? Md3.state.hover : 0)
                        radius: parent.radius

                        Behavior on color {
                            Md3ColorAnimation {
                                role: "state"
                            }
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: 36
                            border.color: Config.alpha(Config.md3.primary, 0.22)
                            border.width: 1
                            color: Config.alpha(Config.md3.primary, 0.12)
                            radius: Md3.shape.medium

                            Md3Icon {
                                anchors.centerIn: parent
                                color: Config.md3.primary
                                filled: true
                                name: "checkbox-checked-symbolic"
                                size: 20
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                                font.pixelSize: Md3.typeScale.bodyMedium.size
                                font.weight: 600
                                text: qsTr("Local tasks")
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface_variant
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                                font.pixelSize: 12
                                text: qsTr("Stored on this device")
                            }
                        }
                        ToggleSwitch {
                            checked: Config.calendarShowLocalTasks
                            interactive: false
                        }
                    }
                    MouseArea {
                        id: localTasksMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: Config.calendarShowLocalTasks = !Config.calendarShowLocalTasks
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.38 : 0.22)
                    border.width: 1
                    color: Config.md3.surface_container_low
                    implicitHeight: emptyContent.implicitHeight + 28
                    radius: Md3.shape.large
                    visible: root.accounts.length === 0 && !root.loading && root.errorMessage === ""

                    ColumnLayout {
                        id: emptyContent

                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 9

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 48
                            Layout.preferredWidth: 48
                            color: Config.alpha(Config.md3.primary, 0.13)
                            radius: 15

                            Md3Icon {
                                anchors.centerIn: parent
                                color: Config.md3.primary
                                filled: true
                                name: "internet-services-symbolic"
                                size: 24
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.titleSmall.letterSpacing
                            font.pixelSize: Md3.typeScale.titleSmall.size
                            font.weight: 600
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("Bring every calendar together")
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                            font.pixelSize: Md3.typeScale.bodySmall.size
                            font.weight: Md3.typeScale.bodySmall.weight
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("Connect Google, Microsoft 365, or iCloud. Events stay in one timeline.")
                            wrapMode: Text.Wrap
                        }
                        SettingsActionButton {
                            Layout.alignment: Qt.AlignHCenter
                            iconName: "contact-new-symbolic"
                            primary: true
                            text: qsTr("Add account")

                            onClicked: root.connectRequested()
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                    font.pixelSize: Md3.typeScale.bodySmall.size
                    font.weight: Md3.typeScale.bodySmall.weight
                    text: root.errorMessage
                    visible: text !== ""
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
