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

    // Calculate days for the current view
    property var daysData: {
        var firstDay = new Date(currentYear, currentMonth, 1).getDay(); // 0 is Sunday
        var startOffset = firstDay === 0 ? 6 : firstDay - 1; // Make Monday = 0
        var daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
        var daysInPrevMonth = new Date(currentYear, currentMonth, 0).getDate();

        var arr = [];
        // Previous month days
        for (var i = startOffset - 1; i >= 0; i--) {
            var prevD = daysInPrevMonth - i;
            var prevM = currentMonth === 0 ? 11 : currentMonth - 1;
            var prevY = currentMonth === 0 ? currentYear - 1 : currentYear;
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
                month: currentMonth,
                year: currentYear,
                isCurrent: true
            });
        }
        // Next month days
        var nextDays = 42 - arr.length;
        for (var k = 1; k <= nextDays; k++) {
            var nextM = currentMonth === 11 ? 0 : currentMonth + 1;
            var nextY = currentMonth === 11 ? currentYear + 1 : currentYear;
            arr.push({
                day: k,
                month: nextM,
                year: nextY,
                isCurrent: false
            });
        }
        return arr;
    }
    property var eventsForSelectedDate: {
        var dummy = GoogleService.allEvents;
        return GoogleService.getEventsForDate(selectedDay, selectedMonth, selectedYear);
    }
    property bool isSwipingOut: false
    property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    property int selectedDay: todayDate
    property int selectedMonth: todayMonth
    property int selectedYear: todayYear
    property bool showEvents: false
    property real swipeOffset: 0
    property int todayDate: new Date().getDate()
    property int todayMonth: new Date().getMonth()
    property int todayYear: new Date().getFullYear()
    property var weekDays: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

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

    anchors.fill: parent

    Behavior on swipeOffset {
        enabled: !calendarDrag.active && !isSwipingOut

        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: swipeTimer

        property int direction: 1

        interval: 150

        onTriggered: {
            isSwipingOut = true;
            if (direction === 1)
                prevMonth();
            else
                nextMonth();
            swipeOffset = -direction * calendarRoot.width;
            swipeInTimer.start();
        }
    }
    Timer {
        id: swipeInTimer

        interval: 20

        onTriggered: {
            isSwipingOut = false;
            swipeOffset = 0;
        }
    }
    DragHandler {
        id: calendarDrag

        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (!active && !isSwipingOut && !swipeTimer.running) {
                if (swipeOffset < -50) {
                    swipeOffset = -calendarRoot.width;
                    swipeTimer.direction = -1;
                    swipeTimer.start();
                } else if (swipeOffset > 50) {
                    swipeOffset = calendarRoot.width;
                    swipeTimer.direction = 1;
                    swipeTimer.start();
                } else {
                    swipeOffset = 0;
                }
            }
        }
        onTranslationChanged: {
            if (!isSwipingOut) {
                swipeOffset = translation.x;
            }
        }
    }
    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
                prevMonth();
            } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
                nextMonth();
            }
        }
    }
    AnimatedFireflies {
        anchors.fill: parent
        color: Config.md3.tertiary
        running: calendarRoot.visible
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 40

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 26
                font.weight: Font.ExtraBold
                horizontalAlignment: Text.AlignHCenter
                text: monthNames[currentMonth] + " " + currentYear
            }
        }

        // Weekday Headers & Days Grid
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true

            GridLayout {
                columnSpacing: 5
                columns: 7
                rowSpacing: 5
                width: parent.width

                transform: Translate {
                    x: swipeOffset
                }

                Repeater {
                    model: weekDays

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        color: (index >= 5) ? Config.md3.tertiary : Config.md3.on_surface // Sat/Sun accent
                        font.family: Config.fontName
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                    }
                }

                // Days Grid
                Repeater {
                    model: daysData

                    Item {
                        property var dayInfo: daysData[index]
                        property bool isSelected: dayInfo.day === selectedDay && dayInfo.month === selectedMonth && dayInfo.year === selectedYear
                        property bool isToday: dayInfo.day === todayDate && dayInfo.month === todayMonth && dayInfo.year === todayYear
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
                            anchors.topMargin: 20
                            color: isToday ? Config.md3.surface_container_highest : (dayArea.containsMouse ? Config.md3.surface_container : "transparent")
                            height: 50
                            radius: 25
                            width: 50

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: dayInfo.isCurrent ? (isWeekend ? Config.md3.tertiary : Config.md3.on_surface) : Config.alpha(Config.md3.on_surface_variant, 0.5)
                                    font.family: Config.fontName
                                    font.pixelSize: 18
                                    font.weight: dayInfo.isCurrent ? Font.Bold : Font.Normal
                                    text: dayInfo.day
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: dayInfo.isCurrent ? ((isToday || lunarSpecial) ? Config.md3.tertiary : Config.md3.on_surface_variant) : Config.alpha(Config.md3.outline, 0.5)
                                    font.family: Config.fontName
                                    font.pixelSize: 12
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
                                var dummy = GoogleService.allEvents;
                                return GoogleService.hasEvents(dayInfo.day, dayInfo.month, dayInfo.year);
                            }
                            width: 5
                        }
                        MouseArea {
                            id: dayArea

                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                // Don't trigger click if we are swiping out
                                if (isSwipingOut)
                                    return;
                                selectedDay = dayInfo.day;
                                selectedMonth = dayInfo.month;
                                selectedYear = dayInfo.year;
                                showEvents = true;
                            }
                        }
                    }
                }
            } // End of GridLayout
        } // End of Item
    } // End of ColumnLayout

    // Events Panel Overlay
    Rectangle {
        id: eventsPanel

        anchors.fill: parent
        color: Config.md3.surface
        opacity: showEvents ? 1 : 0
        visible: showEvents || opacity > 0

        // Add transition for smooth open/close
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
        transform: Translate {
            y: showEvents ? 0 : 40

            Behavior on y {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutBack
                }
            }
        }

        DragHandler {
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
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                // Back button removed, using swipe instead
                Item {
                    height: 30
                    width: 30
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    text: "Events for " + selectedDay + " " + monthNames[selectedMonth] + " " + selectedYear
                }

                // Add button
                Rectangle {
                    color: addArea.containsMouse ? Config.md3.surface_container_highest : Config.md3.surface_container_high
                    height: 30
                    radius: 15
                    width: 30

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.on_surface_variant
                        font.pixelSize: 16
                        text: "+"
                    }
                    MouseArea {
                        id: addArea

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            if (GoogleService.requireAuthentication("calendar-add"))
                                eventEditor.openNew();
                        }
                    }
                }
            }

            // Events list
            ListView {
                Layout.fillHeight: true
                Layout.fillWidth: true
                clip: true
                model: eventsForSelectedDate
                spacing: 8

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                    visible: false
                }
                delegate: Item {
                    height: Math.max(76, eventContent.implicitHeight + 40)
                    width: ListView.view.width

                    // Background for Delete Action
                    Rectangle {
                        anchors.fill: parent
                        color: Config.md3.error
                        radius: 20
                        visible: cardContent.swipeX < -2

                        RowLayout {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.top: parent.top
                            spacing: 8

                            IconImage {
                                height: 18
                                layer.enabled: true
                                source: Quickshell.iconPath("user-trash-symbolic")
                                width: 18

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_error
                                }
                            }
                            Text {
                                color: Config.md3.on_error
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                text: "Delete"
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

                    // Main Foreground Card
                    Rectangle {
                        id: cardContent

                        property real swipeX: 0

                        color: Qt.tint(Config.md3.surface_container, Config.alpha(Config.md3.error, Math.min(0.8, Math.abs(swipeX) / 100)))
                        height: parent.height
                        radius: 20
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

                            onClicked: {
                                if (cardContent.swipeX < 0) {
                                    cardContent.swipeX = 0; // Snap back if swiped
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
                                        // Swipe-to-dismiss: trigger delete immediately
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
                        RowLayout {
                            id: eventContent

                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    text: modelData.title
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.outline
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    text: "📍 " + (modelData.location || "")
                                    visible: modelData.location !== undefined && modelData.location !== ""
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.outline
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    maximumLineCount: 2
                                    text: "📝 " + (modelData.description || "")
                                    visible: modelData.description !== undefined && modelData.description !== ""
                                    wrapMode: Text.Wrap
                                }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                Layout.preferredWidth: 138
                                spacing: 7

                                Rectangle {
                                    Layout.alignment: Qt.AlignRight
                                    color: Config.alpha(Config.md3.primary, 0.92)
                                    implicitHeight: 28
                                    implicitWidth: timeText.implicitWidth + 18
                                    radius: 8

                                    Text {
                                        id: timeText

                                        anchors.centerIn: parent
                                        color: Config.md3.background
                                        font.family: Config.fontName
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        text: {
                                            if (modelData.allDay)
                                                return "All Day";
                                            var s = new Date(modelData.start);
                                            var e = new Date(modelData.end);
                                            var fmt = d => String(d.getHours()).padStart(2, '0') + ":" + String(d.getMinutes()).padStart(2, '0');
                                            return fmt(s) + " - " + fmt(e);
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: modelData.calendarColor || Config.md3.secondary
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData.calendarName || ""
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.outline
                    font.family: Config.fontName
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    text: "No events"
                    visible: parent.count === 0
                }
            }
        }
    }
    CalendarEventEditor {
        id: eventEditor

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
