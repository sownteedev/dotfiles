import "../../"
import "../../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property var accounts: []
    property var calendars: []
    property date displayMonth: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    property string errorMessage: ""
    readonly property var monthDays: buildMonthDays()
    property date selectedDate: new Date()
    property var syncingAccounts: ({})
    property date weekStart: new Date()

    signal accountRemoveRequested(string accountId)
    signal accountToggled(string accountId, bool visible)
    signal calendarToggled(string calendarId, bool visible)
    signal connectRequested
    signal createRequested
    signal dateSelected(var value)

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
    function moveMonth(offset) {
        displayMonth = new Date(displayMonth.getFullYear(), displayMonth.getMonth() + offset, 1);
    }

    onSelectedDateChanged: {
        if (selectedDate.getMonth() !== displayMonth.getMonth() || selectedDate.getFullYear() !== displayMonth.getFullYear())
            displayMonth = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1);
    }

    Flickable {
        id: sidebarFlickable

        anchors.bottomMargin: 10
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 4
        anchors.topMargin: 10
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: Math.max(height, sidebarContent.implicitHeight)
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        ColumnLayout {
            id: sidebarContent

            spacing: 12
            width: sidebarFlickable.width

            SettingsActionButton {
                Layout.fillWidth: true
                iconName: "appointment-new-symbolic"
                text: qsTr("Create event")

                onClicked: root.createRequested()
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.78 : 0.5)
                implicitHeight: monthContent.implicitHeight + 24
                radius: 18

                ColumnLayout {
                    id: monthContent

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            text: root.displayMonth.toLocaleString(Qt.locale(), "MMMM yyyy")
                        }
                        SettingsActionButton {
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: 32
                            iconName: "go-previous-symbolic"
                            iconOnly: true
                            text: qsTr("Previous month")

                            onClicked: root.moveMonth(-1)
                        }
                        SettingsActionButton {
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: 32
                            iconName: "go-next-symbolic"
                            iconOnly: true
                            text: qsTr("Next month")

                            onClicked: root.moveMonth(1)
                        }
                    }
                    Grid {
                        id: monthGrid

                        readonly property real cellWidth: Math.max(0, (width - columnSpacing * 6) / 7)

                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        columnSpacing: 2
                        columns: 7
                        rowSpacing: 3

                        Repeater {
                            model: [qsTr("M"), qsTr("T"), qsTr("W"), qsTr("T"), qsTr("F"), qsTr("S"), qsTr("S")]

                            Text {
                                required property int index
                                required property string modelData

                                color: index >= 5 ? Config.md3.tertiary : Config.alpha(Config.md3.on_surface, 0.58)
                                font.family: Config.fontName
                                font.pixelSize: 10
                                font.weight: Font.Bold
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
                                required property var modelData
                                readonly property date value: modelData.date

                                height: 32
                                width: monthGrid.cellWidth

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    color: root.isInWeek(dayCell.value) ? Config.alpha(Config.md3.primary, 0.075) : "transparent"
                                    radius: 10
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    color: root.isSameDay(dayCell.value, root.selectedDate) ? Config.md3.primary : dayMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                                    height: width
                                    radius: width / 2
                                    width: Math.max(0, Math.min(29, dayCell.width - 2))

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Config.animationDuration(110)
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        color: root.isSameDay(dayCell.value, root.selectedDate) ? Config.md3.on_primary : dayCell.modelData.inMonth ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.3)
                                        font.family: Config.fontName
                                        font.pixelSize: 11
                                        font.weight: root.isSameDay(dayCell.value, root.selectedDate) ? Font.Bold : Font.Medium
                                        text: dayCell.value.getDate()
                                    }
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
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    text: qsTr("Calendars")
                }
                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: Math.max(24, accountCount.implicitWidth + 14)
                    color: Config.alpha(Config.md3.primary, 0.12)
                    radius: 12

                    Text {
                        id: accountCount

                        anchors.centerIn: parent
                        color: Config.md3.primary
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        text: root.accounts.length
                    }
                }
                SettingsActionButton {
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 34
                    iconName: "contact-new-symbolic"
                    iconOnly: true
                    text: qsTr("Add calendar account")

                    onClicked: root.connectRequested()
                }
            }
            Repeater {
                model: root.accounts

                CalendarAccountCard {
                    required property var modelData

                    Layout.fillWidth: true
                    account: modelData
                    calendars: root.calendarsForAccount(modelData.id)
                    loading: Boolean(root.syncingAccounts && root.syncingAccounts[String(modelData.id || "")])

                    onAccountRemoveRequested: accountId => root.accountRemoveRequested(accountId)
                    onAccountVisibilityRequested: (accountId, visible) => root.accountToggled(accountId, visible)
                    onCalendarVisibilityRequested: (calendarId, visible) => root.calendarToggled(calendarId, visible)
                }
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.8 : 0.52)
                implicitHeight: emptyContent.implicitHeight + 24
                radius: 18
                visible: root.accounts.length === 0

                ColumnLayout {
                    id: emptyContent

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 44
                        color: Config.alpha(Config.md3.primary, 0.13)
                        radius: 15

                        IconImage {
                            anchors.centerIn: parent
                            height: 23
                            layer.enabled: true
                            source: Quickshell.iconPath("internet-services-symbolic")
                            width: 23

                            layer.effect: ColorOverlay {
                                color: Config.md3.primary
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Bring every calendar together")
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 11
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
                font.pixelSize: 11
                font.weight: Font.Medium
                text: root.errorMessage
                visible: text !== ""
                wrapMode: Text.Wrap
            }
        }
    }
}
