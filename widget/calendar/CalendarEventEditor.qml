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
    property string calendarId: ""
    property bool calendarPopupOpen: false
    property real calendarPopupY: 0
    property string description: ""
    property string endTime: "11:00"
    property date eventDate: new Date()
    property string eventId: ""
    property bool eventReadOnly: false
    property string eventTitle: ""
    readonly property bool isNewTask: taskCreateMode && taskData === null
    readonly property bool isTask: taskData !== null || taskCreateMode
    property string location: ""
    property bool opened: false
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
    readonly property bool validTimeRange: isTask || allDay || minutesForTime(endTime) > minutesForTime(startTime)
    readonly property var writableCalendars: buildWritableCalendars()

    signal closed

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
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        opened = false;
        closed();
    }
    function dateForApi() {
        return eventDate.getFullYear() + "-" + String(eventDate.getMonth() + 1).padStart(2, "0") + "-" + String(eventDate.getDate()).padStart(2, "0");
    }
    function dateForPicker() {
        return String(eventDate.getDate()).padStart(2, "0") + "/" + String(eventDate.getMonth() + 1).padStart(2, "0") + "/" + eventDate.getFullYear();
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
    function openEvent(eventData, editorAnchor) {
        if (!eventData || taskBusy)
            return;

        if (modeSegment)
            modeSegment.animationsReady = false;
        taskCreateMode = false;
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        calendarPopupOpen = false;
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
        if (allDay) {
            eventDate = parseApiDate(eventData.start);
            startTime = "10:00";
            endTime = "11:00";
        } else {
            var start = new Date(eventData.start);
            var end = new Date(eventData.end);
            eventDate = isNaN(start.getTime()) ? new Date() : new Date(start.getFullYear(), start.getMonth(), start.getDate());
            startTime = isNaN(start.getTime()) ? "10:00" : formatTime(start);
            endTime = isNaN(end.getTime()) ? "11:00" : formatTime(end);
        }
        syncTextFields();
        formFlickable.contentY = 0;
        opened = true;
        Qt.callLater(function () {
            titleField.forceActiveFocus();
        });
    }
    function openNew(value, selectedStartMinutes, selectedEndMinutes, editorAnchor) {
        if (taskBusy)
            return;
        if (modeSegment)
            modeSegment.animationsReady = false;
        taskCreateMode = false;
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        calendarPopupOpen = false;
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
        var startMinutes = Math.max(0, Math.min(23 * 60 + 45, Number(selectedStartMinutes || 0)));
        var endMinutes = Math.max(startMinutes + 1, Math.min(23 * 60 + 59, Number(selectedEndMinutes || startMinutes + 60)));
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
        if (modeSegment)
            modeSegment.animationsReady = false;
        calendarPopupOpen = false;
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
        startTime = "00:00";
        endTime = "23:59";
        syncTextFields();
        formFlickable.contentY = 0;
        opened = true;
        Qt.callLater(function () {
            titleField.forceActiveFocus();
        });
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
            CalendarService.updateEvent(calendarId, eventId, eventTitle.trim(), dateForApi(), startTime, endTime, allDay, location.trim(), description.trim());
        else
            CalendarService.createEvent(calendarId, eventTitle.trim(), dateForApi(), startTime, endTime, allDay, location.trim(), description.trim());
        close();
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
    function setEditorMode(mode) {
        if (taskBusy)
            return;
        calendarPopupOpen = false;
        taskDestinationPopupOpen = false;
        taskListPopupOpen = false;
        taskError = "";

        if (mode === "task") {
            taskCreateMode = true;
            taskData = null;
            allDay = true;
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
            if (!calendarId)
                calendarId = defaultCalendarId();
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
    function verticalPosition(cardHeight) {
        var margin = 16;
        if (!anchorRect)
            return Math.max(margin, Math.round((height - cardHeight) / 2));

        var targetY = Number(anchorRect.y || 0) - 18;
        return Math.max(margin, Math.min(height - cardHeight - margin, targetY));
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

    onTaskListOptionsChanged: {
        if (isNewTask && taskSource === "google") {
            if (taskListOptions.length > 0 && !taskListOptions.some(item => item.id === taskListId))
                taskListId = taskListOptions[0].id;
        }
    }

    WheelHandler {
        blocking: true
        target: null
    }
    MouseArea {
        anchors.fill: parent

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
                    Rectangle {
                        id: dateField

                        function activate() {
                            datePicker.selectedDate = root.dateForPicker();
                            datePicker.currentMonth = root.eventDate.getMonth();
                            datePicker.currentYear = root.eventDate.getFullYear();
                            datePicker.open();
                        }

                        Accessible.description: root.isTask ? qsTr("Choose task due date") : qsTr("Choose event date")
                        Accessible.name: qsTr("%1, %2 lunar").arg(root.eventDate.toLocaleDateString(Qt.locale(), Locale.LongFormat)).arg(Lunar.getLunarFullString(root.eventDate))
                        Accessible.role: Accessible.Button
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: 56
                        activeFocusOnTab: false
                        border.color: dateMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.56) : Config.alpha(Config.md3.outline, 0.22)
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
                            opacity: dateMouse.pressed ? Md3.state.pressed : dateMouse.containsMouse ? Md3.state.hover : 0
                            radius: Math.max(0, dateField.radius - 1)

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
                                name: "calendar_month"
                                size: 22
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    renderType: Text.NativeRendering
                                    text: root.eventDate.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface_variant
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.labelSmall.letterSpacing
                                    font.pixelSize: Md3.typeScale.labelSmall.size
                                    font.weight: Md3.typeScale.labelSmall.weight
                                    renderType: Text.NativeRendering
                                    text: qsTr("%1 lunar").arg(Lunar.getLunarFullString(root.eventDate))
                                }
                            }
                            Md3Icon {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: 20
                                color: Config.md3.on_surface_variant
                                name: "expand_more"
                                size: 20
                            }
                        }
                        MouseArea {
                            id: dateMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: dateField.activate()
                        }
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
                    text: qsTr("End time must be later than start time.")
                    visible: !root.validTimeRange && !root.isTask
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
            root.calendarPopupOpen = false;
        }
    }
    DatePickerPopup {
        id: datePicker

        backdropRadius: 24
        placementParent: editorCard

        onDateSelected: value => {
            return root.eventDate = root.parsePickerDate(value);
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
