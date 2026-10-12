import "../../"
import "../../components"
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: root

    property bool accountMenuOpen: false
    property var accounts: []
    property date anchorDate: new Date()
    property bool calendarMenuOpen: false
    property var calendars: []
    readonly property bool compact: width < 520
    property var events: []
    readonly property bool filtersActive: selectedAccountId !== "" || selectedCalendarId !== "" || rangeMode !== "all" || root.query !== ""
    property alias query: queryInput.text
    property string rangeMode: "all"
    readonly property var results: buildResults()
    property string selectedAccountId: ""
    property string selectedCalendarId: ""

    signal closed
    signal resultSelected(var eventData)

    function accountOptions() {
        var list = [
            {
                "id": "",
                "label": qsTr("All accounts"),
                "provider": ""
            }
        ];
        var accs = root.accounts || [];
        for (var i = 0; i < accs.length; ++i) {
            var acc = accs[i];
            if (!acc)
                continue;
            list.push({
                "id": String(acc.id || ""),
                "label": String(acc.displayName || acc.email || root.providerLabel(String(acc.provider || ""))),
                "provider": String(acc.provider || "")
            });
        }
        return list;
    }
    function activateSelection() {
        var index = resultList.currentIndex < 0 ? 0 : resultList.currentIndex;
        if (index < results.length)
            root.resultSelected(results[index]);
    }
    function activeFilterSummary() {
        var summary = [];
        if (rangeMode !== "all")
            summary.push(rangeLabel());
        if (selectedAccountId !== "")
            summary.push(selectedAccountLabel());
        if (selectedCalendarId !== "")
            summary.push(selectedCalendarLabel());
        return summary.length > 0 ? summary.join(" · ") : rangeLabel();
    }
    function addDays(value, amount) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + amount);
    }
    function buildResults() {
        var values = events || [];
        var wanted = root.query.trim().toLowerCase();
        var rangeStart = null;
        var rangeEnd = null;
        if (root.rangeMode === "week") {
            rangeStart = new Date(root.anchorDate.getFullYear(), root.anchorDate.getMonth(), root.anchorDate.getDate());
            var weekOffset = rangeStart.getDay() === 0 ? -6 : 1 - rangeStart.getDay();
            rangeStart = addDays(rangeStart, weekOffset);
            rangeEnd = addDays(rangeStart, 7);
        } else if (root.rangeMode === "month") {
            rangeStart = new Date(root.anchorDate.getFullYear(), root.anchorDate.getMonth(), 1);
            rangeEnd = new Date(root.anchorDate.getFullYear(), root.anchorDate.getMonth() + 1, 1);
        }

        var result = [];
        for (var index = 0; index < values.length; ++index) {
            var eventData = values[index];
            if (!eventData)
                continue;
            var matchingCalendar = null;
            for (var calendarIndex = 0; calendarIndex < root.calendars.length; ++calendarIndex) {
                if (String(root.calendars[calendarIndex].id || "") === String(eventData.calendarId || "")) {
                    matchingCalendar = root.calendars[calendarIndex];
                    break;
                }
            }
            if (matchingCalendar && matchingCalendar.visible === false)
                continue;
            if (root.selectedAccountId !== "") {
                var eventAccId = String(eventData.accountId || (matchingCalendar ? matchingCalendar.accountId : "") || "");
                if (eventAccId !== root.selectedAccountId)
                    continue;
            }
            if (root.selectedCalendarId !== "" && String(eventData.calendarId || "") !== root.selectedCalendarId)
                continue;
            var start = new Date(eventData.start);
            if (isNaN(start.getTime()))
                continue;
            if (rangeStart && (start < rangeStart || start >= rangeEnd))
                continue;
            var haystack = [eventData.title, eventData.description, eventData.location, eventData.accountName, eventData.accountEmail, eventData.calendarName, eventData.taskListName].join(" ").toLowerCase();
            if (wanted !== "" && haystack.indexOf(wanted) < 0)
                continue;
            result.push(eventData);
        }
        result.sort(function (first, second) {
            return new Date(first.start).getTime() - new Date(second.start).getTime();
        });
        return result.slice(0, 100);
    }
    function calendarOptions() {
        var list = [
            {
                "id": "",
                "label": qsTr("All calendars and lists"),
                "color": "",
                "isTask": false
            }
        ];
        var cals = root.calendars || [];
        for (var i = 0; i < cals.length; ++i) {
            var cal = cals[i];
            if (!cal || cal.visible === false)
                continue;
            if (root.selectedAccountId !== "" && String(cal.accountId || "") !== root.selectedAccountId)
                continue;
            list.push({
                "id": String(cal.id || ""),
                "label": String(cal.name || (cal.isTaskList ? qsTr("Tasks") : qsTr("Calendar"))),
                "color": String(cal.color || ""),
                "isTask": Boolean(cal.isTaskList)
            });
        }
        return list;
    }
    function clearFilters() {
        root.query = "";
        root.selectedAccountId = "";
        root.selectedCalendarId = "";
        root.rangeMode = "all";
        accountMenuOpen = false;
        calendarMenuOpen = false;
    }
    function formatResultTimeAndDetails(eventData) {
        var parts = [];
        var start = new Date(eventData.start);
        var end = eventData.end ? new Date(eventData.end) : null;
        var now = new Date();
        var isThisYear = start.getFullYear() === now.getFullYear();

        var dateStr = isThisYear ? Qt.formatDate(start, "d MMM") : Qt.formatDate(start, "d MMM yyyy");
        parts.push(dateStr);

        if (eventData.allDay) {
            parts.push(qsTr("All day"));
        } else if (!isNaN(start.getTime())) {
            var timeStr = Qt.formatTime(start, "HH:mm");
            if (end && !isNaN(end.getTime()))
                timeStr += " – " + Qt.formatTime(end, "HH:mm");
            parts.push(timeStr);
        }

        if (eventData.location && String(eventData.location).trim() !== "")
            parts.push(String(eventData.location).trim());

        return parts.join(" · ");
    }
    function moveSelection(amount, focusResult) {
        if (results.length === 0)
            return;
        resultList.currentIndex = resultList.currentIndex < 0 ? (amount > 0 ? 0 : results.length - 1) : Math.max(0, Math.min(results.length - 1, resultList.currentIndex + amount));
        resultList.positionViewAtIndex(resultList.currentIndex, ListView.Contain);
        if (focusResult && resultList.currentItem)
            resultList.currentItem.forceActiveFocus();
    }
    function providerLabel(provider) {
        if (provider === "microsoft")
            return qsTr("Microsoft 365");
        if (provider === "caldav" || provider === "icloud")
            return qsTr("iCloud");
        return qsTr("Google");
    }
    function rangeLabel() {
        if (rangeMode === "week")
            return qsTr("This week");
        if (rangeMode === "month")
            return qsTr("This month");
        return qsTr("All dates");
    }
    function selectedAccountLabel() {
        if (root.selectedAccountId === "")
            return qsTr("All accounts");
        var accs = root.accounts || [];
        for (var i = 0; i < accs.length; ++i) {
            if (String(accs[i].id || "") === root.selectedAccountId)
                return String(accs[i].displayName || accs[i].email || root.providerLabel(String(accs[i].provider || "")));
        }
        return qsTr("All accounts");
    }
    function selectedAccountProvider() {
        if (root.selectedAccountId === "")
            return "";
        var accs = root.accounts || [];
        for (var i = 0; i < accs.length; ++i) {
            if (String(accs[i].id || "") === root.selectedAccountId)
                return String(accs[i].provider || "");
        }
        return "";
    }
    function selectedCalendarColor() {
        if (root.selectedCalendarId === "")
            return "";
        var cals = root.calendars || [];
        for (var i = 0; i < cals.length; ++i) {
            if (String(cals[i].id || "") === root.selectedCalendarId)
                return String(cals[i].color || "");
        }
        return "";
    }
    function selectedCalendarLabel() {
        if (root.selectedCalendarId === "")
            return qsTr("All calendars");
        var cals = root.calendars || [];
        for (var i = 0; i < cals.length; ++i) {
            if (String(cals[i].id || "") === root.selectedCalendarId)
                return String(cals[i].name || qsTr("Calendar"));
        }
        return qsTr("All calendars");
    }

    implicitHeight: 600
    implicitWidth: 720

    Keys.onEscapePressed: {
        if (root.accountMenuOpen || root.calendarMenuOpen) {
            root.accountMenuOpen = false;
            root.calendarMenuOpen = false;
        } else {
            root.closed();
        }
    }
    onResultsChanged: Qt.callLater(() => {
        resultList.currentIndex = -1;
        resultList.positionViewAtBeginning();
    })
    onVisibleChanged: {
        if (visible) {
            root.accountMenuOpen = false;
            root.calendarMenuOpen = false;
            Qt.callLater(() => {
                if (root.visible)
                    queryInput.forceActiveFocus();
            });
        }
    }

    ShellShadow {
        active: root.visible
        cornerRadius: panelCard.radius
        level: 3
        target: panelCard
    }
    Rectangle {
        id: panelCard

        anchors.fill: parent
        border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.38 : 0.22)
        border.width: 1
        color: Config.md3.surface_container_low
        radius: Md3.shape.extraLarge

        MouseArea {
            acceptedButtons: Qt.AllButtons
            anchors.fill: parent
            hoverEnabled: true

            onClicked: {
                root.accountMenuOpen = false;
                root.calendarMenuOpen = false;
            }
            onWheel: wheel => wheel.accepted = true
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Search Bar (MD3 Search Bar)
            Rectangle {
                id: searchBarContainer

                Layout.fillWidth: true
                Layout.preferredHeight: 52
                border.color: queryInput.activeFocus ? Config.md3.primary : Config.alpha(Config.md3.outline_variant, 0.32)
                border.width: queryInput.activeFocus ? 2 : 1
                color: Config.md3.surface_container_high
                radius: Md3.shape.full

                Behavior on border.color {
                    Md3ColorAnimation {
                        role: "state"
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: 10

                    Md3Icon {
                        Layout.alignment: Qt.AlignVCenter
                        color: queryInput.activeFocus ? Config.md3.primary : Config.md3.on_surface_variant
                        name: "search"
                        size: 22

                        Behavior on color {
                            Md3ColorAnimation {
                                role: "state"
                            }
                        }
                    }
                    TextField {
                        id: queryInput

                        Accessible.name: qsTr("Search events and tasks")
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 15
                        leftPadding: 0
                        placeholderText: qsTr("Search events, tasks, notes…")
                        placeholderTextColor: Config.alpha(Config.md3.on_surface_variant, 0.7)
                        rightPadding: 0
                        selectByMouse: true

                        background: Item {
                        }

                        Keys.onDownPressed: root.moveSelection(1)
                        Keys.onUpPressed: root.moveSelection(-1)
                        onAccepted: root.activateSelection()
                    }
                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 32
                        color: clearMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent"
                        radius: Md3.shape.full
                        visible: root.query !== ""

                        Md3Icon {
                            anchors.centerIn: parent
                            color: Config.md3.on_surface_variant
                            name: "window-close-symbolic"
                            size: 16
                        }
                        MouseArea {
                            id: clearMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                root.query = "";
                                queryInput.forceActiveFocus();
                            }
                        }
                        Md3ToolTip {
                            text: qsTr("Clear text")
                            visible: clearMouse.containsMouse
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: 1
                        color: Config.alpha(Config.md3.outline_variant, 0.3)
                    }
                    Rectangle {
                        Layout.preferredHeight: 34
                        Layout.preferredWidth: 34
                        color: closeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent"
                        radius: Md3.shape.full

                        Md3Icon {
                            anchors.centerIn: parent
                            color: Config.md3.on_surface_variant
                            name: "close"
                            size: 19
                        }
                        MouseArea {
                            id: closeMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: root.closed()
                        }
                        Md3ToolTip {
                            text: qsTr("Close (Esc)")
                            visible: closeMouse.containsMouse
                        }
                    }
                }
            }
            GridLayout {
                id: filterRow

                Layout.fillWidth: true
                columnSpacing: 10
                columns: root.width < 640 ? 2 : 3
                rowSpacing: 10

                Rectangle {
                    id: rangePill

                    readonly property int selectedIndex: root.rangeMode === "week" ? 1 : root.rangeMode === "month" ? 2 : 0

                    Layout.columnSpan: filterRow.columns === 2 ? 2 : 1
                    Layout.fillWidth: true
                    Layout.minimumWidth: 300
                    Layout.preferredHeight: 44
                    Layout.preferredWidth: 340
                    color: Config.alpha(Config.md3.surface_container_high, 0.6)
                    radius: Md3.shape.full

                    Rectangle {
                        color: Config.md3.primary_container
                        height: rangePill.height - 8
                        radius: Md3.shape.full
                        width: (rangePill.width - 20) / 3
                        x: 4 + rangePill.selectedIndex * (width + 6)
                        y: 4

                        Behavior on x {
                            XAnimator {
                                duration: 190
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    RowLayout {
                        id: rangeRow

                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Repeater {
                            model: [
                                {
                                    "key": "all",
                                    "label": qsTr("All dates")
                                },
                                {
                                    "key": "week",
                                    "label": qsTr("This week")
                                },
                                {
                                    "key": "month",
                                    "label": qsTr("This month")
                                }
                            ]

                            Rectangle {
                                id: segBtn

                                required property var modelData
                                readonly property bool selected: root.rangeMode === modelData.key

                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                color: !selected && segMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : "transparent"
                                radius: Md3.shape.full

                                Behavior on color {
                                    Md3ColorAnimation {
                                        role: "state"
                                    }
                                }

                                Text {
                                    id: segText

                                    anchors.centerIn: parent
                                    color: segBtn.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.labelMedium.letterSpacing
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    text: segBtn.modelData.label
                                }
                                MouseArea {
                                    id: segMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: root.rangeMode = segBtn.modelData.key
                                }
                            }
                        }
                    }
                }

                // Account Filter Chip - Fills available proportional width
                Rectangle {
                    id: accountChip

                    readonly property bool active: root.selectedAccountId !== ""

                    Layout.fillWidth: true
                    Layout.minimumWidth: 140
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 175
                    border.color: active ? Config.md3.primary : accMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.4) : Config.alpha(Config.md3.outline_variant, 0.35)
                    border.width: 1
                    color: active ? Config.alpha(Config.md3.primary, 0.12) : accMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.06) : Config.alpha(Config.md3.surface_container_high, 0.4)
                    radius: Md3.shape.small

                    Behavior on border.color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }
                    Behavior on color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }

                    RowLayout {
                        id: accountChipContent

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        CalendarProviderIcon {
                            height: 16
                            provider: root.selectedAccountProvider()
                            tint: accountChip.active ? Config.md3.primary : Config.md3.on_surface_variant
                            visible: accountChip.active && root.selectedAccountProvider() !== ""
                            width: 16
                        }
                        Md3Icon {
                            color: accountChip.active ? Config.md3.primary : Config.md3.on_surface_variant
                            name: "avatar-default-symbolic"
                            size: 16
                            visible: !accountChip.active || root.selectedAccountProvider() === ""
                        }
                        Text {
                            Layout.fillWidth: true
                            color: accountChip.active ? Config.md3.primary : Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.labelMedium.letterSpacing
                            font.pixelSize: 13
                            font.weight: accountChip.active ? 600 : 500
                            maximumLineCount: 1
                            text: root.selectedAccountLabel()
                        }
                        Md3Icon {
                            color: accountChip.active ? Config.md3.primary : Config.md3.on_surface_variant
                            name: "pan-down-symbolic"
                            size: 14
                        }
                    }
                    MouseArea {
                        id: accMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            root.calendarMenuOpen = false;
                            root.accountMenuOpen = !root.accountMenuOpen;
                        }
                    }
                }

                // Calendar Filter Chip - Fills available proportional width
                Rectangle {
                    id: calendarChip

                    readonly property bool active: root.selectedCalendarId !== ""
                    readonly property color calAccentColor: root.selectedCalendarColor() !== "" ? root.selectedCalendarColor() : Config.md3.primary

                    Layout.fillWidth: true
                    Layout.minimumWidth: 140
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 175
                    border.color: active ? calAccentColor : calMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.4) : Config.alpha(Config.md3.outline_variant, 0.35)
                    border.width: 1
                    color: active ? Config.alpha(calAccentColor, 0.12) : calMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.06) : Config.alpha(Config.md3.surface_container_high, 0.4)
                    radius: Md3.shape.small

                    Behavior on border.color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }
                    Behavior on color {
                        Md3ColorAnimation {
                            role: "state"
                        }
                    }

                    RowLayout {
                        id: calendarChipContent

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Rectangle {
                            Layout.preferredHeight: 9
                            Layout.preferredWidth: 9
                            color: calendarChip.calAccentColor
                            radius: 4.5
                            visible: calendarChip.active
                        }
                        Md3Icon {
                            color: Config.md3.on_surface_variant
                            name: "x-office-calendar-symbolic"
                            size: 16
                            visible: !calendarChip.active
                        }
                        Text {
                            Layout.fillWidth: true
                            color: calendarChip.active ? Config.md3.on_surface : Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.labelMedium.letterSpacing
                            font.pixelSize: 13
                            font.weight: calendarChip.active ? 600 : 500
                            maximumLineCount: 1
                            text: root.selectedCalendarLabel()
                        }
                        Md3Icon {
                            color: Config.md3.on_surface_variant
                            name: "pan-down-symbolic"
                            size: 14
                        }
                    }
                    MouseArea {
                        id: calMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            root.accountMenuOpen = false;
                            root.calendarMenuOpen = !root.calendarMenuOpen;
                        }
                    }
                }
            }

            // Results Count Header
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleSmall.letterSpacing
                    font.pixelSize: 15
                    font.weight: 600
                    text: qsTr("Results")
                }
                Rectangle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: Math.max(28, resultCount.implicitWidth + 16)
                    color: Config.alpha(Config.md3.primary, 0.15)
                    radius: Md3.shape.full

                    Text {
                        id: resultCount

                        anchors.centerIn: parent
                        color: Config.md3.primary
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: 700
                        text: String(root.results.length)
                    }
                }
            }

            // Subtle Divider Line
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.outline_variant, 0.22)
                implicitHeight: 1
            }

            // Results List / Empty State
            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumHeight: 0
                clip: true

                ListView {
                    id: resultList

                    anchors.fill: parent
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    currentIndex: -1
                    model: root.results
                    spacing: 8

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    delegate: Rectangle {
                        id: resultItem

                        readonly property color accentColor: modelData.calendarColor ? String(modelData.calendarColor) : Config.md3.primary
                        readonly property bool highlighted: activeFocus || ListView.isCurrentItem
                        required property int index
                        readonly property bool isCompletedTask: modelData.isTask === true && modelData.status === "completed"
                        required property var modelData
                        readonly property date startDate: new Date(modelData.start)

                        Accessible.name: qsTr("%1, %2, %3").arg(modelData.title || qsTr("Untitled")).arg(root.formatResultTimeAndDetails(modelData)).arg(modelData.isTask ? qsTr("Task") : modelData.calendarName || qsTr("Calendar"))
                        Accessible.role: Accessible.Button
                        Layout.fillWidth: true
                        activeFocusOnTab: true
                        border.color: activeFocus ? Config.md3.primary : (resultItem.highlighted ? "transparent" : Config.alpha(Config.md3.outline_variant, 0.18))
                        border.width: activeFocus ? 2 : 1
                        color: highlighted ? Config.md3.secondary_container : (resultMouse.pressed ? Config.alpha(Config.md3.on_surface, Md3.state.pressed) : resultMouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : Config.alpha(Config.md3.surface_container_high, 0.35))
                        height: 74
                        radius: Md3.shape.medium
                        width: ListView.view.width

                        Behavior on color {
                            Md3ColorAnimation {
                                role: "state"
                            }
                        }

                        Accessible.onPressAction: root.resultSelected(resultItem.modelData)
                        Keys.onDownPressed: root.moveSelection(1, true)
                        Keys.onReturnPressed: root.resultSelected(resultItem.modelData)
                        Keys.onSpacePressed: root.resultSelected(resultItem.modelData)
                        Keys.onUpPressed: root.moveSelection(-1, true)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Squircle Date Badge
                            Rectangle {
                                Layout.preferredHeight: 52
                                Layout.preferredWidth: 48
                                border.color: Config.alpha(Config.md3.primary, 0.22)
                                border.width: 1
                                color: resultItem.highlighted ? Config.alpha(Config.md3.on_secondary_container, 0.12) : Config.alpha(Config.md3.primary, 0.12)
                                radius: Md3.shape.medium

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: resultItem.highlighted ? Config.md3.on_secondary_container : Config.md3.primary
                                        font.family: Config.fontName
                                        font.pixelSize: 19
                                        font.weight: 700
                                        text: resultItem.startDate.getDate()
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: resultItem.highlighted ? Config.md3.on_secondary_container : Config.alpha(Config.md3.on_surface, 0.70)
                                        font.capitalization: Font.AllUppercase
                                        font.family: Config.fontName
                                        font.letterSpacing: 0.5
                                        font.pixelSize: 11
                                        font.weight: 700
                                        text: Qt.formatDate(resultItem.startDate, "MMM")
                                    }
                                }
                            }

                            // Middle Content
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    color: resultItem.highlighted ? Config.md3.on_secondary_container : Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.titleSmall.letterSpacing
                                    font.pixelSize: 15
                                    font.strikeout: resultItem.isCompletedTask
                                    font.weight: 600
                                    text: resultItem.modelData.title || qsTr("Untitled")
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface_variant
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                                    font.pixelSize: 13
                                    text: root.formatResultTimeAndDetails(resultItem.modelData)
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        Layout.preferredHeight: 8
                                        Layout.preferredWidth: 8
                                        color: resultItem.accentColor
                                        radius: 4
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.alpha(Config.md3.on_surface_variant, 0.85)
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 12
                                        text: resultItem.modelData.isTask ? (resultItem.modelData.taskListName || qsTr("Task")) : (resultItem.modelData.calendarName || qsTr("Calendar")) + (resultItem.modelData.accountName ? (" · " + resultItem.modelData.accountName) : "")
                                    }
                                }
                            }

                            // Trailing Icon
                            Md3Icon {
                                Layout.alignment: Qt.AlignVCenter
                                color: resultItem.highlighted ? Config.md3.on_secondary_container : (resultMouse.containsMouse ? Config.md3.primary : Config.alpha(Config.md3.on_surface_variant, 0.6))
                                name: resultItem.modelData.isTask ? "task_alt" : "event"
                                size: 20

                                Behavior on color {
                                    Md3ColorAnimation {
                                        role: "state"
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: resultMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: root.resultSelected(resultItem.modelData)
                        }
                    }
                }

                // Empty State
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: root.results.length === 0
                    width: Math.max(0, parent.width - 48)

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 60
                        Layout.preferredWidth: 60
                        color: Config.alpha(Config.md3.on_surface, 0.06)
                        radius: 20

                        Md3Icon {
                            anchors.centerIn: parent
                            color: Config.md3.on_surface_variant
                            name: "search"
                            size: 28
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: Md3.typeScale.titleMedium.size
                        font.weight: 600
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("No matching events or tasks")
                        wrapMode: Text.Wrap
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: Md3.typeScale.bodyMedium.size
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Try another search term or reset your filters.")
                        wrapMode: Text.Wrap
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: emptyResetText.implicitWidth + 24
                        border.color: Config.alpha(Config.md3.primary, 0.3)
                        border.width: 1
                        color: Config.alpha(Config.md3.primary, 0.12)
                        radius: Md3.shape.full
                        visible: root.filtersActive

                        Text {
                            id: emptyResetText

                            anchors.centerIn: parent
                            color: Config.md3.primary
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: 600
                            text: qsTr("Reset filters")
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: root.clearFilters()
                        }
                    }
                }
            }
        }
    }

    // Dismiss overlay for dropdown menus
    MouseArea {
        anchors.fill: parent
        visible: root.accountMenuOpen || root.calendarMenuOpen
        z: 40

        onClicked: {
            root.accountMenuOpen = false;
            root.calendarMenuOpen = false;
        }
    }

    // Account Dropdown Menu Shadow
    ShellShadow {
        active: root.accountMenuOpen
        cornerRadius: accountMenuCard.radius
        level: 3
        target: accountMenuCard
        z: 49
    }

    // Account Dropdown Menu
    Rectangle {
        id: accountMenuCard

        border.color: Config.alpha(Config.md3.outline_variant, 0.4)
        border.width: 1
        color: Config.md3.surface_container_high
        height: Math.min(260, accountMenuList.contentHeight + 16)
        radius: Md3.shape.medium
        visible: root.accountMenuOpen
        width: Math.max(220, Math.min(320, accountChip.width))
        x: Math.max(12, Math.min(root.width - width - 12, accountChip.x + 14))
        y: Math.min(root.height - height - 12, filterRow.y + filterRow.height + 20)
        z: 50

        ListView {
            id: accountMenuList

            anchors.fill: parent
            anchors.margins: 8
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: root.accountOptions()
            spacing: 2

            delegate: Rectangle {
                id: accOptionItem

                required property var modelData
                readonly property bool selected: String(modelData.id || "") === root.selectedAccountId

                color: selected ? Config.md3.secondary_container : (accOptMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent")
                height: 38
                radius: Md3.shape.small
                width: ListView.view.width

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    CalendarProviderIcon {
                        height: 18
                        provider: String(accOptionItem.modelData.provider || "google")
                        tint: accOptionItem.selected ? Config.md3.on_secondary_container : Config.md3.primary
                        visible: accOptionItem.modelData.provider !== ""
                        width: 18
                    }
                    Md3Icon {
                        color: accOptionItem.selected ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                        name: "avatar-default-symbolic"
                        size: 18
                        visible: accOptionItem.modelData.provider === ""
                    }
                    Text {
                        Layout.fillWidth: true
                        color: accOptionItem.selected ? Config.md3.on_secondary_container : Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: accOptionItem.selected ? 600 : 400
                        text: accOptionItem.modelData.label
                    }
                    Md3Icon {
                        color: Config.md3.primary
                        name: "checkmark-symbolic"
                        size: 15
                        visible: accOptionItem.selected
                        weight: 700
                    }
                }
                MouseArea {
                    id: accOptMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        root.selectedAccountId = String(accOptionItem.modelData.id || "");
                        root.accountMenuOpen = false;
                    }
                }
            }
        }
    }

    // Calendar Dropdown Menu Shadow
    ShellShadow {
        active: root.calendarMenuOpen
        cornerRadius: calendarMenuCard.radius
        level: 3
        target: calendarMenuCard
        z: 49
    }

    // Calendar Dropdown Menu
    Rectangle {
        id: calendarMenuCard

        border.color: Config.alpha(Config.md3.outline_variant, 0.4)
        border.width: 1
        color: Config.md3.surface_container_high
        height: Math.min(280, calendarMenuList.contentHeight + 16)
        radius: Md3.shape.medium
        visible: root.calendarMenuOpen
        width: Math.max(220, Math.min(320, calendarChip.width))
        x: Math.max(12, Math.min(root.width - width - 12, calendarChip.x + 14))
        y: Math.min(root.height - height - 12, filterRow.y + filterRow.height + 20)
        z: 50

        ListView {
            id: calendarMenuList

            anchors.fill: parent
            anchors.margins: 8
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: root.calendarOptions()
            spacing: 2

            delegate: Rectangle {
                id: calOptionItem

                required property var modelData
                readonly property bool selected: String(modelData.id || "") === root.selectedCalendarId

                color: selected ? Config.md3.secondary_container : (calOptMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent")
                height: 38
                radius: Md3.shape.small
                width: ListView.view.width

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        Layout.preferredHeight: 10
                        Layout.preferredWidth: 10
                        color: calOptionItem.modelData.color !== "" ? calOptionItem.modelData.color : Config.md3.primary
                        radius: 5
                        visible: calOptionItem.modelData.id !== ""
                    }
                    Md3Icon {
                        color: calOptionItem.selected ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                        name: "x-office-calendar-symbolic"
                        size: 18
                        visible: calOptionItem.modelData.id === ""
                    }
                    Text {
                        Layout.fillWidth: true
                        color: calOptionItem.selected ? Config.md3.on_secondary_container : Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: calOptionItem.selected ? 600 : 400
                        text: calOptionItem.modelData.label
                    }
                    Md3Icon {
                        color: Config.md3.primary
                        name: "checkmark-symbolic"
                        size: 15
                        visible: calOptionItem.selected
                        weight: 700
                    }
                }
                MouseArea {
                    id: calOptMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        root.selectedCalendarId = String(calOptionItem.modelData.id || "");
                        root.calendarMenuOpen = false;
                    }
                }
            }
        }
    }
}
