import "../../"
import "../../components"
import "../../service"
import "lunar.js" as Lunar
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    readonly property real allDayLaneHeight: allDayMaxCount > 0 ? 12 + Math.min(4, allDayMaxCount) * 31 : 0
    readonly property int allDayMaxCount: maximumAllDayCount()
    readonly property var allDaySegments: buildAllDaySegments(events)
    property bool available: false
    readonly property int currentDayIndex: dayDifference(weekStart, now)
    readonly property real dayWidth: Math.max(0, (timelineFlickable.width - timeGutterWidth) / 7)
    property var draggedCard: null
    readonly property bool eventDragging: draggedCard !== null
    property var events: []
    property var hiddenCalendars: ({})
    property real hourHeight: 56
    property int hoverDayIndex: -1
    property int hoverMinutes: -1
    property bool loading: false
    property bool moveBusy: false
    property date now: new Date()
    property date selectedDate: new Date()
    property bool selectionActive: false
    property int selectionAnchorMinutes: -1
    property bool selectionCommitted: false
    property int selectionCurrentDayIndex: -1
    property int selectionCurrentMinutes: -1
    readonly property int selectionDayCount: selectionStartDayIndex < 0 || selectionEndDayIndex < 0 ? 0 : selectionEndDayIndex - selectionStartDayIndex + 1
    property int selectionDayIndex: -1
    property bool selectionDragged: false
    property int selectionEdgeScrollDirection: 0
    readonly property real selectionEdgeScrollMargin: Math.min(64, Math.max(36, timelineFlickable.height * 0.12))
    readonly property int selectionEndDayIndex: selectionDayIndex < 0 || selectionCurrentDayIndex < 0 ? -1 : Math.max(selectionDayIndex, selectionCurrentDayIndex)
    readonly property int selectionEndMinutes: {
        if (selectionAnchorMinutes < 0 || selectionCurrentMinutes < 0)
            return -1;
        if (selectionDayIndex === selectionCurrentDayIndex)
            return Math.max(selectionAnchorMinutes, selectionCurrentMinutes);
        if (!selectionTimeDragged)
            return selectionCurrentMinutes;
        return selectionDayIndex < selectionCurrentDayIndex ? selectionCurrentMinutes : selectionAnchorMinutes;
    }
    property real selectionPointerViewportY: -1
    property real selectionPressY: 0
    readonly property int selectionStartDayIndex: selectionDayIndex < 0 || selectionCurrentDayIndex < 0 ? -1 : Math.min(selectionDayIndex, selectionCurrentDayIndex)
    readonly property int selectionStartMinutes: {
        if (selectionAnchorMinutes < 0 || selectionCurrentMinutes < 0)
            return -1;
        if (selectionDayIndex === selectionCurrentDayIndex)
            return Math.min(selectionAnchorMinutes, selectionCurrentMinutes);
        if (!selectionTimeDragged)
            return selectionAnchorMinutes;
        return selectionDayIndex < selectionCurrentDayIndex ? selectionAnchorMinutes : selectionCurrentMinutes;
    }
    property bool selectionTimeDragged: false
    readonly property bool selectionVisible: selectionStartDayIndex >= 0 && selectionStartMinutes >= 0 && selectionEndMinutes >= 0 && (selectionEndDayIndex > selectionStartDayIndex || selectionEndMinutes > selectionStartMinutes)
    readonly property real timeGutterWidth: width < 860 ? 54 : 66
    readonly property var timedSegments: buildTimedSegments()
    property date weekStart: new Date()

    signal daySelected(var value)
    signal eventClicked(var eventData, var anchorRect)
    signal eventMoveRequested(var eventData, int dayDelta, int minuteDelta)
    signal eventResizeRequested(var eventData, int startDeltaMinutes, int endDeltaMinutes)
    signal rangeSelected(var value, var endValue, int startMinutes, int endMinutes, var anchorRect)

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
    function appendTimedOccurrenceSegments(result, eventData, occurrenceStart, occurrenceEnd, rangeStart, rangeEnd) {
        if (occurrenceStart >= rangeEnd || occurrenceEnd <= rangeStart)
            return;

        for (var day = 0; day < 7; ++day) {
            var dayStart = addDays(rangeStart, day);
            var dayEnd = addDays(dayStart, 1);
            if (occurrenceStart >= dayEnd || occurrenceEnd <= dayStart)
                continue;

            var clippedStart = occurrenceStart > dayStart ? occurrenceStart : dayStart;
            var clippedEnd = occurrenceEnd < dayEnd ? occurrenceEnd : dayEnd;
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
    function buildAllDaySegments(sourceEvents) {
        var result = [];
        var source = sourceEvents || events || [];
        var rangeStart = startOfDay(weekStart);
        var rangeEnd = addDays(rangeStart, 7);

        for (var i = 0; i < source.length; ++i) {
            var eventData = source[i];
            if (!eventData || !eventData.allDay || isCalendarHidden(eventData.calendarId))
                continue;

            var type = CalendarService.eventRecurrenceType(eventData);
            if (type === "none") {
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
            } else {
                var durationDays = Math.max(1, Math.ceil((eventEnd.getTime() - eventStart.getTime()) / 86400000));
                for (var occurrenceOffset = -durationDays; occurrenceOffset < 7; ++occurrenceOffset) {
                    var occurrenceStart = addDays(rangeStart, occurrenceOffset);
                    if (!CalendarService.eventOccursOnDay(eventData, occurrenceStart))
                        continue;

                    var occurrenceEnd = addDays(occurrenceStart, durationDays);
                    for (var day = 0; day < 7; ++day) {
                        var dayStart = addDays(rangeStart, day);
                        var dayEnd = addDays(dayStart, 1);
                        if (occurrenceStart < dayEnd && occurrenceEnd > dayStart) {
                            result.push({
                                "dayIndex": day,
                                "eventData": eventData
                            });
                        }
                    }
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

            var type = CalendarService.eventRecurrenceType(eventData);
            if (type === "none") {
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
            } else {
                var durationMs = Math.max(15 * 60000, eventEnd.getTime() - eventStart.getTime());
                var durationDays = Math.max(1, Math.ceil(durationMs / 86400000));
                for (var occurrenceOffset = -durationDays; occurrenceOffset < 7; ++occurrenceOffset) {
                    var occurrenceDay = addDays(rangeStart, occurrenceOffset);
                    if (!CalendarService.eventOccursOnDay(eventData, occurrenceDay))
                        continue;

                    var occurrenceStart = new Date(occurrenceDay.getFullYear(), occurrenceDay.getMonth(), occurrenceDay.getDate(), eventStart.getHours(), eventStart.getMinutes(), eventStart.getSeconds(), eventStart.getMilliseconds());
                    appendTimedOccurrenceSegments(result, eventData, occurrenceStart, new Date(occurrenceStart.getTime() + durationMs), rangeStart, rangeEnd);
                }
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
    function cancelEventDrag() {
        if (draggedCard)
            draggedCard.resetDrag();
    }
    function clearSelection() {
        selectionActive = false;
        selectionCommitted = false;
        selectionCurrentDayIndex = -1;
        selectionDayIndex = -1;
        selectionAnchorMinutes = -1;
        selectionCurrentMinutes = -1;
        selectionDragged = false;
        selectionTimeDragged = false;
        selectionEdgeScrollDirection = 0;
        selectionPointerViewportY = -1;
        selectionPressY = 0;
    }
    function dayDifference(first, second) {
        var firstUtc = Date.UTC(first.getFullYear(), first.getMonth(), first.getDate());
        var secondUtc = Date.UTC(second.getFullYear(), second.getMonth(), second.getDate());
        return Math.round((secondUtc - firstUtc) / 86400000);
    }
    function dayIndexForX(value) {
        if (dayWidth <= 0)
            return -1;
        return Math.max(0, Math.min(6, Math.floor((value - timeGutterWidth) / dayWidth)));
    }
    function eventColor(eventData) {
        var candidate = eventData && eventData.calendarColor ? String(eventData.calendarColor) : "";
        return candidate !== "" ? candidate : Config.md3.primary;
    }
    function eventHasRecurrence(eventData) {
        if (!eventData || eventData.isTask === true)
            return false;
        var recurrence = eventData.recurrence;
        if (Array.isArray(recurrence))
            return recurrence.length > 0 && String(recurrence[0] || "").indexOf("FREQ=") >= 0;
        if (recurrence && typeof recurrence === "object")
            return Object.keys(recurrence).length > 0;
        return String(recurrence || "").indexOf("FREQ=") >= 0;
    }
    function eventIcon(eventData) {
        if (eventData && eventData.isTask === true)
            return "task_alt";
        if (eventHasRecurrence(eventData))
            return "repeat";
        return "event";
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
    function recurrenceShortLabel(eventData) {
        if (!eventData)
            return "";
        var recurrence = eventData.recurrence;
        var rule = "";
        var graphObj = null;

        if (Array.isArray(recurrence))
            rule = String(recurrence[0] || "");
        else if (recurrence && typeof recurrence === "object") {
            if (recurrence.pattern) {
                graphObj = recurrence;
            } else {
                var length = Number(recurrence.length);
                if (isFinite(length) && length > 0 && recurrence[0] !== undefined)
                    rule = String(recurrence[0]);
                else
                    rule = String(recurrence || "");
            }
        } else
            rule = String(recurrence || "");

        rule = rule.trim();
        if (!graphObj && rule.charAt(0) === "{") {
            try {
                graphObj = JSON.parse(rule);
            } catch (error) {}
        }

        var freq = "";
        var interval = 1;
        var byday = [];
        var count = 0;
        var untilStr = "";

        if (graphObj && graphObj.pattern) {
            var ptype = String(graphObj.pattern.type || "").toLowerCase();
            if (ptype === "daily")
                freq = "DAILY";
            else if (ptype === "weekly")
                freq = "WEEKLY";
            else if (ptype.indexOf("monthly") >= 0)
                freq = "MONTHLY";
            else if (ptype.indexOf("yearly") >= 0)
                freq = "YEARLY";

            if (graphObj.pattern.interval)
                interval = Math.max(1, Number(graphObj.pattern.interval));

            if (Array.isArray(graphObj.pattern.daysOfWeek)) {
                byday = graphObj.pattern.daysOfWeek.map(function (d) {
                    return String(d || "").slice(0, 2).toUpperCase();
                });
            }

            if (graphObj.range) {
                var rtype = String(graphObj.range.type || "");
                if (rtype === "numbered") {
                    count = Math.max(0, Number(graphObj.range.numberOfOccurrences || 0));
                } else if (rtype === "endDate") {
                    var ed = String(graphObj.range.endDate || "").replace(/-/g, "");
                    if (ed.length >= 8)
                        untilStr = ed.slice(6, 8) + "/" + ed.slice(4, 6) + "/" + ed.slice(0, 4);
                }
            }
        } else {
            var cleanRule = rule.replace(/^RRULE:/i, "");
            var freqMatch = cleanRule.match(/FREQ=([A-Z]+)/i);
            if (freqMatch)
                freq = freqMatch[1].toUpperCase();

            var intMatch = cleanRule.match(/INTERVAL=(\d+)/i);
            if (intMatch)
                interval = Math.max(1, Number(intMatch[1]));

            var bydayMatch = cleanRule.match(/BYDAY=([^;]+)/i);
            if (bydayMatch) {
                byday = bydayMatch[1].split(",").map(function (d) {
                    return d.trim().toUpperCase();
                }).filter(function (d) {
                    return d.length > 0;
                });
            }

            var countMatch = cleanRule.match(/COUNT=(\d+)/i);
            if (countMatch)
                count = Math.max(0, Number(countMatch[1]));

            var untilMatch = cleanRule.match(/UNTIL=(\d{4})(\d{2})(\d{2})/i);
            if (untilMatch)
                untilStr = untilMatch[3] + "/" + untilMatch[2] + "/" + untilMatch[1];
        }

        if (!freq)
            return "";

        var text = "";
        if (interval > 1) {
            var unitPlural = freq === "DAILY" ? qsTr("days") : freq === "WEEKLY" ? qsTr("weeks") : freq === "MONTHLY" ? qsTr("months") : qsTr("years");
            text = qsTr("Every %1 %2").arg(interval).arg(unitPlural);
        } else {
            text = freq === "DAILY" ? qsTr("Daily") : freq === "WEEKLY" ? qsTr("Weekly") : freq === "MONTHLY" ? qsTr("Monthly") : qsTr("Yearly");
        }

        if (byday.length > 1) {
            var dayNames = {
                "MO": qsTr("Mon"),
                "TU": qsTr("Tue"),
                "WE": qsTr("Wed"),
                "TH": qsTr("Thu"),
                "FR": qsTr("Fri"),
                "SA": qsTr("Sat"),
                "SU": qsTr("Sun")
            };
            var formattedDays = byday.map(function (d) {
                return dayNames[d] || d;
            }).join(", ");
            text += " (" + formattedDays + ")";
        }

        if (untilStr !== "")
            text += qsTr(" · until %1").arg(untilStr);
        else if (count > 0)
            text += qsTr(" · %1 times").arg(count);

        return text;
    }
    function scrollToWorkingHours() {
        if (!timelineFlickable || timelineFlickable.height <= 0 || timelineFlickable.contentHeight <= 0)
            return;
        var currentMinutes = root.now.getHours() * 60 + root.now.getMinutes();
        var currentTimeY = currentMinutes / 60 * root.hourHeight;
        var viewportAnchor = Math.max(96, Math.min(220, timelineFlickable.height * 0.34));
        var maximumContentY = Math.max(0, timelineFlickable.contentHeight - timelineFlickable.height);
        timelineFlickable.cancelFlick();
        timelineFlickable.contentY = Math.max(0, Math.min(maximumContentY, currentTimeY - viewportAnchor));
    }
    function snappedMinutesForY(value, allowDayEnd) {
        var maximum = allowDayEnd ? 23 * 60 + 59 : 23 * 60 + 45;
        var snapped = Math.round((value / hourHeight * 60) / 15) * 15;
        return Math.max(0, Math.min(maximum, snapped));
    }
    function startOfDay(value) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate());
    }
    function updateSelectionEdgeScroll(canvasY) {
        selectionPointerViewportY = canvasY - timelineFlickable.contentY;
        if (!selectionActive || !selectionDragged) {
            selectionEdgeScrollDirection = 0;
            return;
        }

        var maximumContentY = Math.max(0, timelineFlickable.contentHeight - timelineFlickable.height);
        if (selectionPointerViewportY <= selectionEdgeScrollMargin && timelineFlickable.contentY > 0)
            selectionEdgeScrollDirection = -1;
        else if (selectionPointerViewportY >= timelineFlickable.height - selectionEdgeScrollMargin && timelineFlickable.contentY < maximumContentY)
            selectionEdgeScrollDirection = 1;
        else
            selectionEdgeScrollDirection = 0;
    }
    function updateSelectionForX(canvasX) {
        var current = dayIndexForX(canvasX);
        if (current >= 0)
            selectionCurrentDayIndex = current;
    }
    function updateSelectionForY(canvasY) {
        selectionTimeDragged = true;
        var distance = canvasY - selectionPressY;
        var current = snappedMinutesForY(canvasY, true);
        if (selectionDayIndex === selectionCurrentDayIndex && current === selectionAnchorMinutes)
            current = distance < 0 ? Math.max(0, selectionAnchorMinutes - 15) : Math.min(23 * 60 + 59, selectionAnchorMinutes + 15);
        selectionCurrentMinutes = current;
    }

    Component.onCompleted: Qt.callLater(scrollToWorkingHours)
    onVisibleChanged: {
        if (!visible)
            cancelEventDrag();
    }
    onWeekStartChanged: {
        cancelEventDrag();
        clearSelection();
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true

        onTriggered: root.now = new Date()
    }
    Timer {
        interval: 16
        repeat: true
        running: root.visible && root.selectionActive && root.selectionDragged && root.selectionEdgeScrollDirection !== 0

        onTriggered: {
            var maximumContentY = Math.max(0, timelineFlickable.contentHeight - timelineFlickable.height);
            var edgeDepth = root.selectionEdgeScrollDirection < 0 ? (root.selectionEdgeScrollMargin - root.selectionPointerViewportY) / root.selectionEdgeScrollMargin : (root.selectionPointerViewportY - (timelineFlickable.height - root.selectionEdgeScrollMargin)) / root.selectionEdgeScrollMargin;
            edgeDepth = Math.max(0, Math.min(1, edgeDepth));
            var step = 2 + 6 * edgeDepth;
            var nextContentY = Math.max(0, Math.min(maximumContentY, timelineFlickable.contentY + root.selectionEdgeScrollDirection * step));
            if (nextContentY === timelineFlickable.contentY) {
                root.selectionEdgeScrollDirection = 0;
                return;
            }

            timelineFlickable.contentY = nextContentY;
            root.updateSelectionForY(nextContentY + root.selectionPointerViewportY);
        }
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
                        font.letterSpacing: Md3.typeScale.labelSmall.letterSpacing
                        font.pixelSize: Md3.typeScale.labelSmall.size
                        font.weight: 600
                        text: Qt.formatDateTime(root.now, "t")
                    }
                }
                Repeater {
                    model: 7

                    Item {
                        id: dayHeader

                        required property int index
                        readonly property var lunarDate: Lunar.getLunarDateForDate(dayHeader.value)
                        readonly property string lunarLabel: lunarDate ? (lunarDate.day === 1 ? `${lunarDate.day}/${lunarDate.month}` : String(lunarDate.day)) : ""
                        readonly property bool lunarSpecial: Boolean(lunarDate && (lunarDate.day === 1 || lunarDate.day === 15))
                        readonly property date value: root.addDays(root.weekStart, index)

                        Accessible.name: qsTr("%1, lunar %2").arg(Qt.formatDate(dayHeader.value, Qt.DefaultLocaleLongDate)).arg(dayHeader.lunarLabel)
                        Accessible.role: Accessible.Button
                        height: dayHeaderRow.height
                        width: Math.max(0, (dayHeaderRow.width - root.timeGutterWidth) / 7)

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: dayHeader.index >= 5 ? Config.md3.tertiary : Config.md3.on_surface_variant
                                font.capitalization: Font.AllUppercase
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.labelMedium.letterSpacing
                                font.pixelSize: Md3.typeScale.labelMedium.size
                                font.weight: 600
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
                                    font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                    font.pixelSize: Md3.typeScale.titleMedium.size
                                    font.weight: root.isSameDay(dayHeader.value, root.now) ? 700 : 600
                                    text: dayHeader.value.getDate()
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: dayHeader.lunarSpecial ? Config.md3.tertiary : Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.labelSmall.letterSpacing
                                font.pixelSize: Math.max(10, Md3.typeScale.labelSmall.size - 1)
                                font.weight: dayHeader.lunarSpecial ? Font.DemiBold : Md3.typeScale.labelSmall.weight
                                text: dayHeader.lunarLabel
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
                        font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                        font.pixelSize: Md3.typeScale.bodySmall.size
                        font.weight: Md3.typeScale.bodySmall.weight
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

                        ListView {
                            id: allDayList

                            anchors.bottomMargin: 5
                            anchors.fill: parent
                            anchors.leftMargin: 3
                            anchors.rightMargin: 3
                            anchors.topMargin: 5
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            flickableDirection: Flickable.VerticalFlick
                            model: allDayColumn.dayEvents
                            reuseItems: true
                            spacing: 3

                            delegate: Rectangle {
                                id: allDayCard

                                readonly property color accentColor: root.eventColor(modelData.eventData)
                                readonly property bool isCompletedTask: allDayCard.modelData.eventData.isTask === true && allDayCard.modelData.eventData.status === "completed"
                                required property var modelData

                                color: allDayMouse.containsMouse ? Config.alpha(accentColor, Config.lightTheme ? (allDayCard.isCompletedTask ? 0.22 : 0.3) : (allDayCard.isCompletedTask ? 0.34 : 0.46)) : Config.alpha(accentColor, Config.lightTheme ? (allDayCard.isCompletedTask ? 0.14 : 0.22) : (allDayCard.isCompletedTask ? 0.24 : 0.36))
                                height: 28
                                radius: 9
                                width: allDayList.width

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
                                    anchors.leftMargin: allDayCard.modelData.eventData.isTask ? 30 : 9
                                    anchors.rightMargin: 6
                                    color: allDayCard.isCompletedTask ? Config.alpha(Config.md3.on_surface, 0.58) : Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                                    font.pixelSize: Md3.typeScale.bodySmall.size
                                    font.strikeout: allDayCard.isCompletedTask
                                    font.weight: allDayCard.isCompletedTask ? Font.Medium : Font.Bold
                                    text: allDayCard.modelData.eventData.title || qsTr("Untitled event")
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    border.color: allDayCard.accentColor
                                    border.width: 1.5
                                    color: allDayCard.isCompletedTask ? Config.alpha(allDayCard.accentColor, 0.18) : "transparent"
                                    height: 13
                                    radius: 6.5
                                    visible: allDayCard.modelData.eventData.isTask === true
                                    width: 13

                                    Md3Icon {
                                        anchors.centerIn: parent
                                        color: allDayCard.accentColor
                                        name: "checkmark-symbolic"
                                        size: 10
                                        visible: allDayCard.isCompletedTask
                                        weight: 700
                                    }
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
            interactive: !root.selectionActive && !root.eventDragging
            width: parent.width

            WheelHandler {
                acceptedModifiers: Qt.ControlModifier
                target: null

                onWheel: event => {
                    var delta = event.angleDelta.y || 0;
                    if (delta === 0)
                        return;
                    var step = delta > 0 ? 6 : -6;
                    root.hourHeight = Math.max(36, Math.min(112, root.hourHeight + step));
                    event.accepted = true;
                }
            }
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
                        root.selectionEdgeScrollDirection = 0;
                        root.selectionPointerViewportY = -1;
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
                            var verticalDistance = mouse.y - root.selectionPressY;
                            root.updateSelectionForX(mouse.x);
                            if (Math.abs(verticalDistance) >= 5)
                                root.selectionTimeDragged = true;
                            if (root.selectionTimeDragged || root.selectionCurrentDayIndex !== root.selectionDayIndex)
                                root.selectionDragged = true;
                            if (!root.selectionDragged) {
                                root.selectionEdgeScrollDirection = 0;
                                return;
                            }

                            if (root.selectionTimeDragged)
                                root.updateSelectionForY(mouse.y);
                            root.updateSelectionEdgeScroll(mouse.y);
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
                        if (!root.available || root.dayWidth <= 0 || mouse.x < root.timeGutterWidth) {
                            mouse.accepted = false;
                            return;
                        }

                        root.selectionDayIndex = root.dayIndexForX(mouse.x);
                        root.selectionCurrentDayIndex = root.selectionDayIndex;
                        root.selectionAnchorMinutes = root.snappedMinutesForY(mouse.y, false);
                        root.selectionCurrentMinutes = Math.min(23 * 60 + 59, root.selectionAnchorMinutes + 60);
                        root.selectionPressY = mouse.y;
                        root.selectionDragged = false;
                        root.selectionTimeDragged = false;
                        root.selectionCommitted = false;
                        root.selectionActive = true;
                        root.selectionEdgeScrollDirection = 0;
                        root.selectionPointerViewportY = mouse.y - timelineFlickable.contentY;
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
                        if (root.selectionStartDayIndex === root.selectionEndDayIndex && endMinutes <= startMinutes) {
                            startMinutes = Math.max(0, Math.min(23 * 60 + 44, startMinutes));
                            endMinutes = Math.min(23 * 60 + 59, startMinutes + 15);
                        }

                        root.selectionEdgeScrollDirection = 0;
                        root.selectionPointerViewportY = -1;
                        root.selectionActive = false;
                        root.selectionCommitted = true;
                        var startDayIndex = root.selectionStartDayIndex;
                        var endDayIndex = root.selectionEndDayIndex;
                        var anchorDayIndex = root.selectionCurrentDayIndex;
                        if (anchorDayIndex === endDayIndex && endMinutes === 0 && endDayIndex > startDayIndex)
                            --anchorDayIndex;
                        var segmentStartMinutes = anchorDayIndex === startDayIndex ? startMinutes : 0;
                        var segmentEndMinutes = anchorDayIndex === endDayIndex ? endMinutes : 24 * 60;
                        var selectionX = root.timeGutterWidth + anchorDayIndex * root.dayWidth + 3;
                        var selectionY = Math.max(segmentStartMinutes / 60 * root.hourHeight, timelineFlickable.contentY);
                        var selectionHeight = Math.max(18, Math.min(segmentEndMinutes / 60 * root.hourHeight, timelineFlickable.contentY + timelineFlickable.height) - selectionY);
                        var position = timelineCanvas.mapToItem(root, selectionX, selectionY);
                        root.rangeSelected(root.addDays(root.weekStart, startDayIndex), root.addDays(root.weekStart, endDayIndex), startMinutes, endMinutes, {
                            "x": position.x,
                            "y": position.y,
                            "width": Math.max(0, root.dayWidth - 6),
                            "height": selectionHeight
                        });
                    }
                    onWheel: wheel => {
                        if (wheel.modifiers & Qt.ControlModifier) {
                            var delta = wheel.angleDelta.y || 0;
                            var step = delta > 0 ? 6 : -6;
                            root.hourHeight = Math.max(36, Math.min(112, root.hourHeight + step));
                            wheel.accepted = true;
                        } else {
                            wheel.accepted = false;
                        }
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
                Item {
                    id: selectionCard

                    anchors.fill: parent
                    opacity: root.selectionVisible ? 1 : 0
                    visible: root.selectionVisible || opacity > 0
                    z: 7

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animationDuration(110)
                        }
                    }

                    Repeater {
                        model: root.selectionVisible ? root.selectionDayCount : 0

                        Rectangle {
                            id: selectionSegment

                            readonly property int dayIndex: root.selectionStartDayIndex + index
                            readonly property int endMinutes: lastSegment ? root.selectionEndMinutes : 24 * 60
                            readonly property bool firstSegment: dayIndex === root.selectionStartDayIndex
                            readonly property int horizontalInsetLeft: firstSegment ? 3 : 0
                            readonly property int horizontalInsetRight: lastSegment ? 3 : 0
                            required property int index
                            readonly property bool lastSegment: dayIndex === root.selectionEndDayIndex
                            readonly property int startMinutes: firstSegment ? root.selectionStartMinutes : 0

                            bottomLeftRadius: lastSegment ? 11 : 0
                            bottomRightRadius: lastSegment ? 11 : 0
                            color: Config.alpha(Config.md3.primary, Config.lightTheme ? 0.32 : 0.5)
                            height: Math.max(18, (endMinutes - startMinutes) / 60 * root.hourHeight)
                            topLeftRadius: firstSegment ? 11 : 0
                            topRightRadius: firstSegment ? 11 : 0
                            visible: endMinutes > startMinutes
                            width: Math.max(0, root.dayWidth - horizontalInsetLeft - horizontalInsetRight)
                            x: root.timeGutterWidth + dayIndex * root.dayWidth + horizontalInsetLeft
                            y: startMinutes / 60 * root.hourHeight

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.top: parent.top
                                bottomLeftRadius: selectionSegment.lastSegment ? 2 : 0
                                bottomRightRadius: bottomLeftRadius
                                color: Config.md3.primary
                                topLeftRadius: selectionSegment.firstSegment ? 2 : 0
                                topRightRadius: topLeftRadius
                                width: 4
                            }
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 7
                                anchors.top: parent.top
                                anchors.topMargin: selectionSegment.height < 44 ? 4 : 7
                                spacing: 2

                                Text {
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: selectionSegment.height < 46 ? Md3.typeScale.bodySmall.letterSpacing : Md3.typeScale.bodyMedium.letterSpacing
                                    font.pixelSize: selectionSegment.height < 46 ? Md3.typeScale.bodySmall.size : Md3.typeScale.bodyMedium.size
                                    font.weight: 600
                                    text: qsTr("Untitled event")
                                    visible: selectionSegment.firstSegment
                                    width: parent.width
                                }
                                Text {
                                    color: Config.alpha(Config.md3.on_surface, 0.7)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                                    font.pixelSize: Md3.typeScale.bodySmall.size
                                    font.weight: 600
                                    text: root.formatMinutes(selectionSegment.startMinutes) + "–" + (selectionSegment.endMinutes === 24 * 60 ? "24:00" : root.formatMinutes(selectionSegment.endMinutes))
                                    visible: selectionSegment.firstSegment && selectionSegment.height >= 48
                                    width: parent.width
                                }
                            }
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
                        Rectangle {
                            color: Config.md3.outline_variant
                            height: 1
                            width: 8
                            x: root.timeGutterWidth - width
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.labelSmall.letterSpacing
                            font.pixelSize: Md3.typeScale.labelSmall.size
                            font.weight: Md3.typeScale.labelSmall.weight
                            horizontalAlignment: Text.AlignRight
                            text: index > 0 && index < 24 ? Qt.formatTime(new Date(2000, 0, 1, index), "h AP") : ""
                            width: root.timeGutterWidth - 20
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
                        readonly property real baseHeight: Math.max(28, modelData.durationMinutes / 60 * root.hourHeight - 3)
                        readonly property bool canMove: !root.loading && !root.moveBusy && modelData.eventData && modelData.eventData.isTask !== true && modelData.eventData.readOnly !== true && CalendarService.eventRecurrenceType(modelData.eventData) === "none"
                        property string dragMode: "none"
                        property bool dragMoved: false
                        property real dragOffsetX: 0
                        property real dragOffsetY: 0
                        readonly property bool dragging: root.draggedCard === eventCard
                        property string hoverResizeEdge: "none"
                        readonly property real laneWidth: Math.max(18, (root.dayWidth - 7) / Math.max(1, modelData.laneCount))
                        required property var modelData
                        property real pressCanvasX: 0
                        property real pressCanvasY: 0
                        property int resizeDeltaMinutes: 0

                        function resetDrag() {
                            if (dragging)
                                root.draggedCard = null;
                            dragOffsetX = 0;
                            dragOffsetY = 0;
                            dragMode = "none";
                            resizeDeltaMinutes = 0;
                        }
                        function resizeEdgeAt(localY) {
                            var edgeSize = Math.min(18, Math.max(10, height * 0.24));
                            if (localY <= edgeSize)
                                return "start";
                            if (localY >= height - edgeSize)
                                return "end";
                            return "none";
                        }

                        clip: true
                        color: eventMouse.containsMouse ? Config.alpha(accentColor, Config.lightTheme ? 0.32 : 0.52) : Config.alpha(accentColor, Config.lightTheme ? 0.24 : 0.42)
                        height: baseHeight + (dragMode === "end" ? resizeDeltaMinutes / 60 * root.hourHeight : dragMode === "start" ? -resizeDeltaMinutes / 60 * root.hourHeight : 0)
                        radius: 11
                        width: Math.max(16, laneWidth - 2)
                        x: root.timeGutterWidth + modelData.dayIndex * root.dayWidth + 4 + modelData.lane * laneWidth
                        y: modelData.startMinutes / 60 * root.hourHeight + 1 + (dragMode === "start" ? resizeDeltaMinutes / 60 * root.hourHeight : 0)
                        z: dragging ? 12 : eventMouse.containsMouse ? 8 : 5

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(110)
                            }
                        }
                        Behavior on dragOffsetX {
                            enabled: !eventCard.dragging

                            NumberAnimation {
                                duration: Config.animationDuration(150)
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on dragOffsetY {
                            enabled: !eventCard.dragging

                            NumberAnimation {
                                duration: Config.animationDuration(150)
                                easing.type: Easing.OutCubic
                            }
                        }
                        transform: Translate {
                            x: eventCard.dragOffsetX
                            y: eventCard.dragOffsetY
                        }

                        Component.onDestruction: {
                            if (dragging)
                                root.draggedCard = null;
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.top: parent.top
                            color: eventCard.accentColor
                            radius: 2
                            width: 4
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            color: Config.alpha(Config.md3.on_surface, 0.56)
                            height: 2
                            radius: 1
                            visible: eventCard.canMove && eventMouse.containsMouse
                            width: Math.min(42, parent.width * 0.55)
                            z: 3
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Config.alpha(Config.md3.on_surface, 0.56)
                            height: 2
                            radius: 1
                            visible: eventCard.canMove && eventMouse.containsMouse
                            width: Math.min(42, parent.width * 0.55)
                            z: 3
                        }
                        Column {
                            anchors.bottomMargin: 6
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            anchors.topMargin: eventCard.height < 44 ? 4 : (eventCard.height < 80 ? 6 : 9)
                            spacing: eventCard.height < 52 ? 2 : (eventCard.height < 80 ? 4 : 6)

                            Text {
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.letterSpacing: eventCard.height < 48 ? Md3.typeScale.bodyMedium.letterSpacing : Md3.typeScale.titleMedium.letterSpacing
                                font.pixelSize: eventCard.height < 48 ? Md3.typeScale.bodyMedium.size : 16
                                font.weight: Font.DemiBold
                                maximumLineCount: eventCard.height >= 76 ? 2 : 1
                                text: eventCard.modelData.eventData.title || qsTr("Untitled event")
                                width: parent.width
                                wrapMode: Text.Wrap
                            }
                            Row {
                                spacing: 7
                                visible: eventCard.height >= 46
                                width: parent.width

                                Md3Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Config.alpha(Config.md3.on_surface, 0.68)
                                    name: "schedule"
                                    size: 14
                                }
                                Text {
                                    color: Config.alpha(Config.md3.on_surface, 0.68)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                                    font.pixelSize: Md3.typeScale.bodyMedium.size
                                    font.weight: Font.Medium
                                    text: root.formatEventTime(eventCard.modelData.eventData)
                                    width: parent.width - 21
                                }
                            }
                            Row {
                                spacing: 7
                                visible: eventCard.height >= 68 && root.eventHasRecurrence(eventCard.modelData.eventData)
                                width: parent.width

                                Md3Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Config.alpha(Config.md3.on_surface, 0.58)
                                    name: "repeat"
                                    size: 14
                                }
                                Text {
                                    color: Config.alpha(Config.md3.on_surface, 0.58)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                                    font.pixelSize: Md3.typeScale.bodyMedium.size
                                    font.weight: Md3.typeScale.bodyMedium.weight
                                    text: root.recurrenceShortLabel(eventCard.modelData.eventData)
                                    width: parent.width - 21
                                }
                            }
                            Row {
                                spacing: 7
                                visible: eventCard.height >= 84 && (eventCard.modelData.eventData.location || "") !== ""
                                width: parent.width

                                Md3Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Config.alpha(Config.md3.on_surface, 0.58)
                                    name: "place"
                                    size: 14
                                }
                                Text {
                                    color: Config.alpha(Config.md3.on_surface, 0.58)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                                    font.pixelSize: Md3.typeScale.bodyMedium.size
                                    font.weight: Md3.typeScale.bodyMedium.weight
                                    text: eventCard.modelData.eventData.location || ""
                                    width: parent.width - 21
                                }
                            }
                            Row {
                                spacing: 7
                                visible: eventCard.height >= 118 && (eventCard.modelData.eventData.description || "") !== ""
                                width: parent.width

                                Md3Icon {
                                    anchors.top: parent.top
                                    anchors.topMargin: 2
                                    color: Config.alpha(Config.md3.on_surface, 0.62)
                                    name: "notes"
                                    size: 14
                                }
                                Text {
                                    color: Config.alpha(Config.md3.on_surface, 0.62)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                                    font.pixelSize: Md3.typeScale.bodyMedium.size
                                    font.weight: Md3.typeScale.bodyMedium.weight
                                    maximumLineCount: 2
                                    text: eventCard.modelData.eventData.description || ""
                                    width: parent.width - 21
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                        MouseArea {
                            id: eventMouse

                            acceptedButtons: Qt.LeftButton
                            anchors.fill: parent
                            cursorShape: !eventCard.canMove || !eventMouse.pressed ? Qt.PointingHandCursor : eventCard.dragMode === "move" ? Qt.SizeAllCursor : Qt.SizeVerCursor
                            enabled: !root.moveBusy
                            hoverEnabled: true
                            preventStealing: true

                            onCanceled: eventCard.resetDrag()
                            onClicked: {
                                if (eventCard.dragMoved) {
                                    eventCard.dragMoved = false;
                                    return;
                                }
                                var position = eventCard.mapToItem(root, 0, 0);
                                root.clearSelection();
                                root.eventClicked(eventCard.modelData.eventData, {
                                    "x": position.x,
                                    "y": position.y,
                                    "width": eventCard.width,
                                    "height": eventCard.height
                                });
                            }
                            onExited: {
                                if (!pressed)
                                    eventCard.hoverResizeEdge = "none";
                            }
                            onPositionChanged: mouse => {
                                if (!eventCard.canMove)
                                    return;
                                if (!pressed) {
                                    eventCard.hoverResizeEdge = eventCard.resizeEdgeAt(mouse.y);
                                    return;
                                }
                                var position = eventMouse.mapToItem(timelineCanvas, mouse.x, mouse.y);
                                var deltaX = position.x - eventCard.pressCanvasX;
                                var deltaY = position.y - eventCard.pressCanvasY;
                                var dragDistance = eventCard.dragMode === "move" ? Math.hypot(deltaX, deltaY) : Math.abs(deltaY);
                                if (!eventCard.dragMoved && dragDistance < Qt.styleHints.startDragDistance)
                                    return;
                                eventCard.dragMoved = true;
                                root.draggedCard = eventCard;
                                if (eventCard.dragMode !== "move") {
                                    var resizeDelta = Math.round((deltaY / Math.max(1, root.hourHeight) * 60) / 15) * 15;
                                    var minimumResizeDelta;
                                    var maximumResizeDelta;
                                    if (eventCard.dragMode === "start") {
                                        minimumResizeDelta = Math.ceil(-eventCard.modelData.startMinutes / 15) * 15;
                                        maximumResizeDelta = Math.floor((eventCard.modelData.durationMinutes - 15) / 15) * 15;
                                    } else {
                                        minimumResizeDelta = Math.ceil((15 - eventCard.modelData.durationMinutes) / 15) * 15;
                                        maximumResizeDelta = Math.floor((1440 - eventCard.modelData.endMinutes) / 15) * 15;
                                    }
                                    eventCard.resizeDeltaMinutes = Math.max(minimumResizeDelta, Math.min(maximumResizeDelta, resizeDelta));
                                    return;
                                }
                                var dayDelta = Math.max(-eventCard.modelData.dayIndex, Math.min(6 - eventCard.modelData.dayIndex, Math.round(deltaX / Math.max(1, root.dayWidth))));
                                var minuteDelta = Math.round((deltaY / Math.max(1, root.hourHeight) * 60) / 15) * 15;
                                var minimumDelta = Math.ceil(-eventCard.modelData.startMinutes / 15) * 15;
                                var maximumStart = 1440 - Math.max(15, Number(eventCard.modelData.durationMinutes || 15));
                                var maximumDelta = Math.floor((maximumStart - eventCard.modelData.startMinutes) / 15) * 15;
                                minuteDelta = Math.max(minimumDelta, Math.min(maximumDelta, minuteDelta));
                                eventCard.dragOffsetX = dayDelta * root.dayWidth;
                                eventCard.dragOffsetY = minuteDelta / 60 * root.hourHeight;
                            }
                            onPressed: mouse => {
                                eventCard.resetDrag();
                                eventCard.dragMoved = false;
                                eventCard.hoverResizeEdge = eventCard.resizeEdgeAt(mouse.y);
                                if (!eventCard.canMove)
                                    return;
                                var position = eventMouse.mapToItem(timelineCanvas, mouse.x, mouse.y);
                                eventCard.pressCanvasX = position.x;
                                eventCard.pressCanvasY = position.y;
                                eventCard.dragMode = eventCard.hoverResizeEdge === "none" ? "move" : eventCard.hoverResizeEdge;
                            }
                            onReleased: {
                                if (!eventCard.dragMoved)
                                    return;
                                var dragMode = eventCard.dragMode;
                                var dayDelta = Math.round(eventCard.dragOffsetX / Math.max(1, root.dayWidth));
                                var minuteDelta = Math.round(eventCard.dragOffsetY / Math.max(1, root.hourHeight) * 60 / 15) * 15;
                                var resizeDeltaMinutes = eventCard.resizeDeltaMinutes;
                                root.draggedCard = null;
                                if (dragMode === "move" && (dayDelta !== 0 || minuteDelta !== 0)) {
                                    root.eventMoveRequested(eventCard.modelData.eventData, dayDelta, minuteDelta);
                                } else if (dragMode === "start" && resizeDeltaMinutes !== 0) {
                                    root.eventResizeRequested(eventCard.modelData.eventData, resizeDeltaMinutes, 0);
                                } else if (dragMode === "end" && resizeDeltaMinutes !== 0) {
                                    root.eventResizeRequested(eventCard.modelData.eventData, 0, resizeDeltaMinutes);
                                }
                                eventCard.resetDrag();
                            }
                            onWheel: wheel => {
                                if (wheel.modifiers & Qt.ControlModifier) {
                                    var delta = wheel.angleDelta.y || 0;
                                    var step = delta > 0 ? 6 : -6;
                                    root.hourHeight = Math.max(36, Math.min(112, root.hourHeight + step));
                                    wheel.accepted = true;
                                } else {
                                    wheel.accepted = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Item {
        anchors.fill: parent
        visible: !root.available && !root.loading
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

                Md3Icon {
                    anchors.centerIn: parent
                    color: Config.md3.primary
                    filled: true
                    name: "x-office-calendar-symbolic"
                    size: 32
                }
            }
            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.titleLarge.letterSpacing
                font.pixelSize: Md3.typeScale.titleLarge.size
                font.weight: 600
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Connect a calendar account")
                width: parent.width
            }
            Text {
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                font.pixelSize: Md3.typeScale.bodyMedium.size
                font.weight: Md3.typeScale.bodyMedium.weight
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Add Google, Microsoft 365, or iCloud from the sidebar. Every event appears in this shared timeline.")
                width: parent.width
                wrapMode: Text.Wrap
            }
        }
    }
    CalendarLoadingState {
        anchors.fill: parent
        visible: root.loading && root.events.length === 0
        z: 21
    }
}
