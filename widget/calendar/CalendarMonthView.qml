import "../../"
import "../../components"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property bool available: false
    readonly property var eventBuckets: buildEventBuckets()
    property var events: []
    readonly property date gridStart: beginningOfGrid(monthStart)
    property var hiddenCalendars: ({})
    property bool loading: false
    property date monthDate: new Date()
    readonly property var monthDays: buildMonthDays()
    readonly property date monthStart: new Date(monthDate.getFullYear(), monthDate.getMonth(), 1)
    property date now: new Date()
    property date selectedDate: new Date()
    readonly property real weekdayHeaderHeight: 42

    signal createRequested(var value, var anchorRect)
    signal daySelected(var value)
    signal eventClicked(var eventData, var anchorRect)
    signal weekRequested(var value)

    function addDays(value, amount) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + amount);
    }
    function beginningOfGrid(value) {
        var day = value.getDay();
        var offset = day === 0 ? -6 : 1 - day;
        return addDays(value, offset);
    }
    function buildEventBuckets() {
        var result = {};
        for (var dayIndex = 0; dayIndex < monthDays.length; ++dayIndex)
            result[monthDays[dayIndex].key] = [];

        var rangeStart = startOfDay(gridStart);
        var rangeEnd = addDays(rangeStart, 42);
        var source = events || [];
        for (var eventIndex = 0; eventIndex < source.length; ++eventIndex) {
            var eventData = source[eventIndex];
            if (!eventData || isCalendarHidden(eventData.calendarId))
                continue;

            var eventStart = eventData.allDay ? parseDateOnly(eventData.start) : new Date(eventData.start);
            var eventEnd = eventData.allDay ? parseDateOnly(eventData.end) : new Date(eventData.end);
            if (isNaN(eventStart.getTime()))
                continue;
            if (isNaN(eventEnd.getTime()) || eventEnd <= eventStart)
                eventEnd = eventData.allDay ? addDays(eventStart, 1) : new Date(eventStart.getTime() + 3600000);

            var firstDay = startOfDay(eventStart);
            var lastDayExclusive = eventData.allDay ? startOfDay(eventEnd) : addDays(startOfDay(new Date(eventEnd.getTime() - 1)), 1);
            if (lastDayExclusive <= firstDay)
                lastDayExclusive = addDays(firstDay, 1);
            if (firstDay < rangeStart)
                firstDay = rangeStart;
            if (lastDayExclusive > rangeEnd)
                lastDayExclusive = rangeEnd;

            for (var cursor = firstDay; cursor < lastDayExclusive; cursor = addDays(cursor, 1)) {
                var key = dateKey(cursor);
                if (result[key])
                    result[key].push(eventData);
            }
        }

        var keys = Object.keys(result);
        for (var keyIndex = 0; keyIndex < keys.length; ++keyIndex) {
            result[keys[keyIndex]].sort(function (first, second) {
                if (first.allDay !== second.allDay)
                    return first.allDay ? -1 : 1;
                return eventStartTime(first) - eventStartTime(second);
            });
        }
        return result;
    }
    function buildMonthDays() {
        var result = [];
        for (var index = 0; index < 42; ++index) {
            var value = addDays(gridStart, index);
            result.push({
                "date": value,
                "inMonth": value.getMonth() === monthStart.getMonth() && value.getFullYear() === monthStart.getFullYear(),
                "key": dateKey(value)
            });
        }
        return result;
    }
    function clearSelection() {
    }
    function dateKey(value) {
        return String(value.getFullYear()) + "-" + String(value.getMonth() + 1).padStart(2, "0") + "-" + String(value.getDate()).padStart(2, "0");
    }
    function eventColor(eventData) {
        var candidate = eventData && eventData.calendarColor ? String(eventData.calendarColor) : "";
        return candidate !== "" ? candidate : Config.md3.primary;
    }
    function eventStartTime(eventData) {
        if (!eventData)
            return 0;
        var value = eventData.allDay ? parseDateOnly(eventData.start) : new Date(eventData.start);
        return isNaN(value.getTime()) ? 0 : value.getTime();
    }
    function eventsForDay(key) {
        return eventBuckets[key] || [];
    }
    function formatEventTime(eventData) {
        if (!eventData || eventData.allDay)
            return "";
        var value = new Date(eventData.start);
        return isNaN(value.getTime()) ? "" : Qt.formatTime(value, "HH:mm");
    }
    function isCalendarHidden(calendarId) {
        return Boolean(hiddenCalendars && hiddenCalendars[String(calendarId || "")]);
    }
    function isSameDay(first, second) {
        return first.getDate() === second.getDate() && first.getMonth() === second.getMonth() && first.getFullYear() === second.getFullYear();
    }
    function parseDateOnly(value) {
        var parts = String(value || "").slice(0, 10).split("-");
        if (parts.length !== 3)
            return new Date(NaN);
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }
    function startOfDay(value) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate());
    }

    clip: true
    color: Config.alpha(Config.md3.surface_container_low, Config.lightTheme ? 0.72 : 0.34)
    radius: 22

    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true

        onTriggered: root.now = new Date()
    }
    Column {
        anchors.fill: parent

        Item {
            id: weekdayHeader

            height: root.weekdayHeaderHeight
            width: parent.width

            Row {
                anchors.fill: parent

                Repeater {
                    model: 7

                    Item {
                        required property int index

                        height: weekdayHeader.height
                        width: weekdayHeader.width / 7

                        Text {
                            anchors.centerIn: parent
                            color: index >= 5 ? Config.md3.tertiary : Config.md3.on_surface_variant
                            font.capitalization: Font.AllUppercase
                            font.family: Config.fontName
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            text: Qt.formatDate(root.addDays(root.gridStart, index), "ddd")
                        }
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                color: Config.alpha(Config.md3.on_surface, 0.08)
                height: 1
                width: parent.width
            }
        }
        Grid {
            id: monthGrid

            columns: 7
            height: Math.max(0, parent.height - root.weekdayHeaderHeight)
            rows: 6
            width: parent.width

            Repeater {
                model: root.monthDays

                Rectangle {
                    id: dayCell

                    readonly property var dayEvents: root.eventsForDay(modelData.key)
                    readonly property int eventSlotCapacity: Math.max(1, Math.min(4, Math.floor((height - 43) / 25)))
                    readonly property int extraEventCount: Math.max(0, dayEvents.length - visibleEvents.length)
                    required property int index
                    required property var modelData
                    readonly property bool selected: root.isSameDay(modelData.date, root.selectedDate)
                    readonly property bool today: root.isSameDay(modelData.date, root.now)
                    readonly property int visibleEventCount: dayEvents.length > eventSlotCapacity ? Math.max(0, eventSlotCapacity - 1) : Math.min(dayEvents.length, eventSlotCapacity)
                    readonly property var visibleEvents: dayEvents.slice(0, visibleEventCount)

                    Accessible.name: Qt.formatDate(modelData.date, Qt.DefaultLocaleLongDate)
                    Accessible.role: Accessible.Button
                    color: selected ? Config.alpha(Config.md3.primary, Config.lightTheme ? 0.08 : 0.12) : dayMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.035) : "transparent"
                    height: monthGrid.height / 6
                    width: monthGrid.width / 7

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(100)
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        color: Config.alpha(Config.md3.on_surface, 0.065)
                        height: 1
                        width: parent.width
                    }
                    Rectangle {
                        anchors.right: parent.right
                        color: Config.alpha(Config.md3.on_surface, 0.065)
                        height: parent.height
                        width: 1
                    }
                    MouseArea {
                        id: dayMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.daySelected(dayCell.modelData.date)
                        onDoubleClicked: {
                            var position = dayCell.mapToItem(root, 0, 0);
                            root.createRequested(dayCell.modelData.date, {
                                "x": position.x,
                                "y": position.y,
                                "width": dayCell.width,
                                "height": dayCell.height
                            });
                        }
                    }
                    Rectangle {
                        id: dateBadge

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 5
                        color: dayCell.today ? Config.md3.primary : dayCell.selected ? Config.alpha(Config.md3.primary, 0.16) : "transparent"
                        height: 28
                        radius: 14
                        width: 28

                        Text {
                            anchors.centerIn: parent
                            color: dayCell.today ? Config.md3.on_primary : dayCell.modelData.inMonth ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.34)
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: dayCell.today || dayCell.selected ? Font.Bold : Font.Medium
                            text: dayCell.modelData.date.getDate()
                        }
                    }
                    Column {
                        id: eventColumn

                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.top: dateBadge.bottom
                        anchors.topMargin: 3
                        spacing: 2

                        Repeater {
                            model: dayCell.visibleEvents

                            Rectangle {
                                id: eventChip

                                readonly property color accentColor: root.eventColor(modelData)
                                required property int index
                                required property var modelData

                                color: eventMouse.containsMouse ? Config.alpha(accentColor, Config.lightTheme ? 0.28 : 0.4) : Config.alpha(accentColor, Config.lightTheme ? 0.18 : 0.28)
                                height: 23
                                radius: 7
                                width: eventColumn.width

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animationDuration(100)
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    color: eventChip.accentColor
                                    radius: 2
                                    width: 3
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 7
                                    anchors.rightMargin: 5
                                    spacing: 5

                                    Text {
                                        color: Config.alpha(Config.md3.on_surface, 0.7)
                                        font.family: Config.fontName
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        text: root.formatEventTime(eventChip.modelData)
                                        visible: text !== "" && eventChip.width >= 125
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        text: eventChip.modelData.title || qsTr("Untitled event")
                                    }
                                }
                                MouseArea {
                                    id: eventMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: {
                                        var position = eventChip.mapToItem(root, 0, 0);
                                        root.eventClicked(eventChip.modelData, {
                                            "x": position.x,
                                            "y": position.y,
                                            "width": eventChip.width,
                                            "height": eventChip.height
                                        });
                                    }
                                }
                            }
                        }
                        Rectangle {
                            color: moreMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.065) : "transparent"
                            height: dayCell.extraEventCount > 0 ? 20 : 0
                            radius: 6
                            visible: dayCell.extraEventCount > 0
                            width: eventColumn.width

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 7
                                anchors.verticalCenter: parent.verticalCenter
                                color: Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                text: qsTr("+%1 more").arg(dayCell.extraEventCount)
                            }
                            MouseArea {
                                id: moreMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: root.weekRequested(dayCell.modelData.date)
                            }
                        }
                    }
                }
            }
        }
    }
    Item {
        anchors.fill: parent
        visible: !root.available
        z: 20

        Rectangle {
            anchors.fill: parent
            color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.78 : 0.64)
            radius: 22
        }
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: Math.min(360, parent.width - 48)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.alpha(Config.md3.primary, 0.14)
                height: 58
                radius: 19
                width: 58

                CalendarProviderIcon {
                    anchors.centerIn: parent
                    height: 29
                    provider: "google"
                    tint: Config.md3.primary
                    width: 29
                }
            }
            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 20
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Connect a calendar account")
                width: parent.width
            }
            Text {
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Add Google, Microsoft 365, or iCloud from the sidebar. Every event appears in this shared calendar.")
                width: parent.width
                wrapMode: Text.Wrap
            }
        }
    }
    Item {
        anchors.fill: parent
        visible: root.available && root.loading && root.events.length === 0
        z: 21

        Rectangle {
            anchors.fill: parent
            color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.66 : 0.5)
            radius: 22
        }
        LoadingIndicator {
            anchors.centerIn: parent
            height: 52
            width: 52
        }
    }
}
