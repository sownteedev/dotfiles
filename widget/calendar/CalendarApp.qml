import "../../"
import "../../components"
import "../../service"
import "."
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

FloatingWindow {
    id: root

    property bool active: false
    property bool blurActive: false
    readonly property bool compactHeader: width < 1120
    readonly property var hiddenCalendars: buildHiddenCalendars()
    property bool pendingCreateAfterConnect: false
    property date pendingCreateDate: new Date()
    property int pendingCreateEndMinutes: 11 * 60
    property int pendingCreateStartMinutes: 10 * 60
    property var pendingEditorAnchor: null
    property date selectedDate: new Date()
    property bool serviceAcquired: false
    readonly property real sidebarContentWidth: width < 1160 ? 244 : 280
    property bool sidebarExpanded: true
    property real sidebarReveal: sidebarExpanded ? 1 : 0
    readonly property real sidebarWidth: sidebarContentWidth * sidebarReveal
    property string viewMode: "week"
    property date weekStart: beginningOfWeek(new Date())

    signal dismissed

    function acquireCalendarService() {
        if (serviceAcquired)
            return;
        CalendarService.acquire();
        serviceAcquired = true;
    }
    function addDays(value, amount) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + amount);
    }
    function beginningOfWeek(value) {
        var day = value.getDay();
        var offset = day === 0 ? -6 : 1 - day;
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + offset);
    }
    function buildHiddenCalendars() {
        var result = {};
        var calendars = CalendarService.calendars || [];
        for (var index = 0; index < calendars.length; ++index) {
            if (calendars[index] && calendars[index].visible === false)
                result[String(calendars[index].id || "")] = true;
        }
        return result;
    }
    function clearCurrentViewSelection() {
        if (calendarViewLoader.status !== Loader.Ready || !calendarViewLoader.item)
            return;
        if (typeof calendarViewLoader.item.clearSelection === "function")
            calendarViewLoader.item.clearSelection();
    }
    function closeCalendar() {
        if (!active)
            return;
        blurAcquireTimer.stop();
        blurActive = false;
        closeOwnedOverlays();
        active = false;
        visible = false;
        releaseCalendarService();
        dismissed();
    }
    function closeOwnedOverlays() {
        editorUnloadTimer.stop();
        eventEditorLoader.active = false;
        clearCurrentViewSelection();
        accountDialog.opened = false;
        pendingCreateAfterConnect = false;
    }
    function createAtSelectedTime() {
        var current = new Date();
        var startMinutes = Math.ceil((current.getHours() * 60 + current.getMinutes()) / 30) * 30;
        startMinutes = Math.max(0, Math.min(23 * 60, startMinutes));
        requestCreate(selectedDate, startMinutes, Math.min(23 * 60 + 59, startMinutes + 60), null);
    }
    function createFromMonth(value, anchorRect) {
        var current = new Date();
        var startMinutes = 9 * 60;
        if (isSameDay(value, current))
            startMinutes = Math.ceil((current.getHours() * 60 + current.getMinutes()) / 30) * 30;
        startMinutes = Math.max(0, Math.min(23 * 60, startMinutes));
        requestCreate(value, startMinutes, Math.min(23 * 60 + 59, startMinutes + 60), editorAnchorFromView(anchorRect));
    }
    function editorAnchorFromView(anchorRect) {
        if (!anchorRect || calendarViewLoader.status !== Loader.Ready || !calendarViewLoader.item)
            return null;
        var position = calendarViewLoader.item.mapToItem(panel, Number(anchorRect.x || 0), Number(anchorRect.y || 0));
        return {
            "x": position.x,
            "y": position.y,
            "width": Number(anchorRect.width || 0),
            "height": Number(anchorRect.height || 0)
        };
    }
    function formatPeriodRange() {
        if (viewMode === "month")
            return selectedDate.toLocaleString(Qt.locale(), "MMMM yyyy");
        return formatWeekRange();
    }
    function formatSyncStatus() {
        if (CalendarService.isLoading)
            return qsTr("Syncing all…");
        var updated = CalendarService.lastEventsUpdated;
        if (!updated || isNaN(updated.getTime()))
            return CalendarService.authenticated ? qsTr("Sync all") : qsTr("No accounts");
        return qsTr("Synced %1").arg(Qt.formatTime(updated, "HH:mm"));
    }
    function formatWeekRange() {
        var end = addDays(weekStart, 6);
        if (weekStart.getFullYear() !== end.getFullYear())
            return Qt.formatDate(weekStart, "MMM d, yyyy") + " – " + Qt.formatDate(end, "MMM d, yyyy");
        if (weekStart.getMonth() !== end.getMonth())
            return Qt.formatDate(weekStart, "MMM d") + " – " + Qt.formatDate(end, "MMM d, yyyy");
        return Qt.formatDate(weekStart, "MMMM d") + "–" + Qt.formatDate(end, "d, yyyy");
    }
    function hasWritableCalendar() {
        var calendars = CalendarService.calendars || [];
        for (var index = 0; index < calendars.length; ++index) {
            if (calendars[index] && calendars[index].readOnly !== true)
                return true;
        }
        return false;
    }
    function isSameDay(first, second) {
        return first.getDate() === second.getDate() && first.getMonth() === second.getMonth() && first.getFullYear() === second.getFullYear();
    }
    function openCalendar() {
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;
        blurAcquireTimer.stop();
        blurActive = false;
        visible = true;
        active = true;
        acquireCalendarService();
        blurAcquireTimer.restart();
        panel.forceActiveFocus();
    }
    function openEventEditor(eventData, anchorRect) {
        editorUnloadTimer.stop();
        eventEditorLoader.active = true;
        Qt.callLater(function () {
            if (eventEditorLoader.status === Loader.Ready)
                eventEditorLoader.item.openEvent(eventData, anchorRect);
        });
    }
    function openNewEditor(value, startMinutes, endMinutes, anchorRect) {
        editorUnloadTimer.stop();
        eventEditorLoader.active = true;
        Qt.callLater(function () {
            if (eventEditorLoader.status === Loader.Ready)
                eventEditorLoader.item.openNew(value, startMinutes, endMinutes, anchorRect);
        });
    }
    function releaseCalendarService() {
        if (!serviceAcquired)
            return;
        CalendarService.release();
        serviceAcquired = false;
    }
    function requestCreate(value, startMinutes, endMinutes, anchorRect) {
        pendingCreateDate = new Date(value.getFullYear(), value.getMonth(), value.getDate());
        pendingCreateStartMinutes = Math.max(0, Math.min(23 * 60 + 45, Number(startMinutes || 0)));
        pendingCreateEndMinutes = Math.max(pendingCreateStartMinutes + 1, Math.min(23 * 60 + 59, Number(endMinutes || pendingCreateStartMinutes + 60)));
        pendingEditorAnchor = anchorRect || null;
        selectedDate = pendingCreateDate;
        if (!CalendarService.authenticated || !hasWritableCalendar()) {
            pendingCreateAfterConnect = true;
            accountDialog.open();
            return;
        }
        openNewEditor(pendingCreateDate, pendingCreateStartMinutes, pendingCreateEndMinutes, pendingEditorAnchor);
    }
    function scrollCurrentWeekToWorkingHours() {
        if (viewMode !== "week" || calendarViewLoader.status !== Loader.Ready || !calendarViewLoader.item)
            return;
        if (typeof calendarViewLoader.item.scrollToWorkingHours === "function")
            calendarViewLoader.item.scrollToWorkingHours();
    }
    function selectDate(value) {
        selectedDate = new Date(value.getFullYear(), value.getMonth(), value.getDate());
        weekStart = beginningOfWeek(selectedDate);
    }
    function shiftPeriod(amount) {
        if (viewMode === "month") {
            selectedDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth() + amount, 1);
            weekStart = beginningOfWeek(selectedDate);
            return;
        }
        weekStart = addDays(weekStart, amount * 7);
        selectedDate = addDays(selectedDate, amount * 7);
    }
    function showToday() {
        selectedDate = new Date();
        weekStart = beginningOfWeek(selectedDate);
        scrollCurrentWeekToWorkingHours();
    }
    function toggleCalendar(calendarId, visible) {
        CalendarService.setCalendarVisible(calendarId, visible);
    }
    function toggleViewMode() {
        clearCurrentViewSelection();
        viewMode = viewMode === "week" ? "month" : "week";
    }

    color: "transparent"
    implicitHeight: 900
    implicitWidth: 1440
    minimumSize: Qt.size(840, 560)
    title: "SownteeShell Calendar"
    visible: false

    BackgroundEffect.blurRegion: Region {
        item: Config.shellBlurSettingsEnabled && root.blurActive ? panelBlurRegion : null
        radius: panel.radius
    }
    Behavior on sidebarReveal {
        NumberAnimation {
            duration: Config.animationDuration(220)
            easing.type: root.sidebarExpanded ? Easing.OutCubic : Easing.InCubic
        }
    }

    Component.onDestruction: releaseCalendarService()
    onClosed: {
        if (!root.active)
            return;
        blurAcquireTimer.stop();
        root.blurActive = false;
        root.closeOwnedOverlays();
        root.active = false;
        root.visible = false;
        root.releaseCalendarService();
        root.dismissed();
    }

    Timer {
        id: blurAcquireTimer

        interval: Math.max(1, Config.animationDuration(40))
        repeat: false

        onTriggered: {
            if (root.active)
                root.blurActive = true;
        }
    }
    Timer {
        id: editorUnloadTimer

        interval: Math.max(1, Config.animationDuration(180))
        repeat: false

        onTriggered: {
            if (!eventEditorLoader.item || !eventEditorLoader.item.opened)
                eventEditorLoader.active = false;
        }
    }
    Connections {
        function onAccountAdded(accountId) {
            if (root.pendingCreateAfterConnect) {
                root.pendingCreateAfterConnect = false;
                root.openNewEditor(root.pendingCreateDate, root.pendingCreateStartMinutes, root.pendingCreateEndMinutes, root.pendingEditorAnchor);
            }
        }

        target: CalendarService
    }
    Item {
        id: panelBlurRegion

        anchors.fill: panel
    }
    Item {
        id: resizeHandles

        readonly property int cornerSize: 14
        readonly property int edgeSize: 7

        anchors.fill: parent
        enabled: root.active && !root.maximized
        z: 100

        MouseArea {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: resizeHandles.cornerSize
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: resizeHandles.cornerSize
            cursorShape: Qt.SizeHorCursor
            width: resizeHandles.edgeSize

            onPressed: root.startSystemResize(Qt.LeftEdge)
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: resizeHandles.cornerSize
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: resizeHandles.cornerSize
            cursorShape: Qt.SizeHorCursor
            width: resizeHandles.edgeSize

            onPressed: root.startSystemResize(Qt.RightEdge)
        }
        MouseArea {
            anchors.left: parent.left
            anchors.leftMargin: resizeHandles.cornerSize
            anchors.right: parent.right
            anchors.rightMargin: resizeHandles.cornerSize
            anchors.top: parent.top
            cursorShape: Qt.SizeVerCursor
            height: resizeHandles.edgeSize

            onPressed: root.startSystemResize(Qt.TopEdge)
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: resizeHandles.cornerSize
            anchors.right: parent.right
            anchors.rightMargin: resizeHandles.cornerSize
            cursorShape: Qt.SizeVerCursor
            height: resizeHandles.edgeSize

            onPressed: root.startSystemResize(Qt.BottomEdge)
        }
        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            cursorShape: Qt.SizeFDiagCursor
            height: resizeHandles.cornerSize
            width: resizeHandles.cornerSize

            onPressed: root.startSystemResize(Qt.LeftEdge | Qt.TopEdge)
        }
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            cursorShape: Qt.SizeBDiagCursor
            height: resizeHandles.cornerSize
            width: resizeHandles.cornerSize

            onPressed: root.startSystemResize(Qt.RightEdge | Qt.TopEdge)
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            cursorShape: Qt.SizeBDiagCursor
            height: resizeHandles.cornerSize
            width: resizeHandles.cornerSize

            onPressed: root.startSystemResize(Qt.LeftEdge | Qt.BottomEdge)
        }
        MouseArea {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            cursorShape: Qt.SizeFDiagCursor
            height: resizeHandles.cornerSize
            width: resizeHandles.cornerSize

            onPressed: root.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
        }
    }
    Rectangle {
        id: panel

        anchors.fill: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.08)
        border.width: 1
        clip: true
        color: Config.shellBlurSettingsEnabled ? Config.alpha(Config.md3.background, Config.lightTheme ? Config.shellBlurPanelOpacityLight : Config.shellBlurPanelOpacityDark) : Config.md3.background
        focus: true
        opacity: root.active ? 1 : 0
        radius: root.maximized ? 0 : 26
        scale: root.active ? 1 : 0.975

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(170)
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(210)
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;
            if (eventEditorLoader.item && eventEditorLoader.item.opened)
                eventEditorLoader.item.close();
            else if (accountDialog.opened)
                accountDialog.close();
            else
                root.closeCalendar();
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent

            onClicked: panel.forceActiveFocus(Qt.MouseFocusReason)
        }
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                id: appHeader

                Layout.fillWidth: true
                Layout.preferredHeight: 74

                MouseArea {
                    acceptedButtons: Qt.LeftButton
                    anchors.fill: parent

                    onDoubleClicked: root.maximized = !root.maximized
                    onPressed: root.startSystemMove()
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: root.compactHeader ? 7 : 10

                    SettingsActionButton {
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 42
                        iconName: root.sidebarExpanded ? "sidebar-collapse-left" : "sidebar-expand-right"
                        iconOnly: true
                        text: root.sidebarExpanded ? qsTr("Hide sidebar") : qsTr("Show sidebar")

                        onClicked: root.sidebarExpanded = !root.sidebarExpanded
                    }
                    Rectangle {
                        Layout.leftMargin: root.compactHeader ? 0 : 2
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 42
                        color: Config.alpha(Config.md3.primary, 0.14)
                        radius: 14

                        Column {
                            anchors.centerIn: parent
                            spacing: -1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Config.md3.primary
                                font.capitalization: Font.AllUppercase
                                font.family: Config.fontName
                                font.pixelSize: 8
                                font.weight: Font.Black
                                text: Qt.formatDate(new Date(), "MMM")
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Config.md3.primary
                                font.family: Config.fontName
                                font.pixelSize: 17
                                font.weight: Font.Black
                                text: new Date().getDate()
                            }
                        }
                    }
                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        text: qsTr("Calendar")
                        visible: !root.compactHeader
                    }
                    Rectangle {
                        Layout.leftMargin: root.compactHeader ? 1 : 5
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: 1
                        color: Config.alpha(Config.md3.on_surface, 0.09)
                    }
                    SettingsActionButton {
                        Layout.preferredHeight: 40
                        text: qsTr("Today")

                        onClicked: root.showToday()
                    }
                    SettingsActionButton {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: 40
                        iconName: "go-previous-symbolic"
                        iconOnly: true
                        text: root.viewMode === "month" ? qsTr("Previous month") : qsTr("Previous week")

                        onClicked: root.shiftPeriod(-1)
                    }
                    SettingsActionButton {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: 40
                        iconName: "go-next-symbolic"
                        iconOnly: true
                        text: root.viewMode === "month" ? qsTr("Next month") : qsTr("Next week")

                        onClicked: root.shiftPeriod(1)
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 100
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: root.compactHeader ? 16 : 18
                        font.weight: Font.DemiBold
                        text: root.formatPeriodRange()
                    }
                    SettingsActionButton {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: root.compactHeader ? 40 : implicitWidth
                        enabled: CalendarService.authenticated
                        iconName: "view-refresh-symbolic"
                        iconOnly: root.compactHeader
                        primary: CalendarService.isLoading
                        text: root.formatSyncStatus()

                        onClicked: {
                            if (!CalendarService.isLoading)
                                CalendarService.syncNow("");
                        }
                    }
                    SettingsActionButton {
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: root.compactHeader ? 38 : implicitWidth
                        iconName: root.viewMode === "month" ? "view-calendar-month" : "view-calendar-week"
                        iconOnly: root.compactHeader
                        text: root.viewMode === "month" ? qsTr("Month") : qsTr("Week")

                        onClicked: root.toggleViewMode()
                    }
                    SettingsActionButton {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: 40
                        iconName: root.maximized ? "window-restore-symbolic" : "window-maximize-symbolic"
                        iconOnly: true
                        text: root.maximized ? qsTr("Restore") : qsTr("Maximize")

                        onClicked: root.maximized = !root.maximized
                    }
                    SettingsActionButton {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: 40
                        iconName: "window-close-symbolic"
                        iconOnly: true
                        text: qsTr("Close")

                        onClicked: root.closeCalendar()
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    color: Config.alpha(Config.md3.on_surface, 0.07)
                    height: 1
                    width: parent.width
                }
            }
            RowLayout {
                Layout.bottomMargin: 10
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.leftMargin: 10 * (1 - root.sidebarReveal)
                Layout.rightMargin: 10
                Layout.topMargin: 10
                spacing: 6 * root.sidebarReveal

                Item {
                    Layout.fillHeight: true
                    Layout.preferredWidth: root.sidebarWidth
                    clip: true
                    visible: root.sidebarExpanded || root.sidebarReveal > 0

                    CalendarSidebar {
                        accounts: CalendarService.accounts
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.top: parent.top
                        calendars: CalendarService.calendars
                        errorMessage: CalendarService.lastError
                        selectedDate: root.selectedDate
                        syncingAccounts: CalendarService.syncingAccounts
                        weekStart: root.weekStart
                        width: root.sidebarContentWidth

                        onAccountRemoveRequested: accountId => CalendarService.removeAccount(accountId)
                        onAccountToggled: (accountId, visible) => CalendarService.setAccountVisible(accountId, visible)
                        onCalendarToggled: (calendarId, visible) => root.toggleCalendar(calendarId, visible)
                        onConnectRequested: accountDialog.open()
                        onCreateRequested: root.createAtSelectedTime()
                        onDateSelected: value => root.selectDate(value)
                    }
                }
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: root.sidebarReveal
                    color: Config.alpha(Config.md3.on_surface, 0.07)
                    opacity: root.sidebarReveal
                    visible: root.sidebarExpanded || root.sidebarReveal > 0
                }
                Loader {
                    id: calendarViewLoader

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    active: root.active
                    asynchronous: false
                    sourceComponent: root.viewMode === "month" ? monthViewComponent : weekViewComponent

                    onLoaded: {
                        if (root.viewMode === "week")
                            Qt.callLater(root.scrollCurrentWeekToWorkingHours);
                    }
                }
            }
        }
        Component {
            id: weekViewComponent

            CalendarWeekView {
                available: CalendarService.authenticated
                events: CalendarService.allEvents
                hiddenCalendars: root.hiddenCalendars
                loading: CalendarService.isLoading
                selectedDate: root.selectedDate
                weekStart: root.weekStart

                onDaySelected: value => root.selectDate(value)
                onEventClicked: (eventData, anchorRect) => root.openEventEditor(eventData, root.editorAnchorFromView(anchorRect))
                onRangeSelected: (value, startMinutes, endMinutes, anchorRect) => root.requestCreate(value, startMinutes, endMinutes, root.editorAnchorFromView(anchorRect))
            }
        }
        Component {
            id: monthViewComponent

            CalendarMonthView {
                available: CalendarService.authenticated
                events: CalendarService.allEvents
                hiddenCalendars: root.hiddenCalendars
                loading: CalendarService.isLoading
                monthDate: root.selectedDate
                selectedDate: root.selectedDate

                onCreateRequested: (value, anchorRect) => root.createFromMonth(value, anchorRect)
                onDaySelected: value => root.selectDate(value)
                onEventClicked: (eventData, anchorRect) => root.openEventEditor(eventData, root.editorAnchorFromView(anchorRect))
                onWeekRequested: value => {
                    root.selectDate(value);
                    root.viewMode = "week";
                }
            }
        }
        Loader {
            id: eventEditorLoader

            active: false
            anchors.fill: parent
            asynchronous: false
            source: Qt.resolvedUrl("CalendarEventEditor.qml")
        }
        Connections {
            function onClosed() {
                root.clearCurrentViewSelection();
                editorUnloadTimer.restart();
            }

            target: eventEditorLoader.item
        }
        CalendarAccountDialog {
            id: accountDialog

            anchors.fill: parent

            onClosed: root.pendingCreateAfterConnect = false
        }
    }
}
