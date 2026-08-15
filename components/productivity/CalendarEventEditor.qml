import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../"
import "../../service"
import ".."

Rectangle {
    id: root

    property bool allDay: false
    property string calendarId: ""
    property bool calendarPopupOpen: false
    property real calendarPopupY: 0
    property string description: ""
    property string endTime: "11:00"
    property string eventId: ""
    property string eventTitle: ""
    property string location: ""
    property bool opened: false
    property int selectedDay: 1
    property int selectedMonth: 0
    property int selectedYear: 1970
    property string startTime: "10:00"
    readonly property bool timePickerOpen: timePicker.opened

    signal closed

    function calendarName() {
        for (var i = 0; i < GoogleService.calendars.length; ++i) {
            if (GoogleService.calendars[i].id === calendarId)
                return GoogleService.calendars[i].name;
        }
        return GoogleService.calendars.length > 0 ? GoogleService.calendars[0].name : "Calendar";
    }
    function close() {
        calendarPopupOpen = false;
        opened = false;
        closed();
    }
    function formatTime(date) {
        return String(date.getHours()).padStart(2, "0") + ":" + String(date.getMinutes()).padStart(2, "0");
    }
    function openEvent(event) {
        eventId = event.id || "";
        calendarId = event.calendarId || "";
        eventTitle = event.title || "";
        description = event.description || "";
        location = event.location || "";
        allDay = event.allDay || false;
        if (!allDay) {
            var start = new Date(event.start);
            var end = new Date(event.end);
            startTime = formatTime(start);
            endTime = formatTime(end);
        } else {
            startTime = "10:00";
            endTime = "11:00";
        }
        opened = true;
    }
    function openNew() {
        reset();
        opened = true;
    }
    function reset() {
        eventId = "";
        calendarId = GoogleService.calendars.length > 0 ? GoogleService.calendars[0].id : "";
        eventTitle = "";
        allDay = false;
        startTime = "10:00";
        endTime = "11:00";
        location = "";
        description = "";
    }
    function save() {
        if (eventTitle.trim() === "")
            return;
        if (calendarId === "" && GoogleService.calendars.length > 0)
            calendarId = GoogleService.calendars[0].id;
        var date = selectedYear + "-" + String(selectedMonth + 1).padStart(2, "0") + "-" + String(selectedDay).padStart(2, "0");
        if (eventId !== "") {
            GoogleService.updateEvent(calendarId, eventId, eventTitle, date, startTime, endTime, allDay, location, description);
        } else {
            GoogleService.createEvent(calendarId, eventTitle, date, startTime, endTime, allDay, location, description);
        }
        close();
    }

    anchors.fill: parent
    color: Config.md3.surface
    opacity: opened ? 1 : 0
    visible: opened || opacity > 0
    z: 20

    Behavior on opacity {
        NumberAnimation {
            duration: 200
        }
    }
    transform: Translate {
        y: root.opened ? 0 : 40

        Behavior on y {
            NumberAnimation {
                duration: 350
                easing.type: Easing.OutBack
            }
        }
    }

    DragHandler {
        enabled: !root.timePickerOpen
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onTranslationChanged: {
            if (translation.x > 150)
                root.close();
        }
    }
    Flickable {
        anchors.bottom: saveButton.top
        anchors.left: parent.left
        anchors.margins: 12
        anchors.right: parent.right
        anchors.top: parent.top
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: form.implicitHeight
        contentWidth: width
        interactive: !root.timePickerOpen && contentHeight > height

        ColumnLayout {
            id: form

            spacing: 15
            width: parent.width

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                text: root.eventId !== "" ? "Edit Event" : "New Event"
            }
            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: Font.Bold
                text: "Calendar"
            }
            Rectangle {
                id: calendarButton

                Layout.fillWidth: true
                border.color: Config.alpha(Config.md3.on_surface, calendarMouse.containsMouse ? 0.12 : 0.06)
                border.width: 1
                color: calendarMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container
                height: 50
                radius: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        text: root.calendarName()
                    }
                    Text {
                        color: Config.md3.on_surface_variant
                        font.pixelSize: 18
                        text: "⌄"
                    }
                }
                MouseArea {
                    id: calendarMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        var point = calendarButton.mapToItem(root, 0, calendarButton.height + 8);
                        root.calendarPopupY = point.y;
                        root.calendarPopupOpen = !root.calendarPopupOpen;
                    }
                }
            }
            FormTextField {
                Layout.fillWidth: true
                label: "Title"
                placeholder: "Event title..."
                text: root.eventTitle

                onTextChanged: root.eventTitle = text
            }
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: "All Day Event"
                }
                ToggleSwitch {
                    checked: root.allDay

                    onToggled: checked => root.allDay = checked
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 15
                visible: !root.allDay

                Repeater {
                    model: [
                        {
                            label: "Start",
                            value: root.startTime,
                            target: "start"
                        },
                        {
                            label: "End",
                            value: root.endTime,
                            target: "end"
                        }
                    ]

                    delegate: ColumnLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        spacing: 4

                        Text {
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            text: modelData.label
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            border.color: Config.alpha(Config.md3.on_surface, 0.06)
                            border.width: 1
                            color: Config.md3.surface_container
                            height: 50
                            radius: 12

                            Text {
                                anchors.centerIn: parent
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                text: modelData.value
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    timePicker.targetField = modelData.target;
                                    timePicker.openWith(modelData.value);
                                }
                            }
                        }
                    }
                }
            }
            FormTextField {
                Layout.fillWidth: true
                label: "Location"
                placeholder: "Location..."
                text: root.location

                onTextChanged: root.location = text
            }
            FormTextField {
                Layout.fillWidth: true
                label: "Description"
                multiline: true
                placeholder: "Description..."
                text: root.description

                onTextChanged: root.description = text
            }
        }
    }
    Rectangle {
        id: saveButton

        readonly property bool ready: root.eventTitle.trim() !== ""

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 12
        anchors.right: parent.right
        color: ready ? (saveMouse.pressed ? Qt.darker(Config.md3.primary, 1.2) : saveMouse.containsMouse ? Qt.lighter(Config.md3.primary, 1.1) : Config.md3.primary) : Config.alpha(Config.md3.on_surface, 0.10)
        height: 50
        radius: 12

        Text {
            anchors.centerIn: parent
            color: saveButton.ready ? Config.md3.on_primary : Config.md3.outline
            font.family: Config.fontName
            font.pixelSize: 16
            font.weight: Font.Bold
            text: root.eventId !== "" ? "Update Event" : "Save Event"
        }
        MouseArea {
            id: saveMouse

            anchors.fill: parent
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: saveButton.ready
            hoverEnabled: true

            onClicked: root.save()
        }
    }
    SelectPopup {
        anchors.fill: parent
        itemActive: calendar => calendar && calendar.id === root.calendarId
        itemLabel: calendar => calendar ? calendar.name : ""
        model: GoogleService.calendars
        opened: root.calendarPopupOpen
        popupY: root.calendarPopupY

        onDismissed: root.calendarPopupOpen = false
        onItemSelected: calendar => {
            root.calendarId = calendar.id;
            root.calendarPopupOpen = false;
        }
    }
    ClockTimePicker {
        id: timePicker

        property string targetField: ""

        placementParent: root

        onConfirmed: (hours, minutes) => {
            var value = hours + ":" + minutes;
            if (targetField === "start")
                root.startTime = value;
            else
                root.endTime = value;
        }
    }
}
