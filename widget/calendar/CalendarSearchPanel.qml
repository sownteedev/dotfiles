import "../../"
import "../../components"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var accounts: []
    property date anchorDate: new Date()
    property var calendars: []
    property var events: []
    property string query: ""
    property string rangeMode: "all"
    readonly property var results: buildResults()

    signal closed
    signal resultSelected(var eventData)

    function addDays(value, amount) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + amount);
    }
    function buildResults() {
        var values = events || [];
        var wanted = root.query.trim().toLowerCase();
        var accountWanted = accountFilter.text.trim().toLowerCase();
        var calendarWanted = calendarFilter.text.trim().toLowerCase();
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
            var start = new Date(eventData.start);
            if (isNaN(start.getTime()))
                continue;
            if (rangeStart && (start < rangeStart || start >= rangeEnd))
                continue;
            var haystack = [eventData.title, eventData.description, eventData.location, eventData.accountName, eventData.accountEmail, eventData.calendarName, eventData.taskListName].join(" ").toLowerCase();
            if (wanted !== "" && haystack.indexOf(wanted) < 0)
                continue;
            if (accountWanted !== "" && [eventData.accountName, eventData.accountEmail].join(" ").toLowerCase().indexOf(accountWanted) < 0)
                continue;
            if (calendarWanted !== "" && [eventData.calendarName, eventData.taskListName].join(" ").toLowerCase().indexOf(calendarWanted) < 0)
                continue;
            result.push(eventData);
        }
        result.sort(function (first, second) {
            return new Date(first.start).getTime() - new Date(second.start).getTime();
        });
        return result.slice(0, 80);
    }
    function formatResultDate(value) {
        var date = new Date(value);
        if (isNaN(date.getTime()))
            return "";
        return Qt.formatDateTime(date, "d MMM yyyy, HH:mm");
    }
    function rangeLabel() {
        if (rangeMode === "week")
            return qsTr("This week");
        if (rangeMode === "month")
            return qsTr("This month");
        return qsTr("All dates");
    }

    border.color: Config.alpha(Config.md3.outline_variant, 0.56)
    border.width: 1
    color: Config.md3.surface_container_high
    height: 520
    implicitHeight: Math.min(620, searchColumn.implicitHeight + 24)
    radius: 20

    onVisibleChanged: {
        if (visible)
            Qt.callLater(queryInput.forceActiveFocus);
    }

    ColumnLayout {
        id: searchColumn

        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                border.color: queryInput.activeFocus ? Config.alpha(Config.md3.primary, 0.52) : Config.alpha(Config.md3.outline, 0.22)
                border.width: 1
                color: Config.md3.surface_container_low
                radius: 14

                TextInput {
                    id: queryInput

                    activeFocusOnTab: true
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: Md3.typeScale.bodyMedium.size

                    onTextChanged: root.query = text

                    Text {
                        anchors.fill: parent
                        color: Config.alpha(Config.md3.on_surface_variant, 0.56)
                        font: queryInput.font
                        text: qsTr("Search events and tasks")
                        verticalAlignment: Text.AlignVCenter
                        visible: queryInput.text === ""
                    }
                }
            }
            SettingsActionButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                iconName: "window-close-symbolic"
                iconOnly: true
                text: qsTr("Close search")

                onClicked: root.closed()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                border.color: Config.alpha(Config.md3.outline, 0.2)
                border.width: 1
                color: Config.md3.surface_container_low
                radius: 12

                TextInput {
                    id: accountFilter

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: Md3.typeScale.bodySmall.size

                    onTextChanged: root.queryChanged()

                    Text {
                        anchors.fill: parent
                        color: Config.alpha(Config.md3.on_surface_variant, 0.52)
                        font: accountFilter.font
                        text: qsTr("Account")
                        verticalAlignment: Text.AlignVCenter
                        visible: accountFilter.text === ""
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                border.color: Config.alpha(Config.md3.outline, 0.2)
                border.width: 1
                color: Config.md3.surface_container_low
                radius: 12

                TextInput {
                    id: calendarFilter

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: Md3.typeScale.bodySmall.size

                    onTextChanged: root.queryChanged()

                    Text {
                        anchors.fill: parent
                        color: Config.alpha(Config.md3.on_surface_variant, 0.52)
                        font: calendarFilter.font
                        text: qsTr("Calendar or task list")
                        verticalAlignment: Text.AlignVCenter
                        visible: calendarFilter.text === ""
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    {
                        "id": "all",
                        "label": qsTr("All dates")
                    },
                    {
                        "id": "week",
                        "label": qsTr("This week")
                    },
                    {
                        "id": "month",
                        "label": qsTr("This month")
                    }
                ]

                SettingsActionButton {
                    Layout.fillWidth: true
                    primary: root.rangeMode === modelData.id
                    text: modelData.label

                    onClicked: root.rangeMode = modelData.id
                }
            }
        }
        Text {
            Layout.fillWidth: true
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: Md3.typeScale.bodySmall.size
            text: root.results.length === 0 ? qsTr("No matching events or tasks") : qsTr("%1 results · %2").arg(root.results.length).arg(root.rangeLabel())
        }
        ListView {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            model: root.results
            spacing: 4

            delegate: Rectangle {
                required property var modelData

                color: resultMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.12) : Config.alpha(Config.md3.on_surface, 0.035)
                height: 58
                radius: 12
                width: ListView.view.width

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        Layout.preferredHeight: 10
                        Layout.preferredWidth: 10
                        color: modelData.calendarColor || Config.md3.primary
                        radius: 5
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: Md3.typeScale.bodyMedium.size
                            font.weight: 600
                            text: modelData.title || qsTr("Untitled")
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface_variant
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: Md3.typeScale.bodySmall.size
                            text: qsTr("%1 · %2").arg(root.formatResultDate(modelData.start)).arg(modelData.isTask ? qsTr("Task") : (modelData.calendarName || qsTr("Calendar")))
                        }
                    }
                }
                MouseArea {
                    id: resultMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.resultSelected(modelData)
                }
            }
        }
    }
}
