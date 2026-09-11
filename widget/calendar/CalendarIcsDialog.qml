import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property bool calendarPopupOpen: false
    property real calendarPopupY: 0
    property string errorMessage: ""
    property string filePath: ""
    property bool importing: false
    property bool opened: false
    readonly property var selectedCalendar: {
        var wanted = selectedCalendarId;
        for (var i = 0; i < writableCalendars.length; ++i) {
            if (String(writableCalendars[i].id) === wanted)
                return writableCalendars[i];
        }
        return writableCalendars.length > 0 ? writableCalendars[0] : null;
    }
    property string selectedCalendarId: ""
    property var summary: ({
            "fileName": "",
            "totalEvents": 0,
            "eventsPreview": []
        })
    readonly property var writableCalendars: {
        var list = [];
        var source = CalendarService.calendars || [];
        for (var i = 0; i < source.length; ++i) {
            if (source[i] && source[i].readOnly !== true)
                list.push(source[i]);
        }
        return list;
    }

    signal closed

    function accountForCalendar(cal) {
        if (!cal)
            return null;
        var accs = CalendarService.accounts || [];
        for (var i = 0; i < accs.length; ++i) {
            if (String(accs[i].id) === String(cal.accountId))
                return accs[i];
        }
        return null;
    }
    function calendarColor() {
        if (selectedCalendar && selectedCalendar.color)
            return selectedCalendar.color;
        return Config.md3.primary;
    }
    function close() {
        if (importing)
            return;
        calendarPopupOpen = false;
        opened = false;
        errorMessage = "";
        closed();
    }
    function formatEventDateTime(evt) {
        if (!evt)
            return "";
        var startDate = new Date(evt.start);
        if (isNaN(startDate.getTime()))
            return "";
        var dateStr = Qt.formatDate(startDate, "dd/MM");
        if (evt.allDay)
            return dateStr + " · " + qsTr("All day");
        var startTime = Qt.formatTime(startDate, "HH:mm");
        return dateStr + " · " + startTime;
    }
    function openWithSummary(path, data) {
        filePath = String(path || "");
        summary = data || {
            "fileName": path.split("/").pop(),
            "totalEvents": 0,
            "eventsPreview": []
        };
        errorMessage = "";
        importing = false;
        calendarPopupOpen = false;

        // Auto-select primary or first writable calendar
        var targetId = "";
        for (var i = 0; i < writableCalendars.length; ++i) {
            if (writableCalendars[i].primary) {
                targetId = String(writableCalendars[i].id);
                break;
            }
        }
        if (targetId === "" && writableCalendars.length > 0)
            targetId = String(writableCalendars[0].id);
        selectedCalendarId = targetId;

        opened = true;
    }
    function submitImport() {
        if (!selectedCalendar || filePath === "" || importing)
            return;
        importing = true;
        errorMessage = "";
        CalendarService.importIcs(selectedCalendar.id, filePath, (success, resultMsg) => {
            importing = false;
            if (success) {
                root.close();
            } else {
                errorMessage = String(resultMsg || qsTr("Could not import events from this file."));
            }
        });
    }

    enabled: opened
    opacity: opened ? 1 : 0
    visible: opened || opacity > 0
    z: 40

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animationDuration(160)
            easing.type: Easing.OutQuad
        }
    }

    WheelHandler {
        blocking: true
        target: null
    }

    // Modal backdrop - absorbs all clicks, hover and wheel events
    MouseArea {
        anchors.fill: parent
        enabled: root.opened && !root.importing
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

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.09)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.98 : 0.96)
        height: Math.min(580, Math.max(500, root.height - 40))
        radius: 26
        scale: root.opened ? 1 : 0.96
        transformOrigin: Item.Center
        width: Math.min(540, parent.width - 36)

        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(200)
                easing.type: Easing.OutCubic
            }
        }

        WheelHandler {
            blocking: true
            target: null
        }

        // Card mouse area - absorbs clicks, hover and wheel inside card
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onWheel: event => event.accepted = true
        }

        // ── 1. Header (Fixed) ──────────────────────────────────────
        RowLayout {
            id: editorHeader

            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: parent.top
            anchors.topMargin: 18
            height: 56
            spacing: 14

            Rectangle {
                Layout.preferredHeight: 44
                Layout.preferredWidth: 44
                color: Config.alpha(root.calendarColor(), 0.16)
                radius: 14

                IconImage {
                    anchors.centerIn: parent
                    height: 23
                    layer.enabled: true
                    source: Quickshell.iconPath("document-import-symbolic")
                    width: 23

                    layer.effect: ColorOverlay {
                        color: root.calendarColor()
                    }
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
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    text: qsTr("Import iCalendar")
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    elide: Text.ElideMiddle
                    font.family: Config.fontName
                    font.pixelSize: 13
                    text: root.summary.fileName || root.filePath.split("/").pop()
                }
            }
            SettingsActionButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                enabled: !root.importing
                iconName: "window-close-symbolic"
                iconOnly: true
                text: qsTr("Close")

                onClicked: root.close()
            }
        }
        Rectangle {
            id: headerDivider

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: editorHeader.bottom
            anchors.topMargin: 4
            color: Config.alpha(Config.md3.on_surface, 0.07)
            height: 1
        }

        // ── 2. Body Content (Fixed Layout, only event list scrolls) ──
        ColumnLayout {
            id: contentColumn

            anchors.bottom: footerDivider.top
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: headerDivider.bottom
            anchors.topMargin: 16
            spacing: 14

            // Target Calendar Field
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

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
                    Layout.preferredHeight: 52
                    border.color: Config.alpha(Config.md3.on_surface, 0.08)
                    border.width: 1
                    color: calMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : Config.alpha(Config.md3.surface, Config.lightTheme ? 0.7 : 0.24)
                    radius: 14

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(110)
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 12

                        Rectangle {
                            Layout.preferredHeight: 13
                            Layout.preferredWidth: 13
                            color: root.calendarColor()
                            radius: 6.5
                        }
                        Text {
                            Layout.maximumWidth: parent ? Math.max(140, parent.width * 0.48) : 200
                            Layout.preferredWidth: implicitWidth
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: root.selectedCalendar ? root.selectedCalendar.name : qsTr("No writable calendar")
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            readonly property var acc: root.accountForCalendar(root.selectedCalendar)

                            Layout.maximumWidth: parent ? Math.max(100, parent.width * 0.44) : 180
                            Layout.preferredWidth: parent ? Math.min(implicitWidth, parent.width * 0.44) : implicitWidth
                            color: Config.alpha(Config.md3.on_surface, 0.50)
                            elide: Text.ElideMiddle
                            font.family: Config.fontName
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignRight
                            text: acc ? (acc.email || acc.displayName) : ""
                            visible: text !== ""
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
                        id: calMouse

                        anchors.fill: parent
                        cursorShape: root.writableCalendars.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.writableCalendars.length > 1

                        onClicked: {
                            var position = calendarField.mapToItem(root, 0, calendarField.height + 6);
                            root.calendarPopupY = position.y;
                            root.calendarPopupOpen = true;
                        }
                    }
                }
            }

            // Summary Badge Row
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                border.color: Config.alpha(Config.md3.on_surface, 0.07)
                border.width: 1
                color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.7 : 0.24)
                radius: 14

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    spacing: 12

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
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: qsTr("%n event(s) ready to import", "", root.summary.totalEvents)
                    }
                    Rectangle {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: countTag.implicitWidth + 14
                        color: Config.alpha(Config.md3.primary, 0.14)
                        radius: 7

                        Text {
                            id: countTag

                            anchors.centerIn: parent
                            color: Config.md3.primary
                            font.family: Config.fontName
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            text: qsTr("%1 events").arg(root.summary.totalEvents)
                        }
                    }
                }
            }

            // Events Preview Section - Fills available vertical space & is the only scrollable list
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 6
                visible: root.summary.eventsPreview && root.summary.eventsPreview.length > 0

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        text: qsTr("Events preview")
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        color: Config.alpha(Config.md3.on_surface, 0.45)
                        font.family: Config.fontName
                        font.pixelSize: 11
                        text: root.summary.totalEvents > root.summary.eventsPreview.length ? qsTr("First %1 events").arg(root.summary.eventsPreview.length) : ""
                        visible: text !== ""
                    }
                }
                Rectangle {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.minimumHeight: 140
                    border.color: Config.alpha(Config.md3.on_surface, 0.07)
                    border.width: 1
                    clip: true
                    color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.7 : 0.24)
                    radius: 14

                    ListView {
                        id: eventPreviewList

                        anchors.fill: parent
                        anchors.margins: 7
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        model: root.summary.eventsPreview
                        spacing: 4

                        delegate: Item {
                            height: 34
                            width: ListView.view.width

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                Rectangle {
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: dateLabel.implicitWidth + 12
                                    color: Config.alpha(Config.md3.primary, 0.14)
                                    radius: 6

                                    Text {
                                        id: dateLabel

                                        anchors.centerIn: parent
                                        color: Config.md3.primary
                                        font.family: Config.fontName
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        text: root.formatEventDateTime(modelData)
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    text: modelData.title || qsTr("Untitled")
                                }
                                Text {
                                    Layout.maximumWidth: 130
                                    color: Config.alpha(Config.md3.on_surface, 0.42)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 11
                                    text: modelData.location || ""
                                    visible: text !== ""
                                }
                            }
                        }

                        WheelHandler {
                            blocking: true
                            target: null

                            onWheel: event => {
                                var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                                eventPreviewList.contentY = Math.max(0, Math.min(eventPreviewList.contentHeight - eventPreviewList.height, eventPreviewList.contentY - delta));
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            // Error text
            Text {
                Layout.fillWidth: true
                color: Config.md3.error
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.Medium
                text: root.errorMessage
                visible: root.errorMessage !== ""
                wrapMode: Text.Wrap
            }
        }

        // Footer Divider
        Rectangle {
            id: footerDivider

            anchors.bottom: editorFooter.top
            anchors.left: parent.left
            anchors.right: parent.right
            color: Config.alpha(Config.md3.on_surface, 0.07)
            height: 1
        }

        // ── 3. Footer Buttons (Fixed) ──────────────────────────────
        RowLayout {
            id: editorFooter

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.rightMargin: 24
            height: 64
            spacing: 12

            Item {
                Layout.fillWidth: true
            }
            SettingsActionButton {
                Layout.preferredHeight: 42
                Layout.preferredWidth: 94
                enabled: !root.importing
                text: qsTr("Cancel")

                onClicked: root.close()
            }
            SettingsActionButton {
                Layout.preferredHeight: 42
                Layout.preferredWidth: Math.max(150, implicitWidth + 28)
                enabled: root.selectedCalendar !== null && root.summary.totalEvents > 0 && !root.importing
                iconName: "document-import-symbolic"
                primary: true
                spinning: root.importing
                text: root.importing ? qsTr("Importing…") : qsTr("Import")

                onClicked: root.submitImport()
            }
        }
    }

    // Calendar Selection Popup
    SelectPopup {
        id: calendarPopup

        accentColor: root.calendarColor()
        anchors.fill: parent
        itemActive: item => item && String(item.value) === String(root.selectedCalendarId)
        model: {
            var options = [];
            for (var index = 0; index < root.writableCalendars.length; ++index) {
                var cal = root.writableCalendars[index];
                var acc = root.accountForCalendar(cal);
                var labelText = cal.name;
                if (acc && (acc.email || acc.displayName))
                    labelText += " (" + (acc.email || acc.displayName) + ")";
                options.push({
                    "label": labelText,
                    "value": String(cal.id),
                    "color": cal.color || Config.md3.primary
                });
            }
            return options;
        }
        opened: root.calendarPopupOpen
        popupWidth: Math.min(420, editorCard.width - 24)
        popupY: root.calendarPopupY
        rightMargin: Math.round((root.width - editorCard.width) / 2) + 24

        onDismissed: root.calendarPopupOpen = false
        onItemSelected: item => {
            root.selectedCalendarId = String(item.value);
            root.calendarPopupOpen = false;
        }
    }
}
