import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

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
    property string location: ""
    property bool opened: false
    property string startTime: "10:00"
    readonly property bool validTimeRange: allDay || minutesForTime(endTime) > minutesForTime(startTime)
    readonly property var writableCalendars: buildWritableCalendars()

    signal closed

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
        for (var i = 0; i < CalendarService.calendars.length; ++i) {
            if (String(CalendarService.calendars[i].id || "") === calendarId)
                return CalendarService.calendars[i].color || Config.md3.primary;
        }
        return Config.md3.primary;
    }
    function calendarName() {
        for (var i = 0; i < CalendarService.calendars.length; ++i) {
            if (String(CalendarService.calendars[i].id || "") === calendarId)
                return CalendarService.calendars[i].name || qsTr("Calendar");
        }
        return writableCalendars.length > 0 ? writableCalendars[0].name : qsTr("Calendar");
    }
    function close() {
        calendarPopupOpen = false;
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

        CalendarService.deleteEvent(calendarId, eventId);
        close();
    }
    function formatTime(value) {
        return String(value.getHours()).padStart(2, "0") + ":" + String(value.getMinutes()).padStart(2, "0");
    }
    function horizontalPosition(cardWidth) {
        var margin = 12;
        if (!anchorRect)
            return Math.max(margin, width - cardWidth - 18);

        var rightPosition = Number(anchorRect.x || 0) + Number(anchorRect.width || 0) + 12;
        if (rightPosition + cardWidth <= width - margin)
            return rightPosition;

        return Math.max(margin, Number(anchorRect.x || 0) - cardWidth - 12);
    }
    function minutesForTime(value) {
        var parts = String(value || "").split(":");
        if (parts.length !== 2)
            return 0;

        return Number(parts[0]) * 60 + Number(parts[1]);
    }
    function openEvent(eventData, editorAnchor) {
        if (!eventData)
            return;

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
        if (eventTitle.trim() === "" || !validTimeRange)
            return;

        if (calendarId === "")
            calendarId = defaultCalendarId();

        if (eventId !== "")
            CalendarService.updateEvent(calendarId, eventId, eventTitle.trim(), dateForApi(), startTime, endTime, allDay, location.trim(), description.trim());
        else
            CalendarService.createEvent(calendarId, eventTitle.trim(), dateForApi(), startTime, endTime, allDay, location.trim(), description.trim());
        close();
    }
    function syncTextFields() {
        titleField.text = eventTitle;
        locationField.text = location;
        descriptionField.text = description;
    }
    function timeForMinutes(value) {
        var minutes = Math.max(0, Math.min(23 * 60 + 59, Number(value || 0)));
        return String(Math.floor(minutes / 60)).padStart(2, "0") + ":" + String(minutes % 60).padStart(2, "0");
    }
    function verticalPosition(cardHeight) {
        var margin = 12;
        if (!anchorRect)
            return Math.max(margin, Math.min((height - cardHeight) / 2, height - cardHeight - margin));

        return Math.max(margin, Math.min(Number(anchorRect.y || 0) - 18, height - cardHeight - margin));
    }

    enabled: opened
    opacity: opened ? 1 : 0
    visible: opened || opacity > 0
    z: 40

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animationDuration(150)
            easing.type: Easing.OutQuad
        }
    }

    MouseArea {
        anchors.fill: parent

        onClicked: root.close()
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
        height: Math.min(620, Math.max(0, root.height - 24))
        radius: 24
        scale: root.opened ? 1 : 0.96
        transformOrigin: Item.Center
        width: Math.min(430, parent.width - 36)
        x: root.horizontalPosition(width)
        y: root.verticalPosition(height)

        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(190)
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
        }
        RowLayout {
            id: editorHeader

            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 14
            height: 52
            spacing: 10

            Rectangle {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                color: Config.alpha(root.calendarColor(), 0.16)
                radius: 13

                IconImage {
                    anchors.centerIn: parent
                    height: 21
                    layer.enabled: true
                    source: Quickshell.iconPath(root.eventId !== "" ? "document-edit-symbolic" : "appointment-new-symbolic")
                    width: 21

                    layer.effect: ColorOverlay {
                        color: root.calendarColor()
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    text: root.eventId !== "" ? qsTr("Edit event") : qsTr("New event")
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.eventDate.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                }
            }
            SettingsActionButton {
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                iconName: "window-close-symbolic"
                iconOnly: true
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
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: editorHeader.bottom
            anchors.topMargin: 14
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: Math.max(height, editorForm.implicitHeight + 8)
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

            ColumnLayout {
                id: editorForm

                spacing: 14
                width: formFlickable.width

                FormTextField {
                    id: titleField

                    Layout.fillWidth: true
                    inputFontPixelSize: 16
                    inputFontWeight: Font.DemiBold
                    label: qsTr("Title")
                    labelFontPixelSize: 13
                    labelFontWeight: Font.DemiBold
                    placeholder: qsTr("Add a title")

                    onAccepted: root.save()
                    onTextChanged: root.eventTitle = text
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        text: qsTr("Calendar")
                    }
                    Rectangle {
                        id: calendarField

                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        border.color: Config.alpha(Config.md3.on_surface, 0.07)
                        border.width: 1
                        color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.7 : 0.24)
                        opacity: root.eventId === "" ? 1 : 0.72
                        radius: 13

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                Layout.preferredHeight: 12
                                Layout.preferredWidth: 12
                                color: root.calendarColor()
                                radius: 6
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                text: root.calendarName()
                            }
                            IconImage {
                                Layout.preferredHeight: 16
                                Layout.preferredWidth: 16
                                layer.enabled: true
                                source: Quickshell.iconPath(root.eventId === "" ? "pan-down-symbolic" : "changes-prevent-symbolic")

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_surface_variant
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: root.eventId === "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: root.eventId === ""

                            onClicked: {
                                var position = calendarField.mapToItem(root, 0, calendarField.height + 6);
                                root.calendarPopupY = position.y;
                                root.calendarPopupOpen = true;
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.48)
                        font.family: Config.fontName
                        font.pixelSize: 11
                        text: qsTr("The calendar cannot be changed after an event is created.")
                        visible: root.eventId !== ""
                        wrapMode: Text.Wrap
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        text: qsTr("Date")
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        border.color: Config.alpha(Config.md3.on_surface, 0.07)
                        border.width: 1
                        color: dateMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : Config.alpha(Config.md3.surface, Config.lightTheme ? 0.7 : 0.24)
                        radius: 13

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(110)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 13
                            anchors.rightMargin: 12
                            spacing: 10

                            IconImage {
                                Layout.preferredHeight: 18
                                Layout.preferredWidth: 18
                                layer.enabled: true
                                source: Quickshell.iconPath("x-office-calendar-symbolic")

                                layer.effect: ColorOverlay {
                                    color: Config.md3.primary
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                text: root.eventDate.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                            }
                            IconImage {
                                Layout.preferredHeight: 16
                                Layout.preferredWidth: 16
                                layer.enabled: true
                                source: Quickshell.iconPath("pan-down-symbolic")

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_surface_variant
                                }
                            }
                        }
                        MouseArea {
                            id: dateMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                datePicker.selectedDate = root.dateForPicker();
                                datePicker.currentMonth = root.eventDate.getMonth();
                                datePicker.currentYear = root.eventDate.getFullYear();
                                datePicker.open();
                            }
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
                    Layout.preferredHeight: 56
                    activeFocusOnTab: true
                    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.7) : "transparent"
                    border.width: 1
                    color: allDayMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : Config.alpha(Config.md3.surface, Config.lightTheme ? 0.65 : 0.22)
                    radius: 13

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
                        anchors.leftMargin: 14
                        anchors.right: allDaySwitch.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            text: qsTr("All-day event")
                            width: parent.width
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface, 0.48)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 11
                            text: qsTr("Hide start and end times")
                            width: parent.width
                        }
                    }
                    ToggleSwitch {
                        id: allDaySwitch

                        Accessible.ignored: true
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.allDay
                        height: 22
                        interactive: false
                        width: 44
                    }
                    MouseArea {
                        id: allDayMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            allDayCard.forceActiveFocus();
                            allDayCard.requestToggle();
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: !root.allDay

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
                            spacing: 5

                            Text {
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                text: modelData.label
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                border.color: Config.alpha(Config.md3.on_surface, 0.07)
                                border.width: 1
                                color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.7 : 0.24)
                                radius: 13

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 13
                                    anchors.rightMargin: 11
                                    spacing: 8

                                    IconImage {
                                        Layout.preferredHeight: 17
                                        Layout.preferredWidth: 17
                                        layer.enabled: true
                                        source: Quickshell.iconPath("preferences-system-time-symbolic")

                                        layer.effect: ColorOverlay {
                                            color: Config.md3.primary
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        font.family: Config.fontName
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        text: modelData.value
                                    }
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
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    text: qsTr("End time must be later than start time.")
                    visible: !root.validTimeRange
                }
                FormTextField {
                    id: locationField

                    Layout.fillWidth: true
                    label: qsTr("Location")
                    labelFontPixelSize: 13
                    labelFontWeight: Font.DemiBold
                    placeholder: qsTr("Add a location")

                    onTextChanged: root.location = text
                }
                FormTextField {
                    id: descriptionField

                    Layout.fillWidth: true
                    fieldHeight: 92
                    label: qsTr("Description")
                    labelFontPixelSize: 13
                    labelFontWeight: Font.DemiBold
                    multiline: true
                    placeholder: qsTr("Add notes or details")

                    onTextChanged: root.description = text
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
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            height: 60
            spacing: 10

            Rectangle {
                Layout.preferredHeight: 44
                Layout.preferredWidth: 44
                color: deleteMouse.containsMouse ? Config.alpha(Config.md3.error, 0.16) : Config.alpha(Config.md3.error, 0.09)
                radius: 13
                visible: root.eventId !== "" && !root.eventReadOnly

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(110)
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 20
                    layer.enabled: true
                    source: Quickshell.iconPath("user-trash-symbolic")
                    width: 20

                    layer.effect: ColorOverlay {
                        color: Config.md3.error
                    }
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
                text: qsTr("Cancel")

                onClicked: root.close()
            }
            SettingsActionButton {
                enabled: !root.eventReadOnly && root.eventTitle.trim() !== "" && root.calendarId !== "" && root.validTimeRange && !CalendarService.eventActionBusy
                iconName: root.eventId !== "" ? "emblem-ok-symbolic" : "appointment-new-symbolic"
                primary: true
                text: root.eventId !== "" ? qsTr("Update") : qsTr("Create")

                onClicked: root.save()
            }
        }
    }
    SelectPopup {
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
