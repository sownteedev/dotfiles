import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../../../" // for Config
import "lunar.js" as Lunar
import "../../../../service"
import "../../../../components"

Item {
    id: calendarRoot

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    property var eventsForSelectedDate: {
        var dummy = GoogleService.allEvents;
        return GoogleService.getEventsForDate(selectedDay, selectedMonth, selectedYear);
    }
    property bool isSwipingOut: false
    property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    property int pendingMonthDirection: 0
    readonly property var pendingTasksByDate: buildPendingTasksIndex(LocalTaskService.tasks, GoogleService.allTasks)
    readonly property var pendingTasksForSelectedDate: tasksForDate(selectedDay, selectedMonth, selectedYear)
    readonly property Item popupBackdropHost: controlLeftWindow.topPopupBackdropHost
    readonly property real popupBackdropRadius: controlLeftWindow.topPopupBackdropRadius
    property int selectedDay: todayDate
    readonly property int selectedEventCount: eventsForSelectedDate ? eventsForSelectedDate.length : 0
    readonly property int selectedItemCount: selectedEventCount + selectedTaskCount
    property int selectedMonth: todayMonth
    readonly property int selectedTaskCount: pendingTasksForSelectedDate ? pendingTasksForSelectedDate.length : 0
    property int selectedYear: todayYear
    property bool showEvents: false
    property real swipeOffset: 0
    property int todayDate: new Date().getDate()
    property int todayMonth: new Date().getMonth()
    property int todayYear: new Date().getFullYear()
    property var weekDays: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    function appendPendingTasks(index, tasks, taskSource) {
        if (!Array.isArray(tasks))
            return;
        for (var i = 0; i < tasks.length; ++i) {
            var task = tasks[i] || {};
            if (String(task.status || "needsAction") !== "needsAction")
                continue;
            var due = String(task.due || "");
            var dueKey = due.slice(0, 10);
            if (!/^\d{4}-\d{2}-\d{2}$/.test(dueKey))
                continue;
            if (!index[dueKey])
                index[dueKey] = [];
            index[dueKey].push({
                "due": due,
                "id": String(task.id || ""),
                "notes": String(task.notes || ""),
                "taskSource": taskSource,
                "title": String(task.title || "")
            });
        }
    }
    function buildPendingTasksIndex(localTasks, googleTasks) {
        var index = ({});
        appendPendingTasks(index, localTasks, "local");
        appendPendingTasks(index, googleTasks, "google");
        return index;
    }
    function completeTask(task) {
        if (!task || !task.id)
            return;
        if (task.taskSource === "google")
            GoogleService.updateTask("@default", task.id, undefined, undefined, undefined, "completed");
        else
            LocalTaskService.updateTask(task.id, undefined, undefined, undefined, "completed");
    }
    function dateKey(day, month, year) {
        return year + "-" + String(month + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0");
    }
    function daysForMonth(month, year) {
        var firstDay = new Date(year, month, 1).getDay(); // 0 is Sunday
        var startOffset = firstDay === 0 ? 6 : firstDay - 1; // Make Monday = 0
        var daysInMonth = new Date(year, month + 1, 0).getDate();
        var daysInPrevMonth = new Date(year, month, 0).getDate();

        var arr = [];
        // Previous month days
        for (var i = startOffset - 1; i >= 0; i--) {
            var prevD = daysInPrevMonth - i;
            var prevM = month === 0 ? 11 : month - 1;
            var prevY = month === 0 ? year - 1 : year;
            arr.push({
                day: prevD,
                month: prevM,
                year: prevY,
                isCurrent: false
            });
        }
        // Current month days
        for (var j = 1; j <= daysInMonth; j++) {
            arr.push({
                day: j,
                month: month,
                year: year,
                isCurrent: true
            });
        }
        // Next month days
        var nextDays = 42 - arr.length;
        for (var k = 1; k <= nextDays; k++) {
            var nextM = month === 11 ? 0 : month + 1;
            var nextY = month === 11 ? year + 1 : year;
            arr.push({
                day: k,
                month: nextM,
                year: nextY,
                isCurrent: false
            });
        }
        return arr;
    }

    // onCurrentMonthChanged is no longer needed since we fetch a 3-year window on startup

    function nextMonth() {
        if (currentMonth === 11) {
            currentMonth = 0;
            currentYear++;
        } else {
            currentMonth++;
        }
    }
    function prevMonth() {
        if (currentMonth === 0) {
            currentMonth = 11;
            currentYear--;
        } else {
            currentMonth--;
        }
    }
    function scheduleCountText() {
        if (selectedEventCount > 0 && selectedTaskCount > 0)
            return qsTr("%1 · %2").arg(qsTr("%n event(s)", "", selectedEventCount)).arg(qsTr("%n task(s)", "", selectedTaskCount));
        if (selectedTaskCount > 0)
            return qsTr("%n task(s)", "", selectedTaskCount);
        return qsTr("%n event(s)", "", selectedEventCount);
    }
    function settleMonth(direction) {
        if (monthSlide.running)
            return;

        pendingMonthDirection = direction;
        isSwipingOut = direction !== 0;
        monthSlide.from = swipeOffset;
        monthSlide.to = direction * (calendarViewport.width + 100);
        monthSlide.start();
    }
    function tasksForDate(day, month, year) {
        return pendingTasksByDate[dateKey(day, month, year)] || [];
    }

    anchors.fill: parent

    Component.onCompleted: {
        if (typeof GoogleService.acquire === "function")
            GoogleService.acquire();
        else if (GoogleService.authenticated)
            GoogleService.fetchAll();
    }
    Component.onDestruction: {
        if (typeof GoogleService.release === "function")
            GoogleService.release();
    }

    NumberAnimation {
        id: monthSlide

        duration: pendingMonthDirection === 0 ? 190 : 260
        easing.type: Easing.OutCubic
        property: "swipeOffset"
        target: calendarRoot

        onFinished: {
            if (pendingMonthDirection < 0)
                nextMonth();
            else if (pendingMonthDirection > 0)
                prevMonth();

            swipeOffset = 0;
            pendingMonthDirection = 0;
            isSwipingOut = false;
        }
    }
    DragHandler {
        id: calendarDrag

        enabled: !eventEditor.opened
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                if (monthSlide.running)
                    monthSlide.stop();
            } else if (!monthSlide.running) {
                var threshold = Math.min(calendarViewport.width * 0.18, 90);
                if (swipeOffset < -threshold) {
                    settleMonth(-1);
                } else if (swipeOffset > threshold) {
                    settleMonth(1);
                } else {
                    settleMonth(0);
                }
            }
        }
        onTranslationChanged: {
            if (active && !monthSlide.running)
                swipeOffset = Math.max(-(calendarViewport.width + 100), Math.min(calendarViewport.width + 100, translation.x));
        }
    }
    WheelHandler {
        enabled: !eventEditor.opened

        onWheel: event => {
            if (monthSlide.running)
                return;

            if (Math.abs(event.angleDelta.x) <= Math.abs(event.angleDelta.y)) {
                event.accepted = false;
                return;
            }
            if (event.angleDelta.x > 0)
                settleMonth(1);
            else if (event.angleDelta.x < 0)
                settleMonth(-1);
        }
    }
    Item {
        id: calendarViewport

        anchors.fill: parent
        clip: true
        visible: !calendarRoot.showEvents && !eventEditor.opened

        Row {
            height: parent.height
            spacing: 100
            x: -(calendarViewport.width + 100) + swipeOffset

            Repeater {
                model: 3

                Item {
                    id: monthPage

                    property int monthOffset: index - 1
                    property date viewDate: new Date(calendarRoot.currentYear, calendarRoot.currentMonth + monthOffset, 1)
                    property var viewDays: calendarRoot.daysForMonth(viewMonth, viewYear)
                    property int viewMonth: viewDate.getMonth()
                    property int viewYear: viewDate.getFullYear()

                    height: calendarViewport.height
                    width: calendarViewport.width

                    onViewDateChanged: Qt.callLater(function () {
                        monthFlickable.contentX = 0;
                        monthFlickable.contentY = 0;
                    })

                    Flickable {
                        id: monthFlickable

                        anchors.fill: parent
                        boundsBehavior: Flickable.StopAtBounds
                        clip: contentHeight > height
                        contentHeight: Math.max(height, monthCanvas.height)
                        contentWidth: width
                        flickableDirection: Flickable.VerticalFlick
                        interactive: contentHeight > height

                        Item {
                            id: monthCanvas

                            height: 580
                            width: monthFlickable.width
                            y: Math.max(0, (monthFlickable.contentHeight - height) / 2)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 40

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 26
                                    font.weight: Font.ExtraBold
                                    horizontalAlignment: Text.AlignHCenter
                                    text: calendarRoot.monthNames[monthPage.viewMonth] + " " + monthPage.viewYear
                                }
                                GridLayout {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    columnSpacing: 5
                                    columns: 7
                                    rowSpacing: 5

                                    Repeater {
                                        model: calendarRoot.weekDays

                                        Text {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            color: (index >= 5) ? Config.md3.tertiary : Config.md3.on_surface
                                            font.family: Config.fontName
                                            font.pixelSize: 17
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData
                                        }
                                    }
                                    Repeater {
                                        model: monthPage.viewDays

                                        Item {
                                            property var dayInfo: monthPage.viewDays[index]
                                            property bool isSelected: dayInfo.day === calendarRoot.selectedDay && dayInfo.month === calendarRoot.selectedMonth && dayInfo.year === calendarRoot.selectedYear
                                            property bool isToday: dayInfo.day === calendarRoot.todayDate && dayInfo.month === calendarRoot.todayMonth && dayInfo.year === calendarRoot.todayYear
                                            property bool isWeekend: index % 7 >= 5
                                            property string lunarDisplay: Lunar.getLunarDisplay(dayInfo.day, dayInfo.month, dayInfo.year)
                                            property bool lunarSpecial: Lunar.isLunarSpecial(dayInfo.day, dayInfo.month, dayInfo.year)

                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            implicitHeight: 75

                                            Rectangle {
                                                id: dayCircle

                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.top: parent.top
                                                anchors.topMargin: 16
                                                color: isToday ? Config.alpha(Config.md3.on_surface, 0.2) : (dayArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent")
                                                height: Math.min(50, Math.max(34, parent.width - 4))
                                                radius: height / 2
                                                width: height

                                                Column {
                                                    anchors.centerIn: parent
                                                    spacing: 1

                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        color: dayInfo.isCurrent ? (isWeekend ? Config.md3.tertiary : Config.md3.on_surface) : Config.alpha(Config.md3.on_surface_variant, 0.5)
                                                        font.family: Config.fontName
                                                        font.pixelSize: Math.min(18, Math.max(14, dayCircle.width * 0.36))
                                                        font.weight: dayInfo.isCurrent ? Font.Bold : Font.Normal
                                                        text: dayInfo.day
                                                    }
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        color: dayInfo.isCurrent ? ((isToday || lunarSpecial) ? Config.md3.tertiary : Config.md3.on_surface_variant) : Config.alpha(Config.md3.outline, 0.5)
                                                        font.family: Config.fontName
                                                        font.pixelSize: Math.min(12, Math.max(10, dayCircle.width * 0.24))
                                                        text: lunarDisplay
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.top: dayCircle.bottom
                                                anchors.topMargin: 5
                                                color: Config.md3.primary
                                                height: 5
                                                radius: 3
                                                visible: {
                                                    var dummyEvents = GoogleService.allEvents;
                                                    var dummyTasks = calendarRoot.pendingTasksByDate;
                                                    return GoogleService.hasEvents(dayInfo.day, dayInfo.month, dayInfo.year) || calendarRoot.tasksForDate(dayInfo.day, dayInfo.month, dayInfo.year).length > 0;
                                                }
                                                width: 5
                                            }
                                            MouseArea {
                                                id: dayArea

                                                anchors.fill: parent
                                                hoverEnabled: true

                                                onClicked: {
                                                    if (calendarRoot.isSwipingOut || Math.abs(calendarRoot.swipeOffset) > 4)
                                                        return;
                                                    calendarRoot.selectedDay = dayInfo.day;
                                                    calendarRoot.selectedMonth = dayInfo.month;
                                                    calendarRoot.selectedYear = dayInfo.year;
                                                    calendarRoot.showEvents = true;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Events Panel Overlay
    Rectangle {
        id: eventsPanel

        anchors.fill: parent
        color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.78 : 0.44)
        opacity: showEvents && !eventEditor.opened ? 1 : 0
        radius: 20
        visible: showEvents && !eventEditor.opened

        // Add transition for smooth open/close
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
        transform: Translate {
            y: showEvents && !eventEditor.opened ? 0 : 40

            Behavior on y {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutBack
                }
            }
        }

        DragHandler {
            enabled: !eventEditor.opened
            target: null
            xAxis.enabled: true
            yAxis.enabled: false

            onTranslationChanged: {
                if (translation.x > 150) {
                    showEvents = false;
                }
            }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.maximumWidth: parent.width - eventCountBadge.width - parent.spacing
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            text: qsTr("%1 %2").arg(calendarRoot.selectedDay).arg(calendarRoot.monthNames[calendarRoot.selectedMonth])
                        }
                        Rectangle {
                            id: eventCountBadge

                            Layout.preferredHeight: 26
                            Layout.preferredWidth: eventCountText.implicitWidth + 18
                            border.color: Config.alpha(Config.md3.primary, 0.2)
                            border.width: 1
                            color: Config.alpha(Config.md3.primary, 0.11)
                            radius: 9

                            Text {
                                id: eventCountText

                                anchors.centerIn: parent
                                color: Config.md3.primary
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                text: calendarRoot.scheduleCountText()
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.62)
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: calendarRoot.selectedYear
                    }
                }
                SettingsActionButton {
                    Layout.alignment: Qt.AlignVCenter
                    iconName: "list-add-symbolic"
                    iconOnly: true
                    primary: true
                    text: qsTr("Add event")

                    onClicked: {
                        if (GoogleService.requireAuthentication("calendar-add"))
                            eventEditor.openNew();
                    }
                }
            }
            ListView {
                id: eventList

                Layout.fillHeight: true
                Layout.fillWidth: true
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                model: eventsForSelectedDate
                spacing: 12

                delegate: Item {
                    readonly property color eventAccent: modelData.calendarColor || Config.md3.primary
                    required property var modelData

                    height: Math.max(106, eventContent.implicitHeight + 32)
                    width: ListView.view.width

                    Rectangle {
                        anchors.fill: parent
                        color: Config.md3.error
                        radius: 17
                        visible: cardContent.swipeX < -2

                        RowLayout {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.top: parent.top
                            spacing: 8

                            IconImage {
                                height: 20
                                layer.enabled: true
                                source: Quickshell.iconPath("user-trash-symbolic")
                                width: 20

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_error
                                }
                            }
                            Text {
                                color: Config.md3.on_error
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                text: qsTr("Delete")
                            }
                        }
                        MouseArea {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width: 100

                            onClicked: {
                                GoogleService.deleteEvent(modelData.calendarId, modelData.id);
                            }
                        }
                    }
                    Rectangle {
                        id: cardContent

                        property real swipeX: 0

                        border.color: Config.alpha(eventAccent, editArea.containsMouse ? 0.4 : 0.22)
                        border.width: 1
                        color: Qt.tint(editArea.pressed ? Config.alpha(Config.md3.primary, 0.16) : editArea.containsMouse ? Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.94 : 0.64) : Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.82 : 0.48), Config.alpha(Config.md3.error, Math.min(0.8, Math.abs(swipeX) / 100)))
                        height: parent.height
                        radius: 17
                        width: parent.width
                        x: swipeX

                        Behavior on swipeX {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        MouseArea {
                            id: editArea

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                if (cardContent.swipeX < 0) {
                                    cardContent.swipeX = 0;
                                    return;
                                }

                                eventEditor.openEvent(modelData);
                            }
                        }
                        DragHandler {
                            id: itemDrag

                            target: null
                            xAxis.enabled: true
                            yAxis.enabled: false

                            onActiveChanged: {
                                if (!active) {
                                    if (cardContent.swipeX < -80) {
                                        GoogleService.deleteEvent(modelData.calendarId, modelData.id);
                                        cardContent.swipeX = 0;
                                    } else {
                                        cardContent.swipeX = 0;
                                    }
                                }
                            }
                            onTranslationChanged: {
                                if (translation.x < 0) {
                                    cardContent.swipeX = translation.x;
                                }
                            }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 14
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.top: parent.top
                            anchors.topMargin: 14
                            color: eventAccent
                            radius: 3
                            width: 5
                        }
                        RowLayout {
                            id: eventContent

                            anchors.bottomMargin: 16
                            anchors.fill: parent
                            anchors.leftMargin: 25
                            anchors.rightMargin: 16
                            anchors.topMargin: 16
                            spacing: 14

                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                spacing: 7

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    text: modelData.title || qsTr("Untitled event")
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    IconImage {
                                        Layout.preferredHeight: 16
                                        Layout.preferredWidth: 16
                                        layer.enabled: true
                                        source: Quickshell.iconPath("x-office-calendar-symbolic")

                                        layer.effect: ColorOverlay {
                                            color: eventAccent
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: eventAccent
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        text: modelData.calendarName || qsTr("Calendar")
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: modelData.location !== undefined && modelData.location !== ""

                                    IconImage {
                                        Layout.preferredHeight: 16
                                        Layout.preferredWidth: 16
                                        layer.enabled: true
                                        source: Quickshell.iconPath("mark-location-symbolic")

                                        layer.effect: ColorOverlay {
                                            color: Config.alpha(Config.md3.on_surface, 0.62)
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.alpha(Config.md3.on_surface, 0.68)
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        text: modelData.location || ""
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: modelData.description !== undefined && modelData.description !== ""

                                    IconImage {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.preferredHeight: 16
                                        Layout.preferredWidth: 16
                                        layer.enabled: true
                                        source: Quickshell.iconPath("document-edit-symbolic")

                                        layer.effect: ColorOverlay {
                                            color: Config.alpha(Config.md3.on_surface, 0.62)
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.alpha(Config.md3.on_surface, 0.68)
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        maximumLineCount: 2
                                        text: modelData.description || ""
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                            Rectangle {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                Layout.preferredHeight: 36
                                Layout.preferredWidth: timeContent.implicitWidth + 22
                                border.color: Config.alpha(eventAccent, 0.3)
                                border.width: 1
                                color: Config.alpha(eventAccent, 0.14)
                                radius: 12

                                Row {
                                    id: timeContent

                                    anchors.centerIn: parent
                                    spacing: 6

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 16
                                        layer.enabled: true
                                        source: Quickshell.iconPath("appointment-soon-symbolic")
                                        width: 16

                                        layer.effect: ColorOverlay {
                                            color: eventAccent
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: eventAccent
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        text: {
                                            if (modelData.allDay)
                                                return qsTr("All day");
                                            var start = new Date(modelData.start);
                                            var end = new Date(modelData.end);
                                            var formatTime = date => String(date.getHours()).padStart(2, "0") + ":" + String(date.getMinutes()).padStart(2, "0");
                                            return formatTime(start) + " – " + formatTime(end);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                footer: Item {
                    height: visible ? taskFooterColumn.implicitHeight + (eventList.count > 0 ? 12 : 0) : 0
                    visible: calendarRoot.selectedTaskCount > 0
                    width: eventList.width

                    Column {
                        id: taskFooterColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: eventList.count > 0 ? 12 : 0
                        spacing: 12

                        Repeater {
                            model: calendarRoot.pendingTasksForSelectedDate

                            CalendarTaskCard {
                                required property var modelData

                                task: modelData
                                width: taskFooterColumn.width

                                onCompletionRequested: task => calendarRoot.completeTask(task)
                            }
                        }
                    }
                }

                ProductivityEmptyState {
                    actionText: qsTr("Add event")
                    actionVisible: true
                    anchors.centerIn: parent
                    description: qsTr("Your schedule is clear for this date")
                    iconName: "x-office-calendar-symbolic"
                    title: qsTr("No events today")
                    visible: calendarRoot.selectedItemCount === 0
                    width: Math.min(parent.width - 40, 320)

                    onActionTriggered: {
                        if (GoogleService.requireAuthentication("calendar-add"))
                            eventEditor.openNew();
                    }
                }
            }
        }
    }
    CalendarEventEditor {
        id: eventEditor

        popupBackdropHost: calendarRoot.popupBackdropHost
        popupBackdropRadius: calendarRoot.popupBackdropRadius
        selectedDay: calendarRoot.selectedDay
        selectedMonth: calendarRoot.selectedMonth
        selectedYear: calendarRoot.selectedYear
    }
    Connections {
        function onAuthenticationSucceeded(context) {
            if (context === "calendar-add")
                eventEditor.openNew();
        }

        target: GoogleService
    }
    GoogleAuthPanel {
        anchors.fill: parent
    }
}
