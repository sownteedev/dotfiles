import "../../"
import "../../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    readonly property real allDayLaneHeight: allDayMaxCount > 0 ? 12 + Math.min(2, allDayMaxCount) * 31 + (allDayMaxCount > 2 ? 16 : 0) : 0
    readonly property int allDayMaxCount: maximumAllDayCount()
    readonly property var allDaySegments: buildAllDaySegments()
    property bool available: false
    readonly property int currentDayIndex: dayDifference(weekStart, now)
    readonly property real dayWidth: Math.max(0, (timelineFlickable.width - timeGutterWidth) / 7)
    property var events: []
    property var hiddenCalendars: ({})
    readonly property real hourHeight: 72
    property int hoverDayIndex: -1
    property int hoverMinutes: -1
    property bool loading: false
    property date now: new Date()
    property date selectedDate: new Date()
    property bool selectionActive: false
    property int selectionAnchorMinutes: -1
    property bool selectionCommitted: false
    property int selectionCurrentMinutes: -1
    property int selectionDayIndex: -1
    property bool selectionDragged: false
    readonly property int selectionEndMinutes: selectionAnchorMinutes < 0 || selectionCurrentMinutes < 0 ? -1 : Math.max(selectionAnchorMinutes, selectionCurrentMinutes)
    property real selectionPressY: 0
    readonly property int selectionStartMinutes: selectionAnchorMinutes < 0 || selectionCurrentMinutes < 0 ? -1 : Math.min(selectionAnchorMinutes, selectionCurrentMinutes)
    readonly property bool selectionVisible: selectionDayIndex >= 0 && selectionStartMinutes >= 0 && selectionEndMinutes > selectionStartMinutes
    readonly property real timeGutterWidth: width < 860 ? 54 : 66
    readonly property var timedSegments: buildTimedSegments()
    property date weekStart: new Date()

    signal daySelected(var value)
    signal eventClicked(var eventData, var anchorRect)
    signal rangeSelected(var value, int startMinutes, int endMinutes, var anchorRect)

    function addDays(value, amount) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + amount);
    }
    function allDayForDay(dayIndex) {
        var result = [];
        for (var i = 0; i < allDaySegments.length; ++i) {
            if (allDaySegments[i].dayIndex === dayIndex)
                result.push(allDaySegments[i]);
        }
        return result;
    }
    function buildAllDaySegments() {
        var result = [];
        var source = events || [];
        var rangeStart = startOfDay(weekStart);
        var rangeEnd = addDays(rangeStart, 7);

        for (var i = 0; i < source.length; ++i) {
            var eventData = source[i];
            if (!eventData || !eventData.allDay || isCalendarHidden(eventData.calendarId))
                continue;

            var eventStart = parseDateOnly(eventData.start);
            var eventEnd = parseDateOnly(eventData.end);
            if (isNaN(eventStart.getTime()))
                continue;
            if (isNaN(eventEnd.getTime()) || eventEnd <= eventStart)
                eventEnd = addDays(eventStart, 1);
            if (eventStart >= rangeEnd || eventEnd <= rangeStart)
                continue;

            for (var day = 0; day < 7; ++day) {
                var dayStart = addDays(rangeStart, day);
                var dayEnd = addDays(dayStart, 1);
                if (eventStart < dayEnd && eventEnd > dayStart) {
                    result.push({
                        "dayIndex": day,
                        "eventData": eventData
                    });
                }
            }
        }
        return result;
    }
    function buildTimedSegments() {
        var result = [];
        var source = events || [];
        var rangeStart = startOfDay(weekStart);
        var rangeEnd = addDays(rangeStart, 7);

        for (var i = 0; i < source.length; ++i) {
            var eventData = source[i];
            if (!eventData || eventData.allDay || isCalendarHidden(eventData.calendarId))
                continue;

            var eventStart = new Date(eventData.start);
            var eventEnd = new Date(eventData.end);
            if (isNaN(eventStart.getTime()))
                continue;
            if (isNaN(eventEnd.getTime()) || eventEnd <= eventStart)
                eventEnd = new Date(eventStart.getTime() + 60 * 60000);
            if (eventStart >= rangeEnd || eventEnd <= rangeStart)
                continue;

            for (var day = 0; day < 7; ++day) {
                var dayStart = addDays(rangeStart, day);
                var dayEnd = addDays(dayStart, 1);
                if (eventStart >= dayEnd || eventEnd <= dayStart)
                    continue;

                var clippedStart = eventStart > dayStart ? eventStart : dayStart;
                var clippedEnd = eventEnd < dayEnd ? eventEnd : dayEnd;
                var startMinutes = (clippedStart.getTime() - dayStart.getTime()) / 60000;
                var endMinutes = (clippedEnd.getTime() - dayStart.getTime()) / 60000;
                result.push({
                    "dayIndex": day,
                    "durationMinutes": Math.max(15, endMinutes - startMinutes),
                    "endMinutes": endMinutes,
                    "eventData": eventData,
                    "lane": 0,
                    "laneCount": 1,
                    "startMinutes": startMinutes
                });
            }
        }

        result.sort(function (first, second) {
            if (first.dayIndex !== second.dayIndex)
                return first.dayIndex - second.dayIndex;
            if (first.startMinutes !== second.startMinutes)
                return first.startMinutes - second.startMinutes;
            return second.durationMinutes - first.durationMinutes;
        });
        return layoutOverlaps(result);
    }
    function clearSelection() {
        selectionActive = false;
        selectionCommitted = false;
        selectionDayIndex = -1;
        selectionAnchorMinutes = -1;
        selectionCurrentMinutes = -1;
        selectionDragged = false;
    }
    function dayDifference(first, second) {
        var firstUtc = Date.UTC(first.getFullYear(), first.getMonth(), first.getDate());
        var secondUtc = Date.UTC(second.getFullYear(), second.getMonth(), second.getDate());
        return Math.round((secondUtc - firstUtc) / 86400000);
    }
    function eventColor(eventData) {
        var candidate = eventData && eventData.calendarColor ? String(eventData.calendarColor) : "";
        return candidate !== "" ? candidate : Config.md3.primary;
    }
    function finishCluster(cluster, laneCount, destination) {
        var widthCount = Math.max(1, laneCount);
        for (var i = 0; i < cluster.length; ++i) {
            cluster[i].laneCount = widthCount;
            destination.push(cluster[i]);
        }
    }
    function formatEventTime(eventData) {
        if (!eventData || eventData.allDay)
            return qsTr("All day");
        var start = new Date(eventData.start);
        var end = new Date(eventData.end);
        if (isNaN(start.getTime()))
            return "";
        var startText = Qt.formatTime(start, "HH:mm");
        if (isNaN(end.getTime()))
            return startText;
        return startText + "–" + Qt.formatTime(end, "HH:mm");
    }
    function formatMinutes(value) {
        var minutes = Math.max(0, Math.min(23 * 60 + 59, Number(value || 0)));
        return String(Math.floor(minutes / 60)).padStart(2, "0") + ":" + String(minutes % 60).padStart(2, "0");
    }
    function isCalendarHidden(calendarId) {
        return Boolean(hiddenCalendars && hiddenCalendars[String(calendarId || "")]);
    }
    function isSameDay(first, second) {
        return first.getDate() === second.getDate() && first.getMonth() === second.getMonth() && first.getFullYear() === second.getFullYear();
    }
    function layoutOverlaps(segments) {
        var laidOut = [];
        for (var day = 0; day < 7; ++day) {
            var daySegments = [];
            for (var i = 0; i < segments.length; ++i) {
                if (segments[i].dayIndex === day)
                    daySegments.push(segments[i]);
            }

            var cluster = [];
            var clusterEnd = -1;
            var laneEnds = [];
            for (var j = 0; j < daySegments.length; ++j) {
                var segment = daySegments[j];
                if (cluster.length > 0 && segment.startMinutes >= clusterEnd) {
                    finishCluster(cluster, laneEnds.length, laidOut);
                    cluster = [];
                    clusterEnd = -1;
                    laneEnds = [];
                }

                var lane = 0;
                while (lane < laneEnds.length && laneEnds[lane] > segment.startMinutes)
                    ++lane;
                if (lane === laneEnds.length)
                    laneEnds.push(segment.endMinutes);
                else
                    laneEnds[lane] = segment.endMinutes;
                segment.lane = lane;
                cluster.push(segment);
                clusterEnd = Math.max(clusterEnd, segment.endMinutes);
            }
            finishCluster(cluster, laneEnds.length, laidOut);
        }
        return laidOut;
    }
    function maximumAllDayCount() {
        var maximum = 0;
        for (var day = 0; day < 7; ++day)
            maximum = Math.max(maximum, allDayForDay(day).length);
        return maximum;
    }
    function parseDateOnly(value) {
        var parts = String(value || "").slice(0, 10).split("-");
        if (parts.length !== 3)
            return new Date(NaN);
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }
    function scrollToWorkingHours() {
        timelineFlickable.contentY = Math.max(0, Math.min(timelineFlickable.contentHeight - timelineFlickable.height, hourHeight * 7 - 24));
    }
    function snappedMinutesForY(value, allowDayEnd) {
        var maximum = allowDayEnd ? 23 * 60 + 59 : 23 * 60 + 45;
        var snapped = Math.round((value / hourHeight * 60) / 15) * 15;
        return Math.max(0, Math.min(maximum, snapped));
    }
    function startOfDay(value) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate());
    }

    Component.onCompleted: Qt.callLater(scrollToWorkingHours)
    onWeekStartChanged: clearSelection()

    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true

        onTriggered: root.now = new Date()
    }
    Rectangle {
        anchors.fill: parent
        color: Config.alpha(Config.md3.surface_container_low, Config.lightTheme ? 0.72 : 0.34)
        radius: 22
    }
    Column {
        anchors.fill: parent

        Item {
            id: calendarHeader

            height: 76 + root.allDayLaneHeight
            width: parent.width

            Rectangle {
                anchors.fill: parent
                color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.62 : 0.18)
                topLeftRadius: 22
                topRightRadius: 22
            }
            Row {
                id: dayHeaderRow

                height: 76
                width: parent.width

                Item {
                    height: parent.height
                    width: root.timeGutterWidth

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Config.alpha(Config.md3.on_surface, 0.5)
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        text: Qt.formatDateTime(root.now, "t")
                    }
                }
                Repeater {
                    model: 7

                    Item {
                        id: dayHeader

                        required property int index
                        readonly property date value: root.addDays(root.weekStart, index)

                        height: dayHeaderRow.height
                        width: Math.max(0, (dayHeaderRow.width - root.timeGutterWidth) / 7)

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: dayHeader.index >= 5 ? Config.md3.tertiary : Config.md3.on_surface_variant
                                font.capitalization: Font.AllUppercase
                                font.family: Config.fontName
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                text: Qt.formatDate(dayHeader.value, "ddd")
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: root.isSameDay(dayHeader.value, root.now) ? Config.md3.primary : root.isSameDay(dayHeader.value, root.selectedDate) ? Config.alpha(Config.md3.primary, 0.14) : "transparent"
                                height: 36
                                radius: 18
                                width: 36

                                Text {
                                    anchors.centerIn: parent
                                    color: root.isSameDay(dayHeader.value, root.now) ? Config.md3.on_primary : Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 18
                                    font.weight: root.isSameDay(dayHeader.value, root.now) ? Font.Bold : Font.DemiBold
                                    text: dayHeader.value.getDate()
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.daySelected(dayHeader.value)
                        }
                    }
                }
            }
            Row {
                anchors.bottom: parent.bottom
                height: root.allDayLaneHeight
                visible: height > 0
                width: parent.width

                Item {
                    height: parent.height
                    width: root.timeGutterWidth

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        color: Config.alpha(Config.md3.on_surface, 0.5)
                        font.family: Config.fontName
                        font.pixelSize: 11
                        text: qsTr("all-day")
                    }
                }
                Repeater {
                    model: 7

                    Item {
                        id: allDayColumn

                        readonly property var dayEvents: root.allDayForDay(index)
                        required property int index

                        height: parent.height
                        width: Math.max(0, (calendarHeader.width - root.timeGutterWidth) / 7)

                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 3
                            anchors.rightMargin: 3
                            anchors.topMargin: 5
                            spacing: 3

                            Repeater {
                                model: allDayColumn.dayEvents.slice(0, 2)

                                Rectangle {
                                    id: allDayCard

                                    readonly property color accentColor: root.eventColor(modelData.eventData)
                                    required property var modelData

                                    color: allDayMouse.containsMouse ? Config.alpha(accentColor, Config.lightTheme ? 0.3 : 0.46) : Config.alpha(accentColor, Config.lightTheme ? 0.22 : 0.36)
                                    height: 28
                                    radius: 9
                                    width: parent.width

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        color: allDayCard.accentColor
                                        radius: 2
                                        width: 3
                                    }
                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 9
                                        anchors.rightMargin: 6
                                        color: Config.md3.on_surface
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        text: allDayCard.modelData.eventData.title || qsTr("Untitled event")
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    MouseArea {
                                        id: allDayMouse

                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true

                                        onClicked: {
                                            var position = allDayCard.mapToItem(root, 0, 0);
                                            root.clearSelection();
                                            root.eventClicked(allDayCard.modelData.eventData, {
                                                "x": position.x,
                                                "y": position.y,
                                                "width": allDayCard.width,
                                                "height": allDayCard.height
                                            });
                                        }
                                    }
                                }
                            }
                            Text {
                                color: Config.md3.primary
                                font.family: Config.fontName
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                text: qsTr("+%1 more").arg(allDayColumn.dayEvents.length - 2)
                                visible: allDayColumn.dayEvents.length > 2
                            }
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
        Flickable {
            id: timelineFlickable

            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: 24 * root.hourHeight + 28
            contentWidth: width
            height: parent.height - calendarHeader.height
            interactive: !root.selectionActive
            width: parent.width

            Item {
                id: timelineCanvas

                height: timelineFlickable.contentHeight
                width: timelineFlickable.width

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }
                MouseArea {
                    id: emptySlotMouse

                    acceptedButtons: Qt.LeftButton
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: root.selectionActive

                    onCanceled: {
                        if (!root.selectionCommitted)
                            root.clearSelection();
                        else
                            root.selectionActive = false;
                    }
                    onExited: {
                        if (!root.selectionActive) {
                            root.hoverDayIndex = -1;
                            root.hoverMinutes = -1;
                        }
                    }
                    onPositionChanged: mouse => {
                        if (!root.available)
                            return;

                        if (root.selectionActive) {
                            var distance = mouse.y - root.selectionPressY;
                            if (Math.abs(distance) >= 5)
                                root.selectionDragged = true;
                            if (!root.selectionDragged)
                                return;

                            var current = root.snappedMinutesForY(mouse.y, true);
                            if (current === root.selectionAnchorMinutes) {
                                current = distance < 0 ? Math.max(0, root.selectionAnchorMinutes - 15) : Math.min(23 * 60 + 59, root.selectionAnchorMinutes + 15);
                            }
                            root.selectionCurrentMinutes = current;
                            return;
                        }

                        if (mouse.x < root.timeGutterWidth) {
                            root.hoverDayIndex = -1;
                            root.hoverMinutes = -1;
                            return;
                        }

                        root.hoverDayIndex = Math.max(0, Math.min(6, Math.floor((mouse.x - root.timeGutterWidth) / root.dayWidth)));
                        root.hoverMinutes = root.snappedMinutesForY(mouse.y, false);
                    }
                    onPressed: mouse => {
                        if (!root.available || mouse.x < root.timeGutterWidth) {
                            mouse.accepted = false;
                            return;
                        }

                        root.selectionDayIndex = Math.max(0, Math.min(6, Math.floor((mouse.x - root.timeGutterWidth) / root.dayWidth)));
                        root.selectionAnchorMinutes = root.snappedMinutesForY(mouse.y, false);
                        root.selectionCurrentMinutes = Math.min(23 * 60 + 59, root.selectionAnchorMinutes + 60);
                        root.selectionPressY = mouse.y;
                        root.selectionDragged = false;
                        root.selectionCommitted = false;
                        root.selectionActive = true;
                        root.hoverDayIndex = -1;
                        root.hoverMinutes = -1;
                    }
                    onReleased: {
                        if (!root.selectionActive)
                            return;

                        if (!root.selectionDragged)
                            root.selectionCurrentMinutes = Math.min(23 * 60 + 59, root.selectionAnchorMinutes + 60);

                        var startMinutes = root.selectionStartMinutes;
                        var endMinutes = root.selectionEndMinutes;
                        if (endMinutes <= startMinutes) {
                            startMinutes = Math.max(0, Math.min(23 * 60 + 44, startMinutes));
                            endMinutes = Math.min(23 * 60 + 59, startMinutes + 15);
                        }

                        root.selectionActive = false;
                        root.selectionCommitted = true;
                        var selectionX = root.timeGutterWidth + root.selectionDayIndex * root.dayWidth + 3;
                        var selectionY = startMinutes / 60 * root.hourHeight;
                        var selectionHeight = Math.max(18, (endMinutes - startMinutes) / 60 * root.hourHeight);
                        var position = timelineCanvas.mapToItem(root, selectionX, selectionY);
                        root.rangeSelected(root.addDays(root.weekStart, root.selectionDayIndex), startMinutes, endMinutes, {
                            "x": position.x,
                            "y": position.y,
                            "width": Math.max(0, root.dayWidth - 6),
                            "height": selectionHeight
                        });
                    }
                }
                Rectangle {
                    color: Config.alpha(Config.md3.primary, 0.065)
                    height: root.hourHeight / 2
                    radius: 8
                    visible: !root.selectionVisible && root.hoverDayIndex >= 0 && root.hoverMinutes >= 0
                    width: Math.max(0, root.dayWidth - 6)
                    x: root.timeGutterWidth + root.hoverDayIndex * root.dayWidth + 3
                    y: root.hoverMinutes / 60 * root.hourHeight
                }
                Rectangle {
                    id: selectionCard

                    color: Config.alpha(Config.md3.primary, Config.lightTheme ? 0.32 : 0.5)
                    height: Math.max(18, (root.selectionEndMinutes - root.selectionStartMinutes) / 60 * root.hourHeight)
                    opacity: root.selectionVisible ? 1 : 0
                    radius: 11
                    visible: root.selectionVisible || opacity > 0
                    width: Math.max(0, root.dayWidth - 6)
                    x: root.timeGutterWidth + root.selectionDayIndex * root.dayWidth + 3
                    y: root.selectionStartMinutes / 60 * root.hourHeight
                    z: 7

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animationDuration(110)
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.top: parent.top
                        color: Config.md3.primary
                        radius: 2
                        width: 4
                    }
                    Column {
                        anchors.bottomMargin: 4
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 7
                        anchors.topMargin: selectionCard.height < 44 ? 4 : 7
                        spacing: 2

                        Text {
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: selectionCard.height < 46 ? 12 : 13
                            font.weight: Font.Bold
                            text: qsTr("Untitled event")
                            width: parent.width
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.7)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: root.formatMinutes(root.selectionStartMinutes) + "–" + root.formatMinutes(root.selectionEndMinutes)
                            visible: selectionCard.height >= 48
                            width: parent.width
                        }
                    }
                }
                Repeater {
                    model: 25

                    Item {
                        required property int index

                        height: 1
                        width: timelineCanvas.width
                        y: index * root.hourHeight

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: root.timeGutterWidth
                            color: Config.alpha(Config.md3.on_surface, index % 6 === 0 ? 0.1 : 0.065)
                            height: 1
                            width: parent.width - root.timeGutterWidth
                        }
                        Text {
                            anchors.right: parent.left
                            anchors.rightMargin: -(root.timeGutterWidth - 8)
                            anchors.verticalCenter: parent.verticalCenter
                            color: Config.alpha(Config.md3.on_surface, 0.52)
                            font.family: Config.fontName
                            font.pixelSize: 11
                            text: index > 0 && index < 24 ? String(index).padStart(2, "0") + ":00" : ""
                        }
                    }
                }
                Repeater {
                    model: 8

                    Rectangle {
                        required property int index

                        color: Config.alpha(Config.md3.on_surface, 0.065)
                        height: timelineCanvas.height
                        width: 1
                        x: root.timeGutterWidth + index * root.dayWidth
                    }
                }
                Rectangle {
                    color: Config.md3.error
                    height: 2
                    visible: root.currentDayIndex >= 0 && root.currentDayIndex < 7
                    width: root.dayWidth
                    x: root.timeGutterWidth + root.currentDayIndex * root.dayWidth
                    y: (root.now.getHours() * 60 + root.now.getMinutes()) / 60 * root.hourHeight
                    z: 9

                    Rectangle {
                        anchors.right: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: parent.color
                        height: 8
                        radius: 4
                        width: 8
                    }
                }
                Repeater {
                    model: root.timedSegments

                    Rectangle {
                        id: eventCard

                        readonly property color accentColor: root.eventColor(modelData.eventData)
                        readonly property real laneWidth: Math.max(18, (root.dayWidth - 7) / Math.max(1, modelData.laneCount))
                        required property var modelData

                        clip: true
                        color: eventMouse.containsMouse ? Config.alpha(accentColor, Config.lightTheme ? 0.32 : 0.52) : Config.alpha(accentColor, Config.lightTheme ? 0.24 : 0.42)
                        height: Math.max(28, modelData.durationMinutes / 60 * root.hourHeight - 3)
                        radius: 11
                        width: Math.max(16, laneWidth - 2)
                        x: root.timeGutterWidth + modelData.dayIndex * root.dayWidth + 4 + modelData.lane * laneWidth
                        y: modelData.startMinutes / 60 * root.hourHeight + 1
                        z: eventMouse.containsMouse ? 8 : 5

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(110)
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.top: parent.top
                            color: eventCard.accentColor
                            radius: 2
                            width: 4
                        }
                        Column {
                            anchors.bottomMargin: 5
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            anchors.topMargin: eventCard.height < 44 ? 4 : 7
                            spacing: 3

                            Text {
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: eventCard.height < 48 ? 12 : 14
                                font.weight: Font.Bold
                                maximumLineCount: eventCard.height >= 76 ? 2 : 1
                                text: eventCard.modelData.eventData.title || qsTr("Untitled event")
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                            Text {
                                color: Config.alpha(Config.md3.on_surface, 0.68)
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                text: root.formatEventTime(eventCard.modelData.eventData)
                                visible: eventCard.height >= 50
                                width: parent.width
                            }
                            Text {
                                color: Config.alpha(Config.md3.on_surface, 0.58)
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                text: eventCard.modelData.eventData.location || ""
                                visible: eventCard.height >= 84 && text !== ""
                                width: parent.width
                            }
                            Text {
                                color: Config.alpha(Config.md3.on_surface, 0.62)
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 12
                                maximumLineCount: 2
                                text: eventCard.modelData.eventData.description || ""
                                visible: eventCard.height >= 118 && text !== ""
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                        }
                        MouseArea {
                            id: eventMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                var position = eventCard.mapToItem(root, 0, 0);
                                root.clearSelection();
                                root.eventClicked(eventCard.modelData.eventData, {
                                    "x": position.x,
                                    "y": position.y,
                                    "width": eventCard.width,
                                    "height": eventCard.height
                                });
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

                IconImage {
                    anchors.centerIn: parent
                    height: 29
                    layer.enabled: true
                    source: Quickshell.iconPath("x-office-calendar-symbolic")
                    width: 29

                    layer.effect: ColorOverlay {
                        color: Config.md3.primary
                    }
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
                text: qsTr("Add Google, Microsoft 365, or iCloud from the sidebar. Every event appears in this shared timeline.")
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
