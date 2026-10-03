import "../../"
import "../../components"
import "../../service"
import "lunar.js" as Lunar
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool allDay: false
    property var anchorRect: null
    property bool availabilityPopupOpen: false
    property real availabilityPopupY: 0
    property string availabilityType: "busy"
    property string calendarId: ""
    property bool calendarPopupOpen: false
    property real calendarPopupY: 0
    property string datePickerTarget: "start"
    property string description: ""
    property string endTime: "11:00"
    property date eventDate: new Date()
    property date eventEndDate: new Date()
    property string eventId: ""
    property bool eventReadOnly: false
    property string eventTitle: ""
    readonly property bool isNewTask: taskCreateMode && taskData === null
    readonly property bool isTask: taskData !== null || taskCreateMode
    property string location: ""
    property bool opened: false
    property bool recurrenceAdvancedPopupOpen: false
    property real recurrenceAdvancedPopupY: 0
    property int recurrenceCount: 1
    property bool recurrenceEndPopupOpen: false
    property string recurrenceEndType: "none"
    property int recurrenceInterval: 1
    property bool recurrencePopupOpen: false
    property real recurrencePopupY: 0
    property string recurrenceType: "none"
    property date recurrenceUntilDate: new Date()
    property var recurrenceWeekdays: []
    property int reminderMinutes: -1
    property bool reminderPopupOpen: false
    property real reminderPopupY: 0
    property bool reminderUserSelected: false
    property string startTime: "10:00"
    property string taskAccountId: ""
    property bool taskBusy: false
    property bool taskCreateMode: false
    property var taskData: null
    readonly property var taskDestinationOptions: buildTaskDestinationOptions()
    property bool taskDestinationPopupOpen: false
    property real taskDestinationPopupY: 0
    property string taskError: ""
    property string taskListId: ""
    readonly property var taskListOptions: buildTaskListOptions()
    property bool taskListPopupOpen: false
    property real taskListPopupY: 0
    property string taskSource: "local"
    property bool useDefaultReminder: false
    readonly property bool validTimeRange: {
        if (isTask)
            return true;
        if (allDay)
            return eventEndDate.getTime() >= eventDate.getTime();
        if (eventEndDate.getTime() > eventDate.getTime())
            return true;
        return eventEndDate.getTime() === eventDate.getTime() && minutesForTime(endTime) > minutesForTime(startTime);
    }
    property bool visibilityPopupOpen: false
    property real visibilityPopupY: 0
    property string visibilityType: "default"
    readonly property var writableCalendars: buildWritableCalendars()

    signal closed

    function applyCalendarDefaultReminder() {
        var calendar = CalendarService.calendarById(calendarId);
        if (calendar && calendar.provider === "google") {
            reminderMinutes = reminderMinutesFromEvent(calendar.defaultReminderMinutes);
            useDefaultReminder = false;
        } else {
            reminderMinutes = -1;
            useDefaultReminder = false;
        }
    }
    function availabilityLabel() {
        var options = availabilityOptions();
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].id) === availabilityType)
                return options[i].label;
        }
        return options[0].label;
    }
    function availabilityOptions() {
        return [
            {
                "id": "busy",
                "label": qsTr("Busy"),
                "description": qsTr("Show this time as unavailable")
            },
            {
                "id": "free",
                "label": qsTr("Free"),
                "description": qsTr("Keep this time available")
            }
        ];
    }
    function buildTaskDestinationOptions() {
        var options = [
            {
                "id": "local",
                "label": qsTr("Local tasks"),
                "source": "local",
                "accountId": "",
                "color": Config.md3.primary
            }
        ];
        var googleAccounts = GoogleService.accounts || [];
        for (var i = 0; i < googleAccounts.length; ++i) {
            var account = googleAccounts[i];
            options.push({
                "id": account.id,
                "label": account.email || account.displayName || qsTr("Google account"),
                "source": "google",
                "accountId": account.id,
                "color": CalendarService.taskAccountColor(account.id)
            });
        }
        return options;
    }
    function buildTaskListOptions() {
        if (taskSource !== "google" || !taskAccountId)
            return [];
        var lists = GoogleService.listsForAccount(taskAccountId) || [];
        var options = [];
        for (var i = 0; i < lists.length; ++i) {
            var list = lists[i];
            options.push({
                "id": list.id,
                "label": list.title || qsTr("Tasks"),
                "color": CalendarService.taskListColor(taskAccountId, list.id)
            });
        }
        return options;
    }
    function buildWritableCalendars() {
        var source = CalendarService.calendars || [];
        var result = [];
        for (var index = 0; index < source.length; ++index) {
            if (source[index] && source[index].readOnly !== true)
                result.push(source[index]);
        }
        return result;
    }
    function calendarColor() {
        if (isNewTask) {
            if (taskSource === "google") {
                if (taskListId)
                    return CalendarService.taskListColor(taskAccountId, taskListId);
                if (taskAccountId)
                    return CalendarService.taskAccountColor(taskAccountId);
            }
            return Config.md3.primary;
        }
        if (isTask)
            return taskData.calendarColor || Config.md3.primary;
        for (var i = 0; i < CalendarService.calendars.length; ++i) {
            if (String(CalendarService.calendars[i].id || "") === calendarId)
                return CalendarService.calendars[i].color || Config.md3.primary;
        }
        return Config.md3.primary;
    }
    function calendarName() {
        if (isNewTask) {
            if (taskSource === "google")
                return taskDestinationLabel() + (taskListId ? " · " + taskListLabel() : "");
            return qsTr("Local tasks");
        }
        if (isTask)
            return (taskData.taskListName || taskData.calendarName || qsTr("Tasks")) + " · " + (taskData.accountName || "");
        for (var i = 0; i < CalendarService.calendars.length; ++i) {
            if (String(CalendarService.calendars[i].id || "") === calendarId)
                return CalendarService.calendars[i].name || qsTr("Calendar");
        }
        return writableCalendars.length > 0 ? writableCalendars[0].name : qsTr("Calendar");
    }
    function changeTask(operation) {
        if (!isTask || taskBusy)
            return;
        taskError = "";
        var id = taskData.taskId;
        var nextStatus = operation === "complete" ? "completed" : operation === "reopen" ? "needsAction" : undefined;
        if (taskData.taskSource === "local") {
            if (operation === "delete")
                LocalTaskService.deleteTask(id);
            else
                LocalTaskService.updateTask(id, eventTitle.trim(), dateForApi(), description, nextStatus);
            close();
            return;
        }
        taskBusy = true;
        var done = function (ok, message) {
            root.taskBusy = false;
            if (ok)
                root.close();
            else
                root.taskError = message;
        };
        if (operation === "delete")
            GoogleService.deleteTask(taskData.taskListId, id, taskData.accountId, done);
        else
            GoogleService.updateTask(taskData.taskListId, id, eventTitle.trim(), dateForApi(), description, nextStatus, taskData.accountId, done);
    }
    function close() {
        if (taskBusy)
            return;
        if (modeSegment)
            modeSegment.animationsReady = false;
        calendarPopupOpen = false;
        recurrencePopupOpen = false;
        reminderPopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        recurrenceEndPopupOpen = false;
        availabilityPopupOpen = false;
        visibilityPopupOpen = false;
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        opened = false;
        closed();
    }
    function dateForApi() {
        return dateForValue(eventDate);
    }
    function dateForPicker() {
        return dateForPickerValue(eventDate);
    }
    function dateForPickerValue(value) {
        return String(value.getDate()).padStart(2, "0") + "/" + String(value.getMonth() + 1).padStart(2, "0") + "/" + value.getFullYear();
    }
    function dateForValue(value) {
        return value.getFullYear() + "-" + String(value.getMonth() + 1).padStart(2, "0") + "-" + String(value.getDate()).padStart(2, "0");
    }
    function defaultCalendarId() {
        for (var i = 0; i < writableCalendars.length; ++i) {
            if (writableCalendars[i].primary === true)
                return String(writableCalendars[i].id || "");
        }
        return writableCalendars.length > 0 ? String(writableCalendars[0].id || "") : "";
    }
    function deleteEvent() {
        if (eventId === "")
            return;

        if (isTask) {
            changeTask("delete");
            return;
        }
        CalendarService.deleteEvent(calendarId, eventId);
        close();
    }
    function ensureWeeklyWeekday() {
        if (recurrenceType === "weekly" && recurrenceWeekdays.length === 0)
            recurrenceWeekdays = [weekdayCodeForDate(eventDate)];
    }
    function formatTime(value) {
        return String(value.getHours()).padStart(2, "0") + ":" + String(value.getMinutes()).padStart(2, "0");
    }
    function horizontalPosition(cardWidth) {
        var margin = 16;
        if (!anchorRect)
            return Math.max(margin, Math.round((width - cardWidth) / 2));

        var rightPosition = Number(anchorRect.x || 0) + Number(anchorRect.width || 0) + 12;
        if (rightPosition + cardWidth <= width - margin)
            return rightPosition;

        var leftPosition = Number(anchorRect.x || 0) - cardWidth - 12;
        if (leftPosition >= margin)
            return leftPosition;

        return Math.max(margin, Math.min(width - cardWidth - margin, Math.round((width - cardWidth) / 2)));
    }
    function minutesForTime(value) {
        var parts = String(value || "").split(":");
        if (parts.length !== 2)
            return 0;

        return Number(parts[0]) * 60 + Number(parts[1]);
    }
    function openAvailabilityPopup(sourceItem) {
        if (!sourceItem)
            return;
        var position = sourceItem.mapToItem(root, 0, sourceItem.height + Md3.spacing.xs);
        availabilityPopupY = position.y;
        availabilityPopupOpen = true;
        visibilityPopupOpen = false;
        recurrencePopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        reminderPopupOpen = false;
    }
    function openDatePicker(target) {
        datePickerTarget = target;
        var value = target === "end" ? eventEndDate : target === "recurrenceUntil" ? recurrenceUntilDate : eventDate;
        datePicker.selectedDate = dateForPickerValue(value);
        datePicker.currentMonth = value.getMonth();
        datePicker.currentYear = value.getFullYear();
        datePicker.open();
    }
    function openEvent(eventData, editorAnchor) {
        if (!eventData || taskBusy)
            return;

        if (modeSegment)
            modeSegment.animationsReady = false;
        taskCreateMode = false;
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        calendarPopupOpen = false;
        recurrencePopupOpen = false;
        reminderPopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        recurrenceEndPopupOpen = false;
        availabilityPopupOpen = false;
        visibilityPopupOpen = false;
        taskData = eventData.isTask ? eventData : null;
        taskError = "";
        anchorRect = editorAnchor || null;
        eventId = String(eventData.id || "");
        eventReadOnly = eventData.readOnly === true;
        calendarId = String(eventData.calendarId || "");
        eventTitle = String(eventData.title || "");
        description = String(eventData.description || "");
        location = String(eventData.location || "");
        allDay = eventData.allDay === true;
        recurrenceType = recurrenceTypeFromEvent(eventData.recurrence);
        reminderMinutes = reminderMinutesFromEvent(eventData.reminderMinutes);
        useDefaultReminder = eventData.useDefaultReminder === true;
        reminderUserSelected = true;
        availabilityType = eventData.availability === "free" ? "free" : "busy";
        visibilityType = ["default", "public", "private"].indexOf(eventData.visibility) >= 0 ? eventData.visibility : "default";
        recurrenceInterval = recurrenceIntervalFromRule(eventData.recurrence);
        recurrenceWeekdays = recurrenceWeekdaysFromRule(eventData.recurrence);
        recurrenceEndType = recurrenceEndFromRule(eventData.recurrence);
        if (allDay) {
            eventDate = parseApiDate(eventData.start);
            var allDayEnd = parseApiDate(eventData.end);
            eventEndDate = new Date(allDayEnd.getFullYear(), allDayEnd.getMonth(), allDayEnd.getDate() - 1);
            startTime = "10:00";
            endTime = "11:00";
        } else {
            var start = new Date(eventData.start);
            var end = new Date(eventData.end);
            eventDate = isNaN(start.getTime()) ? new Date() : new Date(start.getFullYear(), start.getMonth(), start.getDate());
            eventEndDate = isNaN(end.getTime()) ? new Date(eventDate) : new Date(end.getFullYear(), end.getMonth(), end.getDate());
            startTime = isNaN(start.getTime()) ? "10:00" : formatTime(start);
            endTime = isNaN(end.getTime()) ? "11:00" : formatTime(end);
        }
        if (eventEndDate.getTime() < eventDate.getTime())
            eventEndDate = new Date(eventDate);
        ensureWeeklyWeekday();
        syncTextFields();
        formFlickable.contentY = 0;
        opened = true;
        Qt.callLater(function () {
            titleField.forceActiveFocus();
        });
    }
    function openNew(value, selectedStartMinutes, selectedEndMinutes, editorAnchor, selectedEndDate) {
        if (taskBusy)
            return;
        if (modeSegment)
            modeSegment.animationsReady = false;
        taskCreateMode = false;
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        calendarPopupOpen = false;
        recurrencePopupOpen = false;
        reminderPopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        recurrenceEndPopupOpen = false;
        availabilityPopupOpen = false;
        visibilityPopupOpen = false;
        taskData = null;
        taskError = "";
        anchorRect = editorAnchor || null;
        eventId = "";
        eventReadOnly = false;
        calendarId = defaultCalendarId();
        eventTitle = "";
        description = "";
        location = "";
        allDay = false;
        eventDate = value && !isNaN(value.getTime()) ? new Date(value.getFullYear(), value.getMonth(), value.getDate()) : new Date();
        eventEndDate = selectedEndDate && typeof selectedEndDate.getTime === "function" && !isNaN(selectedEndDate.getTime()) ? new Date(selectedEndDate.getFullYear(), selectedEndDate.getMonth(), selectedEndDate.getDate()) : new Date(eventDate);
        if (eventEndDate.getTime() < eventDate.getTime())
            eventEndDate = new Date(eventDate);
        recurrenceType = "none";
        reminderMinutes = -1;
        availabilityType = "busy";
        visibilityType = "default";
        recurrenceInterval = 1;
        recurrenceWeekdays = [];
        recurrenceEndType = "none";
        recurrenceCount = 1;
        useDefaultReminder = false;
        reminderUserSelected = false;
        applyCalendarDefaultReminder();
        recurrenceUntilDate = new Date(eventDate);
        var startMinutes = Math.max(0, Math.min(23 * 60 + 45, Number(selectedStartMinutes || 0)));
        var requestedEndMinutes = selectedEndMinutes === undefined || selectedEndMinutes === null ? startMinutes + 60 : Number(selectedEndMinutes);
        var minimumEndMinutes = eventEndDate.getTime() === eventDate.getTime() ? startMinutes + 1 : 0;
        var endMinutes = Math.max(minimumEndMinutes, Math.min(23 * 60 + 59, requestedEndMinutes));
        startTime = timeForMinutes(startMinutes);
        endTime = timeForMinutes(endMinutes);
        syncTextFields();
        formFlickable.contentY = 0;
        opened = true;
        Qt.callLater(function () {
            titleField.forceActiveFocus();
        });
    }
    function openNewTask(value) {
        if (taskBusy)
            return;
        useDefaultReminder = false;
        reminderUserSelected = false;
        if (modeSegment)
            modeSegment.animationsReady = false;
        calendarPopupOpen = false;
        recurrencePopupOpen = false;
        reminderPopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        recurrenceEndPopupOpen = false;
        availabilityPopupOpen = false;
        visibilityPopupOpen = false;
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        taskData = null;
        taskCreateMode = true;
        taskSource = "local";
        taskAccountId = "";
        taskListId = "";
        taskError = "";
        anchorRect = null;
        eventId = "";
        eventReadOnly = false;
        calendarId = "";
        eventTitle = "";
        description = "";
        location = "";
        allDay = true;
        eventDate = value && !isNaN(value.getTime()) ? new Date(value.getFullYear(), value.getMonth(), value.getDate()) : new Date();
        eventEndDate = new Date(eventDate);
        recurrenceType = "none";
        reminderMinutes = -1;
        startTime = "00:00";
        endTime = "23:59";
        syncTextFields();
        formFlickable.contentY = 0;
        opened = true;
        Qt.callLater(function () {
            titleField.forceActiveFocus();
        });
    }
    function openRecurrenceAdvancedPopup(sourceItem) {
        if (!sourceItem || recurrenceType === "none")
            return;
        ensureWeeklyWeekday();
        var position = sourceItem.mapToItem(root, 0, sourceItem.height + Md3.spacing.xs);
        recurrenceAdvancedPopupY = position.y;
        recurrencePopupOpen = false;
        reminderPopupOpen = false;
        availabilityPopupOpen = false;
        visibilityPopupOpen = false;
        recurrenceAdvancedPopupOpen = true;
        recurrenceEndPopupOpen = false;
    }
    function openRecurrencePopup(sourceItem) {
        if (!sourceItem)
            return;
        var position = sourceItem.mapToItem(root, 0, sourceItem.height + Md3.spacing.xs);
        recurrencePopupY = position.y;
        recurrencePopupOpen = true;
        reminderPopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        recurrenceEndPopupOpen = false;
        availabilityPopupOpen = false;
        visibilityPopupOpen = false;
    }
    function openReminderPopup(sourceItem) {
        if (!sourceItem)
            return;
        var position = sourceItem.mapToItem(root, 0, sourceItem.height + Md3.spacing.xs);
        reminderPopupY = position.y;
        reminderPopupOpen = true;
        recurrencePopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        availabilityPopupOpen = false;
        visibilityPopupOpen = false;
    }
    function openTaskDestinationPopup(sourceItem) {
        if (!sourceItem)
            return;
        var position = sourceItem.mapToItem(root, 0, sourceItem.height + Md3.spacing.xs);
        taskDestinationPopupY = position.y;
        taskDestinationPopupOpen = true;
        taskListPopupOpen = false;
        calendarPopupOpen = false;
    }
    function openTaskListPopup(sourceItem) {
        if (!sourceItem)
            return;
        var position = sourceItem.mapToItem(root, 0, sourceItem.height + Md3.spacing.xs);
        taskListPopupY = position.y;
        taskListPopupOpen = true;
        taskDestinationPopupOpen = false;
        calendarPopupOpen = false;
    }
    function openVisibilityPopup(sourceItem) {
        if (!sourceItem)
            return;
        var position = sourceItem.mapToItem(root, 0, sourceItem.height + Md3.spacing.xs);
        visibilityPopupY = position.y;
        visibilityPopupOpen = true;
        availabilityPopupOpen = false;
        recurrencePopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        reminderPopupOpen = false;
    }
    function parseApiDate(value) {
        var parts = String(value || "").slice(0, 10).split("-");
        if (parts.length !== 3)
            return new Date();

        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }
    function parsePickerDate(value) {
        var parts = String(value || "").split("/");
        if (parts.length !== 3)
            return eventDate;

        return new Date(Number(parts[2]), Number(parts[1]) - 1, Number(parts[0]));
    }
    function recurrenceAdvancedLabel() {
        if (recurrenceType === "none")
            return qsTr("Choose a repeat pattern first");
        var unit = recurrenceType === "daily" ? qsTr("day") : recurrenceType === "weekly" ? qsTr("week") : recurrenceType === "monthly" ? qsTr("month") : qsTr("year");
        var text = qsTr("Every %1 %2").arg(recurrenceInterval).arg(unit + (recurrenceInterval === 1 ? "" : "s"));
        if (recurrenceType === "monthly")
            text += qsTr(" · on day %1").arg(eventDate.getDate());
        if (recurrenceEndType === "count")
            text += qsTr(" · %1 times").arg(recurrenceCount);
        else if (recurrenceEndType === "until")
            text += qsTr(" · until %1").arg(dateForPickerValue(recurrenceUntilDate));
        return text;
    }
    function recurrenceEndFromRule(value) {
        var text = recurrenceRuleText(value);
        var count = text.match(/COUNT=(\d+)/i);
        if (count) {
            recurrenceCount = Math.max(1, Number(count[1]));
            return "count";
        }
        var until = text.match(/UNTIL=(\d{8})/i);
        if (until) {
            recurrenceUntilDate = new Date(Number(until[1].slice(0, 4)), Number(until[1].slice(4, 6)) - 1, Number(until[1].slice(6, 8)));
            return "until";
        }
        return "none";
    }
    function recurrenceEndOptions() {
        return [
            {
                "id": "none",
                "label": qsTr("Never")
            },
            {
                "id": "count",
                "label": qsTr("After a number of times")
            },
            {
                "id": "until",
                "label": qsTr("On a date")
            }
        ];
    }
    function recurrenceIntervalFromRule(value) {
        var match = recurrenceRuleText(value).match(/INTERVAL=(\d+)/i);
        return match ? Math.max(1, Number(match[1])) : 1;
    }
    function recurrenceLabel() {
        var options = recurrenceOptions();
        for (var i = 0; i < options.length; ++i) {
            if (options[i].id === recurrenceType)
                return options[i].label;
        }
        return options[0].label;
    }
    function recurrenceOptions() {
        return [
            {
                "id": "none",
                "label": qsTr("Does not repeat")
            },
            {
                "id": "daily",
                "label": qsTr("Daily")
            },
            {
                "id": "weekly",
                "label": qsTr("Weekly")
            },
            {
                "id": "monthly",
                "label": qsTr("Monthly")
            },
            {
                "id": "yearly",
                "label": qsTr("Yearly")
            },
            {
                "id": "advanced",
                "label": qsTr("Customize…")
            }
        ];
    }
    function recurrenceRule() {
        if (recurrenceType === "none")
            return [];
        var frequency = recurrenceType.toUpperCase();
        var rule = "RRULE:FREQ=" + frequency;
        if (recurrenceInterval > 1)
            rule += ";INTERVAL=" + Math.max(1, recurrenceInterval);
        if (recurrenceType === "weekly" && recurrenceWeekdays.length > 0)
            rule += ";BYDAY=" + recurrenceWeekdays.join(",");
        if (recurrenceType === "monthly")
            rule += ";BYMONTHDAY=" + eventDate.getDate();
        if (recurrenceEndType === "count")
            rule += ";COUNT=" + Math.max(1, recurrenceCount);
        else if (recurrenceEndType === "until")
            rule += ";UNTIL=" + dateForValue(recurrenceUntilDate).replace(/-/g, "") + "T235959Z";
        return [rule];
    }
    function recurrenceRuleText(value) {
        if (value === null || value === undefined)
            return "";
        if (typeof value === "string")
            return value;
        if (typeof value !== "object" || value.pattern)
            return "";

        // A JS array becomes a QQmlListProperty/QJSValue-like object when it
        // travels through a Repeater model.  In that case Array.isArray() is
        // false even though length and numeric indexes are still available.
        var length = Number(value.length);
        if (isFinite(length) && length > 0 && value[0] !== undefined)
            return String(value[0]);
        return value[0] === undefined ? "" : String(value[0]);
    }
    function recurrenceTypeFromEvent(value) {
        var first = recurrenceRuleText(value);
        if (value && typeof value === "object" && value.pattern) {
            var patternType = String(value.pattern.type || "");
            if (patternType === "daily")
                return "daily";
            if (patternType === "weekly")
                return "weekly";
            if (patternType === "absoluteMonthly" || patternType === "relativeMonthly")
                return "monthly";
            if (patternType === "absoluteYearly" || patternType === "relativeYearly")
                return "yearly";
        }
        first = first.trim();
        if (first.charAt(0) === "{") {
            try {
                var parsed = JSON.parse(first);
                var graphType = parsed.pattern ? parsed.pattern.type : "";
                if (graphType === "daily")
                    return "daily";
                if (graphType === "weekly")
                    return "weekly";
                if (graphType === "absoluteMonthly" || graphType === "relativeMonthly")
                    return "monthly";
                if (graphType === "absoluteYearly" || graphType === "relativeYearly")
                    return "yearly";
            } catch (error) {
                return "none";
            }
        }
        var normalized = first.toUpperCase().replace(/^RRULE:/, "");
        if (normalized.indexOf("FREQ=DAILY") >= 0)
            return "daily";
        if (normalized.indexOf("FREQ=WEEKLY") >= 0)
            return "weekly";
        if (normalized.indexOf("FREQ=MONTHLY") >= 0)
            return "monthly";
        if (normalized.indexOf("FREQ=YEARLY") >= 0)
            return "yearly";
        return "none";
    }
    function recurrenceWeekdaysFromRule(value) {
        var match = recurrenceRuleText(value).match(/BYDAY=([^;]+)/i);
        return match ? match[1].split(",") : [];
    }
    function reminderLabel() {
        if (reminderMinutes < 0)
            return qsTr("No reminder");
        var options = reminderOptions();
        for (var i = 0; i < options.length; ++i)
            if (options[i].minutes === reminderMinutes)
                return options[i].label;
        return qsTr("%1 minutes before").arg(reminderMinutes);
    }
    function reminderMinutesFromEvent(value) {
        if (value === null || value === undefined || value === "")
            return -1;
        var number = Number(value);
        return isFinite(number) && number >= 0 ? number : -1;
    }
    function reminderOptions() {
        var options = [
            {
                "id": "none",
                "minutes": -1,
                "label": qsTr("No reminder")
            },
            {
                "id": "start",
                "minutes": 0,
                "label": qsTr("At start time")
            },
            {
                "id": "5",
                "minutes": 5,
                "label": qsTr("5 minutes before")
            },
            {
                "id": "10",
                "minutes": 10,
                "label": qsTr("10 minutes before")
            },
            {
                "id": "15",
                "minutes": 15,
                "label": qsTr("15 minutes before")
            },
            {
                "id": "30",
                "minutes": 30,
                "label": qsTr("30 minutes before")
            },
            {
                "id": "60",
                "minutes": 60,
                "label": qsTr("1 hour before")
            },
            {
                "id": "1440",
                "minutes": 1440,
                "label": qsTr("1 day before")
            }
        ];
        return options;
    }
    function save() {
        if (isNewTask) {
            if (eventTitle.trim() === "")
                return;
            if (taskSource === "google" && (taskAccountId === "" || taskListId === "")) {
                taskError = qsTr("Please select a Google account and task list.");
                return;
            }
            taskBusy = true;
            taskError = "";
            var done = function (ok, message) {
                root.taskBusy = false;
                if (ok) {
                    root.close();
                } else {
                    root.taskError = message || qsTr("Could not save task.");
                }
            };
            if (taskSource === "local") {
                var newId = LocalTaskService.createTask(eventTitle.trim(), dateForApi(), description.trim());
                taskBusy = false;
                if (newId !== "")
                    close();
                else
                    taskError = qsTr("Could not create local task.");
            } else {
                GoogleService.createTask(taskListId, eventTitle.trim(), dateForApi(), description.trim(), taskAccountId, done);
            }
            return;
        }

        if (eventTitle.trim() === "" || !validTimeRange)
            return;

        if (isTask) {
            changeTask("update");
            return;
        }
        if (calendarId === "")
            calendarId = defaultCalendarId();

        if (eventId !== "")
            CalendarService.updateEvent(calendarId, eventId, eventTitle.trim(), eventDate, eventEndDate, startTime, endTime, allDay, location.trim(), description.trim(), recurrenceRule(), reminderMinutes, null, availabilityType, visibilityType, useDefaultReminder);
        else
            CalendarService.createEvent(calendarId, eventTitle.trim(), eventDate, eventEndDate, startTime, endTime, allDay, location.trim(), description.trim(), recurrenceRule(), reminderMinutes, null, availabilityType, visibilityType, useDefaultReminder);
        close();
    }
    function selectAvailability(item) {
        if (!item)
            return;
        availabilityType = String(item.id || "busy") === "free" ? "free" : "busy";
        availabilityPopupOpen = false;
    }
    function selectRecurrence(item) {
        if (!item)
            return;
        var selected = String(item.id || "none");
        if (selected === "advanced") {
            recurrencePopupOpen = false;
            Qt.callLater(function () {
                if (root.recurrenceType !== "none")
                    root.openRecurrenceAdvancedPopup(recurrenceAdvancedField);
            });
            return;
        }
        recurrenceType = selected;
        if (recurrenceType === "none")
            recurrenceAdvancedPopupOpen = false;
        else
            ensureWeeklyWeekday();
        recurrencePopupOpen = false;
        if (recurrenceType !== "none") {
            Qt.callLater(function () {
                if (root.opened && root.recurrenceType !== "none")
                    root.openRecurrenceAdvancedPopup(recurrenceAdvancedField);
            });
        }
    }
    function selectReminder(item) {
        if (!item)
            return;
        reminderMinutes = Number(item.minutes);
        useDefaultReminder = false;
        reminderUserSelected = true;
        reminderPopupOpen = false;
    }
    function selectTaskDestination(item) {
        if (!item)
            return;
        taskSource = item.source || "local";
        if (taskSource === "google") {
            taskAccountId = item.accountId || item.id || "";
            var lists = GoogleService.listsForAccount(taskAccountId) || [];
            if (lists.length > 0) {
                taskListId = lists[0].id;
            } else {
                taskListId = "";
                GoogleService.refreshTasks(taskAccountId);
            }
        } else {
            taskAccountId = "";
            taskListId = "";
        }
        taskDestinationPopupOpen = false;
        taskError = "";
    }
    function selectTaskList(item) {
        if (!item)
            return;
        taskListId = String(item.id || "");
        taskListPopupOpen = false;
        taskError = "";
    }
    function selectVisibility(item) {
        if (!item)
            return;
        var value = String(item.id || "default");
        visibilityType = ["default", "public", "private"].indexOf(value) >= 0 ? value : "default";
        visibilityPopupOpen = false;
    }
    function setEditorMode(mode) {
        if (taskBusy)
            return;
        calendarPopupOpen = false;
        recurrencePopupOpen = false;
        reminderPopupOpen = false;
        recurrenceAdvancedPopupOpen = false;
        availabilityPopupOpen = false;
        visibilityPopupOpen = false;
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        taskError = "";

        if (mode === "task") {
            taskCreateMode = true;
            taskData = null;
            allDay = true;
            recurrenceType = "none";
            reminderMinutes = -1;
            useDefaultReminder = false;
            reminderUserSelected = false;
            if (taskSource === "google") {
                if (!taskAccountId && GoogleService.accounts.length > 0)
                    taskAccountId = GoogleService.accounts[0].id;
                var lists = GoogleService.listsForAccount(taskAccountId);
                if (lists.length > 0 && !taskListId)
                    taskListId = lists[0].id;
            }
        } else {
            taskCreateMode = false;
            taskData = null;
            allDay = false;
            if (eventEndDate.getTime() < eventDate.getTime())
                eventEndDate = new Date(eventDate);
            if (!calendarId)
                calendarId = defaultCalendarId();
            applyCalendarDefaultReminder();
        }
    }
    function syncTextFields() {
        titleField.text = eventTitle;
        locationField.text = location;
        descriptionField.text = description;
    }
    function taskDestinationLabel() {
        if (taskSource === "local")
            return qsTr("Local tasks");
        for (var i = 0; i < taskDestinationOptions.length; ++i) {
            if (taskDestinationOptions[i].source === "google" && taskDestinationOptions[i].accountId === taskAccountId)
                return taskDestinationOptions[i].label;
        }
        return qsTr("Choose account");
    }
    function taskListLabel() {
        for (var i = 0; i < taskListOptions.length; ++i) {
            if (taskListOptions[i].id === taskListId)
                return taskListOptions[i].label;
        }
        return qsTr("Choose task list");
    }
    function timeForMinutes(value) {
        var minutes = Math.max(0, Math.min(23 * 60 + 59, Number(value || 0)));
        return String(Math.floor(minutes / 60)).padStart(2, "0") + ":" + String(minutes % 60).padStart(2, "0");
    }
    function toggleRecurrenceWeekday(day) {
        var next = recurrenceWeekdays.slice();
        var index = next.indexOf(day);
        if (index >= 0)
            next.splice(index, 1);
        else
            next.push(day);
        recurrenceWeekdays = next;
    }
    function verticalPosition(cardHeight) {
        var margin = 16;
        if (!anchorRect)
            return Math.max(margin, Math.round((height - cardHeight) / 2));

        var targetY = Number(anchorRect.y || 0) - 18;
        return Math.max(margin, Math.min(height - cardHeight - margin, targetY));
    }
    function visibilityLabel() {
        var options = visibilityOptions();
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].id) === visibilityType)
                return options[i].label;
        }
        return options[0].label;
    }
    function visibilityOptions() {
        return [
            {
                "id": "default",
                "label": qsTr("Default"),
                "description": qsTr("Use the calendar's default visibility")
            },
            {
                "id": "public",
                "label": qsTr("Public"),
                "description": qsTr("Anyone with access can see the details")
            },
            {
                "id": "private",
                "label": qsTr("Private"),
                "description": qsTr("Only you can see the details")
            }
        ];
    }
    function weekdayCodeForDate(value) {
        if (!value || isNaN(value.getTime()))
            return "MO";
        // JavaScript Date uses Sunday=0, while RRULE uses MO..SU.
        return ["SU", "MO", "TU", "WE", "TH", "FR", "SA"][value.getDay()];
    }

    enabled: opened
    opacity: opened ? 1 : 0
    visible: opened || opacity > 0
    z: 40

    Behavior on opacity {
        Md3NumberAnimation {
            role: opened ? "enter" : "exit"
        }
    }

    onOpenedChanged: {
        if (opened && eventId === "" && !isTask && !reminderUserSelected)
            Qt.callLater(applyCalendarDefaultReminder);
    }
    onTaskListOptionsChanged: {
        if (isNewTask && taskSource === "google") {
            if (taskListOptions.length > 0 && !taskListOptions.some(item => item.id === taskListId))
                taskListId = taskListOptions[0].id;
        }
    }

    Connections {
        function onCalendarsChanged() {
            if (root.opened && root.eventId === "" && !root.isTask && !root.reminderUserSelected)
                root.applyCalendarDefaultReminder();
        }

        target: CalendarService
    }
    WheelHandler {
        blocking: true
        target: null
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onClicked: root.close()
        onWheel: event => event.accepted = true
    }
    ShellShadow {
        active: root.opened
        componentShadow: true
        cornerRadius: editorCard.radius
        target: editorCard
    }
    Rectangle {
        id: editorCard

        border.color: Config.alpha(Config.md3.on_surface, 0.09)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.98 : 0.96)
        height: Math.min(Math.max(540, editorForm.implicitHeight + 162), Math.max(540, root.height - 48))
        radius: 24
        scale: root.opened ? 1 : 0.96
        transformOrigin: Item.Center
        width: Math.min(440, parent.width - 40)
        x: root.horizontalPosition(width)
        y: root.verticalPosition(height)

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
            hoverEnabled: true

            onWheel: event => event.accepted = true
        }
        RowLayout {
            id: editorHeader

            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 16
            height: 58
            spacing: 14

            Rectangle {
                Layout.preferredHeight: 46
                Layout.preferredWidth: 46
                color: Config.alpha(root.calendarColor(), 0.16)
                radius: 14

                Md3Icon {
                    anchors.centerIn: parent
                    color: root.calendarColor()
                    filled: true
                    name: root.isNewTask ? "checkbox-checked-symbolic" : (root.eventId !== "" ? "document-edit-symbolic" : "appointment-new-symbolic")
                    size: 24
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleLarge.letterSpacing
                    font.pixelSize: 20
                    font.weight: 600
                    text: root.isNewTask ? qsTr("New task") : (root.isTask ? qsTr("Edit task") : (root.eventId !== "" ? qsTr("Edit event") : qsTr("New event")))
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                    font.pixelSize: 13
                    font.weight: Font.Normal
                    text: root.eventDate.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                }
            }
            SettingsActionButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                iconName: "window-close-symbolic"
                iconOnly: true
                iconSize: 20
                text: qsTr("Close editor")

                onClicked: root.close()
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: editorHeader.bottom
            color: Config.alpha(Config.md3.on_surface, 0.07)
            height: 1
        }
        Flickable {
            id: formFlickable

            anchors.bottom: footerDivider.top
            anchors.bottomMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: editorHeader.bottom
            anchors.topMargin: 14
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: editorForm.implicitHeight + 16
            contentWidth: width
            enabled: !root.taskBusy
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            ColumnLayout {
                id: editorForm

                spacing: 12
                width: formFlickable.width

                SettingsSegmentedControl {
                    id: modeSegment

                    Layout.bottomMargin: visible ? 4 : 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 44 : 0
                    backgroundColor: Config.alpha(Config.md3.surface_container_highest, Config.lightTheme ? 0.70 : 0.46)
                    fontPixelSize: 15
                    options: [
                        {
                            "label": qsTr("Event"),
                            "value": "event"
                        },
                        {
                            "label": qsTr("Task"),
                            "value": "task"
                        }
                    ]
                    selectedValue: root.isTask ? "task" : "event"
                    visible: root.eventId === "" && root.taskData === null

                    onSelected: value => root.setEditorMode(value)
                }
                FormTextField {
                    id: titleField

                    Layout.fillWidth: true
                    inputFontPixelSize: 16
                    inputFontWeight: Font.DemiBold
                    label: root.isTask ? qsTr("Task title") : qsTr("Title")
                    labelFontPixelSize: 14
                    labelFontWeight: Font.DemiBold
                    placeholder: root.isTask ? qsTr("Add a task") : qsTr("Add a title")
                    placeholderFontPixelSize: 16
                    placeholderFontWeight: Font.DemiBold

                    onAccepted: root.save()
                    onTextChanged: root.eventTitle = text
                }
                SettingsSelectField {
                    id: taskDestinationField

                    Layout.fillWidth: true
                    label: qsTr("Save in")
                    labelFontPixelSize: 14
                    labelFontWeight: Font.DemiBold
                    valueBadgeColor: root.taskSource === "local" ? Config.md3.primary : CalendarService.taskAccountColor(root.taskAccountId)
                    valueFontPixelSize: 15
                    valueText: root.taskDestinationLabel()
                    visible: root.isNewTask

                    onClicked: sourceItem => root.openTaskDestinationPopup(sourceItem)
                }
                SettingsSelectField {
                    id: taskListField

                    Layout.fillWidth: true
                    label: qsTr("Task list")
                    labelFontPixelSize: 14
                    labelFontWeight: Font.DemiBold
                    placeholder: GoogleService.refreshingAccounts[root.taskAccountId] ? qsTr("Loading task lists…") : qsTr("Choose task list")
                    valueBadgeColor: CalendarService.taskListColor(root.taskAccountId, root.taskListId)
                    valueFontPixelSize: 15
                    valueText: root.taskListLabel()
                    visible: root.isNewTask && root.taskSource === "google"

                    onClicked: sourceItem => root.openTaskListPopup(sourceItem)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Md3.spacing.xs
                    visible: !root.isNewTask

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                        text: root.isTask ? qsTr("Task list") : qsTr("Calendar")
                    }
                    Rectangle {
                        id: calendarField

                        function activate() {
                            if (!enabled)
                                return;

                            var position = mapToItem(root, 0, height + Md3.spacing.xs);
                            root.calendarPopupY = position.y;
                            root.calendarPopupOpen = true;
                        }

                        Accessible.description: root.eventId === "" ? qsTr("Choose a calendar") : qsTr("The calendar cannot be changed after an event is created.")
                        Accessible.name: root.calendarName()
                        Accessible.role: Accessible.ComboBox
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: 56
                        activeFocusOnTab: false
                        border.color: calendarMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.56) : Config.alpha(Config.md3.outline, 0.22)
                        border.width: 1
                        color: Config.md3.surface_container_low
                        enabled: root.eventId === ""
                        opacity: enabled ? 1 : Md3.state.disabledContent
                        radius: Md3.shape.medium

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Config.animationDuration(Md3.motion.short3)
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animationDuration(Md3.motion.short2)
                            }
                        }

                        Accessible.onPressAction: activate()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                                activate();
                                event.accepted = true;
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            color: Config.md3.on_surface
                            opacity: calendarMouse.pressed ? Md3.state.pressed : calendarMouse.containsMouse ? Md3.state.hover : 0
                            radius: Math.max(0, calendarField.radius - 1)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animationDuration(Md3.motion.short2)
                                    easing.type: Md3.motion.standard
                                }
                            }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 15
                            spacing: Md3.spacing.sm

                            Rectangle {
                                Layout.preferredHeight: 12
                                Layout.preferredWidth: 12
                                color: root.calendarColor()
                                radius: 6
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                                text: root.calendarName()
                            }
                            Md3Icon {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: 20
                                color: Config.md3.on_surface_variant
                                filled: root.eventId !== ""
                                name: root.eventId === "" ? "expand_more" : "lock"
                                size: 20
                            }
                        }
                        MouseArea {
                            id: calendarMouse

                            anchors.fill: parent
                            cursorShape: calendarField.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: calendarField.enabled
                            hoverEnabled: true

                            onClicked: calendarField.activate()
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.48)
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                        font.pixelSize: Md3.typeScale.bodySmall.size
                        font.weight: Md3.typeScale.bodySmall.weight
                        text: qsTr("The calendar cannot be changed after an event is created.")
                        visible: root.eventId !== "" && !root.isTask
                        wrapMode: Text.Wrap
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Md3.spacing.xs

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                        text: root.isTask ? qsTr("Due date") : qsTr("Date")
                    }
                    CalendarDateField {
                        accessibleDescription: root.isTask ? qsTr("Choose task due date") : qsTr("Choose event date")
                        value: root.eventDate

                        onClicked: root.openDatePicker("start")
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Md3.spacing.xs
                    visible: !root.isTask

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                        text: qsTr("End date")
                    }
                    CalendarDateField {
                        accessibleDescription: qsTr("Choose event end date")
                        value: root.eventEndDate

                        onClicked: root.openDatePicker("end")
                    }
                }
                Rectangle {
                    id: allDayCard

                    function requestToggle() {
                        root.allDay = !root.allDay;
                    }

                    Accessible.checked: root.allDay
                    Accessible.description: qsTr("Hide start and end times")
                    Accessible.name: qsTr("All-day event")
                    Accessible.role: Accessible.CheckBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    activeFocusOnTab: false
                    border.color: "transparent"
                    border.width: 0
                    color: allDayMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : Config.alpha(Config.md3.surface, Config.lightTheme ? 0.65 : 0.22)
                    radius: Md3.shape.medium
                    visible: !root.isTask

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Config.animationDuration(120)
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(110)
                        }
                    }

                    Accessible.onPressAction: requestToggle()
                    Keys.onReturnPressed: event => {
                        requestToggle();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: event => {
                        requestToggle();
                        event.accepted = true;
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: allDaySwitch.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            text: qsTr("All-day event")
                            width: parent.width
                        }
                        Text {
                            color: Config.md3.on_surface_variant
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            renderType: Text.NativeRendering
                            text: qsTr("Hide start and end times")
                            width: parent.width
                        }
                    }
                    ToggleSwitch {
                        id: allDaySwitch

                        Accessible.ignored: true
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.allDay
                        hovered: allDayMouse.containsMouse
                        interactive: false
                        pressed: allDayMouse.pressed
                    }
                    MouseArea {
                        id: allDayMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: allDayCard.requestToggle()
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: !root.allDay && !root.isTask

                    Repeater {
                        model: [
                            {
                                "label": qsTr("Starts"),
                                "target": "start",
                                "value": root.startTime
                            },
                            {
                                "label": qsTr("Ends"),
                                "target": "end",
                                "value": root.endTime
                            }
                        ]

                        ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            spacing: Md3.spacing.xs

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                text: modelData.label
                            }
                            Rectangle {
                                id: timeField

                                function activate() {
                                    timePicker.targetField = modelData.target;
                                    timePicker.openWith(modelData.value);
                                }

                                Accessible.description: qsTr("Choose event time")
                                Accessible.name: qsTr("%1: %2").arg(modelData.label).arg(modelData.value)
                                Accessible.role: Accessible.Button
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredHeight: 56
                                activeFocusOnTab: false
                                border.color: timeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.56) : Config.alpha(Config.md3.outline, 0.22)
                                border.width: 1
                                color: Config.md3.surface_container_low
                                radius: Md3.shape.medium

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Config.animationDuration(Md3.motion.short3)
                                    }
                                }

                                Accessible.onPressAction: activate()
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                                        activate();
                                        event.accepted = true;
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    color: Config.md3.on_surface
                                    opacity: timeMouse.pressed ? Md3.state.pressed : timeMouse.containsMouse ? Md3.state.hover : 0
                                    radius: Math.max(0, timeField.radius - 1)

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Config.animationDuration(Md3.motion.short2)
                                            easing.type: Md3.motion.standard
                                        }
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 15
                                    spacing: Md3.spacing.sm

                                    Md3Icon {
                                        Layout.preferredHeight: 22
                                        Layout.preferredWidth: 22
                                        color: Config.md3.primary
                                        name: "schedule"
                                        size: 22
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        color: Config.md3.on_surface
                                        font.family: Config.fontName
                                        font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                        font.pixelSize: 16
                                        font.weight: Font.Medium
                                        renderType: Text.NativeRendering
                                        text: modelData.value
                                    }
                                }
                                MouseArea {
                                    id: timeMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: timeField.activate()
                                }
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                    font.pixelSize: Md3.typeScale.bodySmall.size
                    font.weight: 600
                    text: qsTr("End date and time must be later than the start.")
                    visible: !root.validTimeRange && !root.isTask
                }
                SettingsSelectField {
                    id: recurrenceField

                    Layout.fillWidth: true
                    label: qsTr("Repeat")
                    labelFontPixelSize: 14
                    labelFontWeight: Font.DemiBold
                    valueFontPixelSize: 15
                    valueText: root.recurrenceLabel()
                    visible: !root.isTask

                    onClicked: sourceItem => root.openRecurrencePopup(sourceItem)
                }
                SettingsSelectField {
                    id: recurrenceAdvancedField

                    Layout.fillWidth: true
                    label: qsTr("Repeat options")
                    labelFontPixelSize: 14
                    labelFontWeight: Font.DemiBold
                    valueFontPixelSize: 15
                    valueText: root.recurrenceAdvancedLabel()
                    visible: !root.isTask && root.recurrenceType !== "none"

                    onClicked: sourceItem => root.openRecurrenceAdvancedPopup(sourceItem)
                }
                SettingsSelectField {
                    id: reminderField

                    Layout.fillWidth: true
                    label: qsTr("Reminder")
                    labelFontPixelSize: 14
                    labelFontWeight: Font.DemiBold
                    valueFontPixelSize: 15
                    valueText: root.reminderLabel()
                    visible: !root.isTask

                    onClicked: sourceItem => root.openReminderPopup(sourceItem)
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: !root.isTask

                    SettingsSelectField {
                        id: availabilityField

                        Layout.fillWidth: true
                        label: qsTr("Show as")
                        labelFontPixelSize: 14
                        labelFontWeight: Font.DemiBold
                        valueFontPixelSize: 15
                        valueText: root.availabilityLabel()

                        onClicked: sourceItem => root.openAvailabilityPopup(sourceItem)
                    }
                    SettingsSelectField {
                        id: visibilityField

                        Layout.fillWidth: true
                        label: qsTr("Visibility")
                        labelFontPixelSize: 14
                        labelFontWeight: Font.DemiBold
                        valueFontPixelSize: 15
                        valueText: root.visibilityLabel()

                        onClicked: sourceItem => root.openVisibilityPopup(sourceItem)
                    }
                }
                FormTextField {
                    id: locationField

                    Layout.fillWidth: true
                    inputFontPixelSize: 15
                    label: qsTr("Location")
                    labelFontPixelSize: 14
                    labelFontWeight: Font.DemiBold
                    placeholder: qsTr("Add a location")
                    placeholderFontPixelSize: 15
                    visible: !root.isTask

                    onTextChanged: root.location = text
                }
                FormTextField {
                    id: descriptionField

                    Layout.fillWidth: true
                    inputFontPixelSize: 15
                    label: root.isTask ? qsTr("Notes") : qsTr("Description")
                    labelFontPixelSize: 14
                    labelFontWeight: Font.DemiBold
                    multiline: true
                    placeholder: qsTr("Add notes or details")
                    placeholderFontPixelSize: 15

                    onTextChanged: root.description = text
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                    font.pixelSize: Md3.typeScale.bodySmall.size
                    font.weight: Md3.typeScale.bodySmall.weight
                    text: root.taskError
                    visible: text !== ""
                    wrapMode: Text.Wrap
                }
            }
        }
        Rectangle {
            id: footerDivider

            anchors.bottom: editorFooter.top
            anchors.left: parent.left
            anchors.right: parent.right
            color: Config.alpha(Config.md3.on_surface, 0.07)
            height: 1
        }
        RowLayout {
            id: editorFooter

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            height: 60
            spacing: 10

            Rectangle {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                color: deleteMouse.containsMouse ? Config.alpha(Config.md3.error, 0.16) : Config.alpha(Config.md3.error, 0.09)
                enabled: !root.taskBusy
                radius: 12
                visible: root.eventId !== "" && !root.eventReadOnly

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(110)
                    }
                }

                Md3Icon {
                    anchors.centerIn: parent
                    color: Config.md3.error
                    filled: true
                    name: "user-trash-symbolic"
                    size: 20
                }
                MouseArea {
                    id: deleteMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.deleteEvent()
                }
            }
            Item {
                Layout.fillWidth: true
            }
            SettingsActionButton {
                enabled: !root.taskBusy
                iconName: root.taskData && root.taskData.status === "completed" ? "checkbox-symbolic" : "checkbox-checked-symbolic"
                iconOnly: true
                text: root.taskData && root.taskData.status === "completed" ? qsTr("Mark incomplete") : qsTr("Mark completed")
                visible: root.isTask && !root.isNewTask

                onClicked: root.changeTask(root.taskData && root.taskData.status === "completed" ? "reopen" : "complete")
            }
            SettingsActionButton {
                Layout.preferredHeight: 44
                enabled: !root.taskBusy
                text: qsTr("Cancel")
                textPixelSize: 15
                textWeight: Font.DemiBold

                onClicked: root.close()
            }
            SettingsActionButton {
                Layout.preferredHeight: 44
                enabled: !root.taskBusy && (root.isNewTask ? (root.eventTitle.trim() !== "" && (root.taskSource !== "google" || (root.taskAccountId !== "" && root.taskListId !== ""))) : root.isTask ? (root.eventTitle.trim() !== "") : (!root.eventReadOnly && root.eventTitle.trim() !== "" && root.calendarId !== "" && root.validTimeRange && !CalendarService.eventActionBusy))
                iconName: root.isNewTask ? "checkbox-checked-symbolic" : (root.eventId !== "" ? "emblem-ok-symbolic" : "appointment-new-symbolic")
                iconSize: 20
                primary: true
                text: root.taskBusy ? qsTr("Saving…") : (root.isNewTask ? qsTr("Create task") : (root.eventId !== "" ? qsTr("Update") : qsTr("Create")))
                textPixelSize: 15
                textWeight: Font.DemiBold

                onClicked: root.save()
            }
        }
    }
    SelectPopup {
        id: taskDestinationPopup

        anchors.fill: parent
        itemActive: option => {
            if (!option)
                return false;
            if (root.taskSource === "local")
                return option.source === "local";
            return option.source === "google" && option.accountId === root.taskAccountId;
        }
        itemColor: option => option && option.color ? option.color : ""
        itemLabel: option => option && option.label ? option.label : ""
        model: root.taskDestinationOptions
        opened: root.taskDestinationPopupOpen
        popupWidth: 320
        popupY: root.taskDestinationPopupY
        rightMargin: Math.max(12, root.width - editorCard.x - editorCard.width + 8)
        shadowOpacity: 0.5
        z: 60

        onDismissed: root.taskDestinationPopupOpen = false
        onItemSelected: option => root.selectTaskDestination(option)
    }
    SelectPopup {
        id: taskListPopup

        anchors.fill: parent
        itemActive: option => option && String(option.id || "") === root.taskListId
        itemColor: option => option && option.color ? option.color : ""
        itemLabel: option => option && option.label ? option.label : ""
        model: root.taskListOptions
        opened: root.taskListPopupOpen
        popupWidth: 300
        popupY: root.taskListPopupY
        rightMargin: Math.max(12, root.width - editorCard.x - editorCard.width + 8)
        shadowOpacity: 0.5
        z: 60

        onDismissed: root.taskListPopupOpen = false
        onItemSelected: option => root.selectTaskList(option)
    }
    SelectPopup {
        id: calendarPopup

        anchors.fill: parent
        itemActive: calendar => {
            return calendar && String(calendar.id || "") === root.calendarId;
        }
        itemLabel: calendar => {
            return calendar ? String(calendar.name || qsTr("Calendar")) : "";
        }
        model: root.writableCalendars
        opened: root.calendarPopupOpen
        popupWidth: 300
        popupY: root.calendarPopupY
        rightMargin: Math.max(12, root.width - editorCard.x - editorCard.width + 8)
        shadowOpacity: 0.5
        z: 60

        onDismissed: root.calendarPopupOpen = false
        onItemSelected: calendar => {
            root.calendarId = String(calendar.id || "");
            if (!root.isTask && (!root.reminderUserSelected || root.useDefaultReminder))
                root.applyCalendarDefaultReminder();
            root.calendarPopupOpen = false;
        }
    }
    SelectPopup {
        id: recurrencePopup

        anchors.fill: parent
        itemActive: option => option && String(option.id || "none") === root.recurrenceType
        itemLabel: option => option && option.label ? option.label : ""
        itemVisible: option => option && String(option.id || "") !== "advanced" || root.recurrenceType !== "none"
        model: root.recurrenceOptions()
        opened: root.recurrencePopupOpen
        popupWidth: 280
        popupY: root.recurrencePopupY
        rightMargin: Math.max(12, root.width - editorCard.x - editorCard.width + 8)
        shadowOpacity: 0.5
        z: 60

        onDismissed: root.recurrencePopupOpen = false
        onItemSelected: option => root.selectRecurrence(option)
    }
    SelectPopup {
        id: reminderPopup

        anchors.fill: parent
        itemActive: option => option && Number(option.minutes) === root.reminderMinutes
        itemLabel: option => {
            if (!option)
                return "";
            return option.label || "";
        }
        model: root.reminderOptions()
        opened: root.reminderPopupOpen
        popupWidth: 280
        popupY: root.reminderPopupY
        rightMargin: Math.max(12, root.width - editorCard.x - editorCard.width + 8)
        shadowOpacity: 0.5
        z: 60

        onDismissed: root.reminderPopupOpen = false
        onItemSelected: option => root.selectReminder(option)
    }
    SelectPopup {
        id: availabilityPopup

        anchors.fill: parent
        itemActive: option => option && String(option.id || "busy") === root.availabilityType
        itemLabel: option => option && option.label ? option.label : ""
        model: root.availabilityOptions()
        opened: root.availabilityPopupOpen
        popupWidth: 300
        popupY: root.availabilityPopupY
        rightMargin: Math.max(12, root.width - editorCard.x - editorCard.width + 8)
        shadowOpacity: 0.5
        z: 60

        onDismissed: root.availabilityPopupOpen = false
        onItemSelected: option => root.selectAvailability(option)
    }
    SelectPopup {
        id: visibilityPopup

        anchors.fill: parent
        itemActive: option => option && String(option.id || "default") === root.visibilityType
        itemLabel: option => option && option.label ? option.label : ""
        model: root.visibilityOptions()
        opened: root.visibilityPopupOpen
        popupWidth: 320
        popupY: root.visibilityPopupY
        rightMargin: Math.max(12, root.width - editorCard.x - editorCard.width + 8)
        shadowOpacity: 0.5
        z: 60

        onDismissed: root.visibilityPopupOpen = false
        onItemSelected: option => root.selectVisibility(option)
    }
    Item {
        id: recurrenceAdvancedPopup

        anchors.fill: parent
        enabled: root.recurrenceAdvancedPopupOpen
        visible: root.recurrenceAdvancedPopupOpen
        z: 65

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.recurrenceAdvancedPopupOpen = false
            onWheel: event => event.accepted = true
        }
        Rectangle {
            id: recurrenceAdvancedCard

            color: Config.md3.surface_container_high
            height: Math.min(advancedColumn.implicitHeight + advancedTitleText.implicitHeight + advancedFooterRow.implicitHeight + Md3.spacing.lg * 2 + Md3.spacing.md * 2, root.height - 32)
            radius: Md3.shape.extraLarge
            width: Math.min(380, root.width - 24)
            x: Math.max(12, Math.min(root.width - width - 12, editorCard.x + editorCard.width - width))
            y: Math.max(12, Math.min(root.height - height - 12, root.recurrenceAdvancedPopupY))

            ShellShadow {
                active: root.recurrenceAdvancedPopupOpen
                componentShadow: true
                cornerRadius: recurrenceAdvancedCard.radius
                target: recurrenceAdvancedCard
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onClicked: event => event.accepted = true
                onWheel: event => event.accepted = true
            }
            ColumnLayout {
                id: advancedOuterColumn

                anchors.fill: parent
                anchors.margins: Md3.spacing.lg
                spacing: 0

                // ── Title ──
                Text {
                    id: advancedTitleText

                    Layout.bottomMargin: Md3.spacing.md
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleLarge.letterSpacing
                    font.pixelSize: Md3.typeScale.titleLarge.size
                    font.weight: Md3.typeScale.titleLarge.emphasizedWeight
                    text: qsTr("Custom recurrence")
                }

                // ── Scrollable content ──
                Flickable {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    contentHeight: advancedColumn.implicitHeight
                    contentWidth: width
                    flickableDirection: Flickable.VerticalFlick
                    interactive: contentHeight > height

                    ColumnLayout {
                        id: advancedColumn

                        spacing: Md3.spacing.md
                        width: parent.width

                        // ── Repeat every ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Md3.spacing.sm

                            Md3Icon {
                                Layout.alignment: Qt.AlignVCenter
                                color: Config.md3.on_surface_variant
                                name: "repeat"
                                size: 20
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                text: qsTr("Repeat every")
                            }
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredHeight: 44
                                Layout.preferredWidth: 64
                                border.color: intervalInput.activeFocus ? Config.md3.primary : Config.alpha(Config.md3.outline, 0.22)
                                border.width: intervalInput.activeFocus ? 2 : 1
                                color: Config.md3.surface_container_low
                                radius: Md3.shape.medium

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Config.animationDuration(Md3.motion.short2)
                                    }
                                }

                                TextInput {
                                    id: intervalInput

                                    anchors.fill: parent
                                    anchors.margins: Md3.spacing.sm
                                    clip: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: Md3.typeScale.bodyLarge.size
                                    horizontalAlignment: Text.AlignHCenter
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    maximumLength: 3
                                    text: String(root.recurrenceInterval)
                                    verticalAlignment: Text.AlignVCenter

                                    validator: IntValidator {
                                        bottom: 1
                                        top: 999
                                    }

                                    onEditingFinished: root.recurrenceInterval = Math.max(1, Number(text || 1))
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                color: Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                font.pixelSize: Md3.typeScale.bodyLarge.size
                                text: {
                                    if (root.recurrenceType === "daily")
                                        return root.recurrenceInterval === 1 ? qsTr("day") : qsTr("days");
                                    if (root.recurrenceType === "weekly")
                                        return root.recurrenceInterval === 1 ? qsTr("week") : qsTr("weeks");
                                    if (root.recurrenceType === "monthly")
                                        return root.recurrenceInterval === 1 ? qsTr("month") : qsTr("months");
                                    return root.recurrenceInterval === 1 ? qsTr("year") : qsTr("years");
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                color: Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                font.pixelSize: Md3.typeScale.bodyLarge.size
                                text: qsTr("on day %1").arg(root.eventDate.getDate())
                                visible: root.recurrenceType === "monthly"
                            }
                        }

                        // ── Repeat on (weekly only) ──
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Md3.spacing.sm
                            visible: root.recurrenceType === "weekly"

                            RowLayout {
                                Layout.fillWidth: true

                                Md3Icon {
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Config.md3.on_surface_variant
                                    name: "calendar_month"
                                    size: 22
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    text: qsTr("Repeat on")
                                }
                            }
                            Row {
                                Layout.fillWidth: true
                                spacing: Md3.spacing.xs

                                Repeater {
                                    model: [
                                        {
                                            "id": "MO",
                                            "label": qsTr("M")
                                        },
                                        {
                                            "id": "TU",
                                            "label": qsTr("T")
                                        },
                                        {
                                            "id": "WE",
                                            "label": qsTr("W")
                                        },
                                        {
                                            "id": "TH",
                                            "label": qsTr("T")
                                        },
                                        {
                                            "id": "FR",
                                            "label": qsTr("F")
                                        },
                                        {
                                            "id": "SA",
                                            "label": qsTr("S")
                                        },
                                        {
                                            "id": "SU",
                                            "label": qsTr("S")
                                        }
                                    ]

                                    delegate: Rectangle {
                                        id: dayPill

                                        required property var modelData
                                        property bool selected: root.recurrenceWeekdays.indexOf(modelData.id) >= 0

                                        color: selected ? Config.md3.primary : "transparent"
                                        height: 36
                                        radius: Md3.shape.full
                                        width: 36

                                        Behavior on color {
                                            Md3ColorAnimation {
                                                role: "state"
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            border.color: dayPill.selected ? "transparent" : Config.alpha(Config.md3.outline, 0.38)
                                            border.width: 1
                                            color: "transparent"
                                            radius: parent.radius
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Config.alpha(dayPill.selected ? Config.md3.on_primary : Config.md3.on_surface, dayMouse.pressed ? Md3.state.pressed : dayMouse.containsMouse ? Md3.state.hover : 0)
                                            radius: parent.radius

                                            Behavior on color {
                                                Md3ColorAnimation {
                                                    role: "state"
                                                }
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            color: dayPill.selected ? Config.md3.on_primary : Config.md3.on_surface
                                            font.family: Config.fontName
                                            font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                                            font.pixelSize: Md3.typeScale.labelLarge.size
                                            font.weight: Md3.typeScale.labelLarge.weight
                                            text: dayPill.modelData.label

                                            Behavior on color {
                                                Md3ColorAnimation {
                                                    role: "state"
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: dayMouse

                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true

                                            onClicked: root.toggleRecurrenceWeekday(dayPill.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        // ── Separator ──
                        Rectangle {
                            Layout.bottomMargin: Md3.spacing.xxs
                            Layout.fillWidth: true
                            Layout.topMargin: Md3.spacing.xxs
                            color: Config.alpha(Config.md3.outline_variant, 0.28)
                            implicitHeight: 1
                        }

                        // ── Ends ──
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Md3.spacing.sm

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44

                                Md3Icon {
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Config.md3.on_surface_variant
                                    name: "schedule"
                                    size: 22
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    text: qsTr("Ends")
                                }
                            }

                            // Never
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                spacing: Md3.spacing.sm

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: 20
                                    border.color: root.recurrenceEndType === "none" ? Config.md3.primary : Config.md3.outline
                                    border.width: 2
                                    color: "transparent"
                                    radius: 10

                                    Behavior on border.color {
                                        Md3ColorAnimation {
                                            role: "state"
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        color: Config.md3.primary
                                        height: 10
                                        radius: 5
                                        scale: root.recurrenceEndType === "none" ? 1 : 0
                                        width: 10

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Config.animationDuration(Md3.motion.short3)
                                                easing.type: Md3.motion.standard
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.centerIn: parent
                                        cursorShape: Qt.PointingHandCursor
                                        height: 40
                                        width: 40

                                        onClicked: root.recurrenceEndType = "none"
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                    font.pixelSize: 15
                                    text: qsTr("Never")
                                    verticalAlignment: Text.AlignVCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: root.recurrenceEndType = "none"
                                    }
                                }
                            }

                            // On date
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                spacing: Md3.spacing.sm

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: 20
                                    border.color: root.recurrenceEndType === "until" ? Config.md3.primary : Config.md3.outline
                                    border.width: 2
                                    color: "transparent"
                                    radius: 10

                                    Behavior on border.color {
                                        Md3ColorAnimation {
                                            role: "state"
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        color: Config.md3.primary
                                        height: 10
                                        radius: 5
                                        scale: root.recurrenceEndType === "until" ? 1 : 0
                                        width: 10

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Config.animationDuration(Md3.motion.short3)
                                                easing.type: Md3.motion.standard
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.centerIn: parent
                                        cursorShape: Qt.PointingHandCursor
                                        height: 40
                                        width: 40

                                        onClicked: {
                                            root.recurrenceEndType = "until";
                                            root.openDatePicker("recurrenceUntil");
                                        }
                                    }
                                }
                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                    font.pixelSize: 15
                                    text: qsTr("On date")
                                    verticalAlignment: Text.AlignVCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            root.recurrenceEndType = "until";
                                            root.openDatePicker("recurrenceUntil");
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    border.color: datePillMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.56) : Config.alpha(Config.md3.outline, 0.22)
                                    border.width: 1
                                    color: Config.md3.surface_container_low
                                    enabled: root.recurrenceEndType === "until"
                                    opacity: enabled ? 1 : Md3.state.disabledContent
                                    radius: Md3.shape.full

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: Config.animationDuration(Md3.motion.short2)
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        color: Config.md3.on_surface
                                        font.family: Config.fontName
                                        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                                        font.pixelSize: Md3.typeScale.labelLarge.size
                                        font.weight: Md3.typeScale.labelLarge.weight
                                        text: root.dateForPickerValue(root.recurrenceUntilDate)
                                    }
                                    MouseArea {
                                        id: datePillMouse

                                        anchors.fill: parent
                                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        enabled: parent.enabled
                                        hoverEnabled: true

                                        onClicked: root.openDatePicker("recurrenceUntil")
                                    }
                                }
                            }

                            // After N occurrences
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                spacing: Md3.spacing.sm

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: 20
                                    border.color: root.recurrenceEndType === "count" ? Config.md3.primary : Config.md3.outline
                                    border.width: 2
                                    color: "transparent"
                                    radius: 10

                                    Behavior on border.color {
                                        Md3ColorAnimation {
                                            role: "state"
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        color: Config.md3.primary
                                        height: 10
                                        radius: 5
                                        scale: root.recurrenceEndType === "count" ? 1 : 0
                                        width: 10

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Config.animationDuration(Md3.motion.short3)
                                                easing.type: Md3.motion.standard
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.centerIn: parent
                                        cursorShape: Qt.PointingHandCursor
                                        height: 40
                                        width: 40

                                        onClicked: root.recurrenceEndType = "count"
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                    font.pixelSize: 15
                                    text: qsTr("After")

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: root.recurrenceEndType = "count"
                                    }
                                }
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredHeight: 40
                                    Layout.preferredWidth: 64
                                    border.color: countInput.activeFocus ? Config.md3.primary : Config.alpha(Config.md3.outline, 0.22)
                                    border.width: countInput.activeFocus ? 2 : 1
                                    color: Config.md3.surface_container_low
                                    enabled: root.recurrenceEndType === "count"
                                    opacity: enabled ? 1 : Md3.state.disabledContent
                                    radius: Md3.shape.medium

                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: Config.animationDuration(Md3.motion.short2)
                                        }
                                    }

                                    TextInput {
                                        id: countInput

                                        anchors.fill: parent
                                        anchors.margins: Md3.spacing.xs
                                        clip: true
                                        color: Config.md3.on_surface
                                        enabled: parent.enabled
                                        font.family: Config.fontName
                                        font.pixelSize: Md3.typeScale.bodyLarge.size
                                        horizontalAlignment: Text.AlignHCenter
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        maximumLength: 4
                                        text: String(root.recurrenceCount)
                                        verticalAlignment: Text.AlignVCenter

                                        validator: IntValidator {
                                            bottom: 1
                                            top: 9999
                                        }

                                        onEditingFinished: root.recurrenceCount = Math.max(1, Number(text || 1))
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface_variant
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                    font.pixelSize: Md3.typeScale.bodyLarge.size
                                    text: qsTr("occurrences")
                                }
                            }
                        }
                    }
                }

                // ── Footer: Cancel + Done ──
                RowLayout {
                    id: advancedFooterRow

                    Layout.fillWidth: true
                    Layout.topMargin: Md3.spacing.md
                    spacing: Md3.spacing.xs

                    Item {
                        Layout.fillWidth: true
                    }
                    SettingsActionButton {
                        text: qsTr("Cancel")
                        textPixelSize: Md3.typeScale.labelLarge.size
                        textWeight: Md3.typeScale.labelLarge.weight

                        onClicked: root.recurrenceAdvancedPopupOpen = false
                    }
                    SettingsActionButton {
                        primary: true
                        text: qsTr("Done")
                        textPixelSize: Md3.typeScale.labelLarge.size
                        textWeight: Md3.typeScale.labelLarge.emphasizedWeight

                        onClicked: root.recurrenceAdvancedPopupOpen = false
                    }
                }
            }
        }
    }
    SelectPopup {
        id: endPopup

        anchors.fill: parent
        itemActive: option => option && String(option.id || "none") === root.recurrenceEndType
        itemLabel: option => option && option.label ? option.label : ""
        model: root.recurrenceEndOptions()
        opened: root.recurrenceEndPopupOpen
        popupWidth: 300
        popupY: root.recurrenceAdvancedPopupY + 136
        rightMargin: Math.max(12, root.width - recurrenceAdvancedCard.x - recurrenceAdvancedCard.width + 8)
        shadowOpacity: 0.5
        z: 70

        onDismissed: root.recurrenceEndPopupOpen = false
        onItemSelected: option => {
            if (!option)
                return;
            root.recurrenceEndType = String(option.id || "none");
            root.recurrenceEndPopupOpen = false;
            if (root.recurrenceEndType === "until")
                root.openDatePicker("recurrenceUntil");
        }
    }
    DatePickerPopup {
        id: datePicker

        backdropRadius: 24
        placementParent: editorCard

        onDateSelected: value => {
            var selected = root.parsePickerDate(value);
            if (root.datePickerTarget === "recurrenceUntil") {
                root.recurrenceUntilDate = selected;
            } else if (root.datePickerTarget === "end") {
                root.eventEndDate = selected;
            } else {
                root.eventDate = selected;
                if (root.eventEndDate.getTime() < selected.getTime())
                    root.eventEndDate = new Date(selected);
            }
        }
    }
    ClockTimePicker {
        id: timePicker

        property string targetField: ""

        backdropRadius: 24
        placementParent: editorCard

        onConfirmed: (hours, minutes) => {
            var value = hours + ":" + minutes;
            if (targetField === "start")
                root.startTime = value;
            else
                root.endTime = value;
        }
    }
}
