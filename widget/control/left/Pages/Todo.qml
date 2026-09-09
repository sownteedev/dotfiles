import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../../../"
import "../../../../service"
import "../../../../components"

Item {
    id: root

    property string activeSelectorKind: ""
    property var activeSelectorOptions: []
    readonly property var allTasks: LocalTaskService.tasks.map(task => Object.assign({}, task, {
            "taskSource": "local"
        })).concat(GoogleService.allTasks.map(task => Object.assign({}, task, {
            "taskSource": "google"
        })))
    readonly property bool canSave: newTaskTitle.trim() !== "" && !saving && (editingTaskSource === "local" || GoogleService.listsForAccount(editingAccountId).some(list => list.id === editingListId))
    property int currentTab: 0 // 0: To do, 1: Done
    readonly property var destinationOptions: [
        {
            "color": Config.md3.primary,
            "id": "",
            "label": qsTr("Local tasks"),
            "source": "local"
        }
    ].concat(GoogleService.accounts.map(account => ({
                "color": CalendarService.taskAccountColor(account.id),
                "id": account.id,
                "label": account.email || account.displayName,
                "source": "google"
            })))
    property string editingAccountId: ""
    property string editingListId: ""
    property string editingTaskId: ""
    property string editingTaskSource: "local"
    property var filteredTasks: {
        var list = [];
        var sourceTasks = allTasks;
        for (var i = 0; i < sourceTasks.length; i++) {
            var task = sourceTasks[i];
            var listKey = task.taskSource === "local" ? "local" : JSON.stringify([task.accountId, task.taskListId]);
            if (selectedTaskListKey !== "" && listKey !== selectedTaskListKey)
                continue;
            if (currentTab === 0 && task.status === "needsAction") {
                list.push(task);
            } else if (currentTab === 1 && task.status === "completed") {
                list.push(task);
            }
        }
        list.sort(function (a, b) {
            var aTime = a.due ? new Date(a.due).getTime() : Number.POSITIVE_INFINITY;
            var bTime = b.due ? new Date(b.due).getTime() : Number.POSITIVE_INFINITY;
            if (isNaN(aTime))
                aTime = Number.POSITIVE_INFINITY;
            if (isNaN(bTime))
                bTime = Number.POSITIVE_INFINITY;
            return aTime - bTime;
        });
        return list;
    }
    property string formError: ""
    readonly property var listOptions: [
        {
            "color": "",
            "id": "",
            "label": qsTr("All tasks")
        },
        {
            "color": Config.md3.primary,
            "id": "local",
            "label": qsTr("Local tasks")
        }
    ].concat(GoogleService.taskLists.map(list => ({
                "color": CalendarService.taskListColor(list.accountId, list.id),
                "id": JSON.stringify([list.accountId, list.id]),
                "label": list.title + " · " + list.accountLabel
            })))
    property string newTaskDue: ""
    property string newTaskNotes: ""
    property string newTaskTitle: ""
    readonly property Item popupBackdropHost: controlLeftWindow.topPopupBackdropHost
    readonly property real popupBackdropRadius: controlLeftWindow.topPopupBackdropRadius
    property bool saving: false
    property string selectedTaskListKey: ""
    property string selectionKind: ""
    property real selectionY: 0
    readonly property var selectorOptions: selectionKind === "destination" ? destinationOptions : selectionKind === "list" ? GoogleService.listsForAccount(editingAccountId).map(list => ({
                "color": CalendarService.taskListColor(editingAccountId, list.id),
                "id": list.id,
                "label": list.title
            })) : listOptions
    property bool showAddEvent: false

    function deleteTask(task) {
        if (task.taskSource === "local")
            LocalTaskService.deleteTask(task.id);
        else if (!GoogleService.taskActionBusy)
            GoogleService.deleteTask(task.taskListId, task.id, task.accountId);
    }
    function finishTaskSave() {
        if (editingTaskId === "") {
            currentTab = 0;
            if (selectedTaskListKey !== "")
                selectedTaskListKey = editingTaskSource === "local" ? "local" : JSON.stringify([editingAccountId, editingListId]);
        }
        showAddEvent = false;
    }
    function openNewTask() {
        if (saving)
            return;
        if (GoogleService.authenticated)
            GoogleService.fetchTasks();
        editingTaskId = "";
        formError = "";
        var selected = GoogleService.taskLists.find(list => JSON.stringify([list.accountId, list.id]) === selectedTaskListKey);
        editingTaskSource = selected ? "google" : "local";
        editingAccountId = selected ? selected.accountId : "";
        editingListId = selected ? selected.id : "";
        newTaskTitle = "";
        newTaskDue = "";
        newTaskNotes = "";
        titleField.text = "";
        notesField.text = "";
        showAddEvent = true;
        formFlickable.contentY = 0;
    }
    function openSelector(kind, sourceItem) {
        if (GoogleService.authenticated)
            GoogleService.refreshIfStale();
        activeSelectorKind = kind;
        selectionKind = kind;
        activeSelectorOptions = selectorOptions;
        selectionY = sourceItem.mapToItem(root, 0, sourceItem.height).y + 6;
    }
    function openTask(task) {
        if (saving)
            return;
        editingTaskId = String(task.id || "");
        editingTaskSource = task.taskSource;
        editingAccountId = task.accountId || "";
        editingListId = task.taskListId || "";
        formError = "";
        newTaskTitle = task.title || "";
        newTaskNotes = task.notes || "";
        titleField.text = newTaskTitle;
        notesField.text = newTaskNotes;
        if (task.due) {
            var parts = String(task.due).slice(0, 10).split("-");
            var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
            newTaskDue = String(d.getDate()).padStart(2, '0') + "/" + String(d.getMonth() + 1).padStart(2, '0') + "/" + d.getFullYear();
        } else {
            newTaskDue = "";
        }
        showAddEvent = true;
        formFlickable.contentY = 0;
    }
    function saveTask() {
        if (!canSave)
            return;
        var due = "";
        if (newTaskDue) {
            var parts = newTaskDue.split("/");
            if (parts.length === 3)
                due = parts[2] + "-" + parts[1].padStart(2, "0") + "-" + parts[0].padStart(2, "0");
        }
        formError = "";
        if (editingTaskSource === "local") {
            if (editingTaskId)
                LocalTaskService.updateTask(editingTaskId, newTaskTitle, due, newTaskNotes, undefined);
            else
                LocalTaskService.createTask(newTaskTitle, due, newTaskNotes);
            finishTaskSave();
            return;
        }
        saving = true;
        var done = function (ok, message) {
            root.saving = false;
            if (ok)
                root.finishTaskSave();
            else
                root.formError = message;
        };
        if (editingTaskId)
            GoogleService.updateTask(editingListId, editingTaskId, newTaskTitle, due, newTaskNotes, undefined, editingAccountId, done);
        else
            GoogleService.createTask(editingListId, newTaskTitle, due, newTaskNotes, "", editingAccountId, done);
    }
    function selectOption(item) {
        if (selectionKind === "")
            return;
        if (selectionKind === "destination") {
            editingTaskSource = item.source;
            editingAccountId = item.id;
            var lists = item.source === "google" ? GoogleService.listsForAccount(item.id) : [];
            editingListId = lists.length > 0 ? lists[0].id : "";
            formError = "";
        } else if (selectionKind === "list") {
            editingListId = item.id;
        } else {
            selectedTaskListKey = item.id;
            taskList.positionViewAtBeginning();
        }
        selectionKind = "";
    }
    function selectedLabel(options, id, fallback) {
        var item = options.find(option => option.id === id);
        return item ? item.label || item.title : fallback;
    }
    function toggleTask(task) {
        var newStatus = task.status === "completed" ? "needsAction" : "completed";
        if (task.taskSource === "local")
            LocalTaskService.updateTask(task.id, undefined, undefined, undefined, newStatus);
        else if (!GoogleService.taskActionBusy)
            GoogleService.updateTask(task.taskListId, task.id, undefined, undefined, undefined, newStatus, task.accountId);
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
    onSelectorOptionsChanged: {
        if (selectionKind !== "")
            activeSelectorOptions = selectorOptions;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        visible: !root.showAddEvent

        Item {
            id: toolbar

            readonly property bool compactToolbar: width < 430

            Layout.fillWidth: true
            Layout.preferredHeight: 44

            RowLayout {
                anchors.fill: parent
                spacing: toolbar.compactToolbar ? 8 : 12

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: toolbar.compactToolbar ? 104 : 120
                    border.color: Config.alpha(Config.md3.on_surface, 0.08)
                    border.width: 1
                    color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.72 : 0.38)
                    radius: 14

                    Rectangle {
                        color: Config.md3.primary_container
                        height: parent.height - 6
                        radius: 11
                        width: (parent.width - 6) / 2
                        x: 3 + currentTab * width
                        y: 3

                        Behavior on x {
                            NumberAnimation {
                                duration: Config.animationDuration(220)
                                easing.type: Easing.OutCubic
                            }
                        }

                        ShellShadow {
                            componentShadow: true
                            cornerRadius: parent.radius
                            target: parent
                            z: -1
                        }
                    }
                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Repeater {
                            model: [
                                {
                                    label: qsTr("To do"),
                                    icon: "view-list-symbolic",
                                    value: 0
                                },
                                {
                                    label: qsTr("Done"),
                                    icon: "checkbox-checked-symbolic",
                                    value: 1
                                }
                            ]

                            delegate: Item {
                                required property var modelData

                                Accessible.name: modelData.label
                                Accessible.role: Accessible.Button
                                height: parent.height
                                width: parent.width / 2

                                IconImage {
                                    anchors.centerIn: parent
                                    height: 20
                                    layer.enabled: true
                                    source: Quickshell.iconPath(modelData.icon)
                                    width: 20

                                    layer.effect: ColorOverlay {
                                        color: currentTab === modelData.value ? Config.md3.on_primary_container : Config.alpha(Config.md3.on_surface, 0.68)

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Config.animationDuration(160)
                                                easing.type: Easing.InOutCubic
                                            }
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: currentTab = modelData.value
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    id: filterSelectorButton

                    Accessible.name: qsTr("Task list: %1").arg(filterText.text)
                    Accessible.role: Accessible.ComboBox
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 42
                    activeFocusOnTab: true
                    border.color: activeFocus || filterMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.35) : Config.alpha(Config.md3.on_surface, 0.09)
                    border.width: 1
                    color: filterMouse.pressed ? Config.alpha(Config.md3.primary, 0.16) : filterMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.surface_container_high, 0.45)
                    radius: 11

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Config.animationDuration(120)
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(120)
                        }
                    }

                    Accessible.onPressAction: root.openSelector("filter", filterSelectorButton)
                    Keys.onDownPressed: root.openSelector("filter", filterSelectorButton)
                    Keys.onReturnPressed: root.openSelector("filter", filterSelectorButton)
                    Keys.onSpacePressed: root.openSelector("filter", filterSelectorButton)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: filterBadge.visible ? 8 : 0

                        Rectangle {
                            id: filterBadge

                            readonly property string badgeColorStr: {
                                var selected = root.listOptions.find(item => item.id === root.selectedTaskListKey);
                                return selected && selected.color ? String(selected.color) : "";
                            }
                            readonly property bool hasBadge: badgeColorStr !== "" && badgeColorStr !== "transparent" && badgeColorStr !== "#00000000"

                            Layout.preferredHeight: 8
                            Layout.preferredWidth: hasBadge ? 8 : 0
                            color: hasBadge ? badgeColorStr : "transparent"
                            radius: 4
                            visible: hasBadge
                        }
                        Text {
                            id: filterText

                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                            text: root.selectedLabel(root.listOptions, root.selectedTaskListKey, qsTr("All tasks"))
                        }
                        IconImage {
                            Layout.preferredHeight: 15
                            Layout.preferredWidth: 15
                            layer.enabled: true
                            source: Quickshell.iconPath("pan-down-symbolic")

                            layer.effect: ColorOverlay {
                                color: Config.alpha(Config.md3.on_surface, 0.58)
                            }
                        }
                    }
                    MouseArea {
                        id: filterMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.openSelector("filter", filterSelectorButton)
                    }
                }
                SettingsActionButton {
                    iconName: "list-add-symbolic"
                    iconOnly: true
                    primary: true
                    text: qsTr("Add task")

                    onClicked: root.openNewTask()
                }
            }
        }
        Text {
            Layout.fillWidth: true
            color: Config.md3.error
            elide: Text.ElideRight
            font.family: Config.fontName
            font.pixelSize: 13
            maximumLineCount: 3
            text: GoogleService.errorMessage || CalendarService.taskSnapshots.filter(snapshot => snapshot.error).map(snapshot => GoogleService.accountLabel(snapshot.accountId) + ": " + snapshot.error).join("\n")
            visible: root.selectedTaskListKey !== "local" && GoogleService.authenticated && text !== ""
            wrapMode: Text.Wrap
        }
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ProductivityEmptyState {
                actionVisible: false
                anchors.centerIn: parent
                busy: root.selectedTaskListKey !== "local" && GoogleService.authenticated && currentTab === 0 && GoogleService.isLoadingTasks && GoogleService.allTasks.length === 0
                description: {
                    if (currentTab === 1)
                        return qsTr("Completed tasks will appear here");
                    if (busy)
                        return qsTr("Fetching the latest task list");
                    return qsTr("Create a task to start organizing your day");
                }
                iconName: currentTab === 0 ? "view-list-symbolic" : "checkbox-checked-symbolic"
                opacity: filteredTasks.length === 0 ? 1 : 0
                title: {
                    if (currentTab === 1)
                        return qsTr("Nothing completed yet");
                    if (busy)
                        return qsTr("Syncing tasks…");
                    return root.selectedTaskListKey === "local" ? qsTr("No local tasks") : root.selectedTaskListKey !== "" ? qsTr("No tasks in this list") : qsTr("No tasks yet");
                }
                visible: root.filteredTasks.length === 0
                width: Math.min(parent.width - 40, 320)

                Behavior on opacity {
                    enabled: root.filteredTasks.length === 0

                    NumberAnimation {
                        duration: Config.animationDuration(140)
                        easing.type: Easing.OutCubic
                    }
                }
            }
            ListView {
                id: taskList

                readonly property real cardInset: 2

                anchors.fill: parent
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                model: filteredTasks
                spacing: 10

                delegate: Item {
                    id: taskDelegateRoot

                    readonly property bool actionBusy: !localTask && GoogleService.taskActionBusy
                    readonly property bool localTask: modelData.taskSource === "local"
                    required property var modelData

                    height: Math.max(80, taskContent.implicitHeight + 28)
                    layer.enabled: cardContent.swipeX < -0.4
                    width: taskList.width - taskList.cardInset * 2

                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            height: taskDelegateRoot.height
                            radius: 17
                            width: taskDelegateRoot.width
                        }
                    }
                    transform: Translate {
                        x: taskList.cardInset
                    }

                    SwipeDeleteBackground {
                        actionText: qsTr("Delete")
                        anchors.fill: parent
                        interactive: !taskDelegateRoot.actionBusy
                        swipeOffset: cardContent.swipeX

                        onTriggered: root.deleteTask(taskDelegateRoot.modelData)
                    }
                    Rectangle {
                        id: cardContent

                        readonly property color accountColor: taskDelegateRoot.localTask ? Config.md3.primary : CalendarService.taskListColor(modelData.accountId, modelData.taskListId)
                        property real swipeX: 0

                        border.color: taskCardMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.28) : Config.alpha(Config.md3.on_surface, 0.08)
                        border.width: 1
                        color: taskCardMouse.pressed ? Config.alpha(Config.md3.primary, 0.13) : taskCardMouse.containsMouse ? Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.9 : 0.58) : Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.76 : 0.4)
                        height: parent.height
                        opacity: modelData.status === "completed" ? 0.72 : 1
                        radius: 17
                        width: parent.width
                        x: swipeX

                        Behavior on swipeX {
                            enabled: !taskSwipe.active && !Config.shellReducedMotion

                            SpringAnimation {
                                damping: 0.52
                                epsilon: 0.25
                                mass: 0.85
                                spring: 4.6
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: cardContent.accountColor
                            height: parent.height - 24
                            radius: 2
                            visible: !taskDelegateRoot.localTask
                            width: 3.5
                        }
                        MouseArea {
                            id: taskCardMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !taskDelegateRoot.actionBusy
                            hoverEnabled: true

                            onClicked: {
                                if (cardContent.swipeX < 0) {
                                    cardContent.swipeX = 0;
                                    return;
                                }

                                root.openTask(modelData);
                            }
                        }
                        DragHandler {
                            id: taskSwipe

                            enabled: !taskDelegateRoot.actionBusy
                            target: null
                            xAxis.enabled: true
                            yAxis.enabled: false

                            onActiveChanged: {
                                if (!active) {
                                    if (cardContent.swipeX < -80) {
                                        root.deleteTask(taskDelegateRoot.modelData);
                                        cardContent.swipeX = 0;
                                    } else {
                                        cardContent.swipeX = 0;
                                    }
                                }
                            }
                            onTranslationChanged: {
                                cardContent.swipeX = Math.min(0, translation.x);
                            }
                        }
                        RowLayout {
                            id: taskContent

                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Rectangle {
                                border.color: cardContent.accountColor
                                border.width: 2
                                color: modelData.status === "completed" ? cardContent.accountColor : "transparent"
                                height: 28
                                radius: 14
                                width: 28

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animationDuration(140)
                                    }
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    height: 16
                                    layer.enabled: true
                                    source: Quickshell.iconPath("object-select-symbolic")
                                    visible: modelData.status === "completed"
                                    width: 16

                                    layer.effect: ColorOverlay {
                                        color: Config.md3.background
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !taskDelegateRoot.actionBusy

                                    onClicked: root.toggleTask(taskDelegateRoot.modelData)
                                }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.strikeout: modelData.status === "completed"
                                    font.weight: Font.Medium
                                    text: modelData.title || qsTr("Untitled task")
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.alpha(Config.md3.on_surface, 0.54)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    maximumLineCount: 2
                                    text: modelData.notes || (!taskDelegateRoot.localTask && modelData.taskListName && modelData.taskListName !== "Tasks" && modelData.taskListName !== "Việc cần làm của tôi" ? modelData.taskListName : "")
                                    visible: Boolean(text)
                                    wrapMode: Text.Wrap
                                }
                            }
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: dueContent.implicitWidth + 18
                                border.color: Config.alpha(Config.md3.primary, 0.24)
                                border.width: 1
                                color: Config.alpha(Config.md3.primary, 0.11)
                                radius: 10
                                visible: Boolean(modelData.due)

                                Row {
                                    id: dueContent

                                    anchors.centerIn: parent
                                    spacing: 6

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 14
                                        layer.enabled: true
                                        source: Quickshell.iconPath("x-office-calendar-symbolic")
                                        width: 14

                                        layer.effect: ColorOverlay {
                                            color: Config.md3.primary
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Config.md3.primary
                                        font.family: Config.fontName
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        text: {
                                            if (!modelData.due)
                                                return "";
                                            var parts = String(modelData.due).slice(0, 10).split("-");
                                            var dueDate = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
                                            var shortDate = String(dueDate.getDate()).padStart(2, "0") + "/" + String(dueDate.getMonth() + 1).padStart(2, "0");
                                            return taskList.width < 420 ? shortDate : shortDate + "/" + dueDate.getFullYear();
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
    Rectangle {
        id: addEventPanel

        color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.56 : 0.22)
        height: parent.height
        radius: 20
        width: parent.width
        y: showAddEvent ? 0 : parent.height

        Behavior on y {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        DragHandler {
            enabled: !root.saving
            target: null
            xAxis.enabled: true
            yAxis.enabled: false

            onTranslationChanged: {
                if (translation.x > 150) {
                    showAddEvent = false;
                }
            }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    text: editingTaskId ? qsTr("Edit task") : qsTr("Add task")
                }
            }
            Flickable {
                id: formFlickable

                Layout.fillHeight: true
                Layout.fillWidth: true
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                contentHeight: formLayout.implicitHeight
                contentWidth: width
                enabled: !root.saving

                ColumnLayout {
                    id: formLayout

                    spacing: 25
                    width: formFlickable.width

                    SettingsSelectRow {
                        Layout.fillWidth: true
                        enabled: root.editingTaskId === "" && !root.saving
                        label: root.editingTaskId ? qsTr("Saved in") : qsTr("Create in")
                        valueBadgeColor: root.editingTaskSource === "local" ? Config.md3.primary : CalendarService.taskAccountColor(root.editingAccountId)
                        valueText: root.editingTaskSource === "local" ? qsTr("Local tasks") : GoogleService.accountLabel(root.editingAccountId) || qsTr("Choose account")

                        onClicked: sourceItem => root.openSelector("destination", sourceItem)
                    }
                    SettingsSelectRow {
                        Layout.fillWidth: true
                        enabled: root.editingTaskId === "" && !root.saving
                        label: qsTr("Task list")
                        valueBadgeColor: CalendarService.taskListColor(root.editingAccountId, root.editingListId)
                        valueText: root.selectedLabel(GoogleService.listsForAccount(root.editingAccountId), root.editingListId, qsTr("Choose list"))
                        visible: root.editingTaskSource === "google"

                        onClicked: sourceItem => root.openSelector("list", sourceItem)
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.error
                        font.family: Config.fontName
                        font.pixelSize: 13
                        text: root.formError || (root.editingTaskSource === "google" ? GoogleService.errorForAccount(root.editingAccountId) : "")
                        visible: text !== ""
                        wrapMode: Text.Wrap
                    }
                    FormTextField {
                        id: titleField

                        Layout.fillWidth: true
                        label: "Title"
                        placeholder: "What needs to be done?"
                        text: newTaskTitle

                        onTextChanged: newTaskTitle = text
                    }
                    FormTextField {
                        Layout.fillWidth: true
                        label: "Due Date"
                        placeholder: "Select due date..."
                        readOnly: true
                        text: newTaskDue

                        onClicked: datePickerPopup.open()
                    }
                    FormTextField {
                        id: notesField

                        Layout.fillWidth: true
                        label: "Notes"
                        multiline: true
                        placeholder: "Notes..."
                        text: newTaskNotes

                        onTextChanged: newTaskNotes = text
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: root.canSave ? (saveBtn.pressed ? Config.alpha(Config.md3.primary, 0.8) : Config.md3.primary) : Config.alpha(Config.md3.on_surface, 0.10)
                radius: 15

                Text {
                    anchors.centerIn: parent
                    color: root.canSave ? Config.md3.on_primary : Config.md3.outline
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: root.saving ? qsTr("Saving…") : qsTr("Save")
                }
                MouseArea {
                    id: saveBtn

                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: root.canSave

                    onClicked: root.saveTask()
                }
            }
        }
    }
    DatePickerPopup {
        id: datePickerPopup

        backdropRadius: root.popupBackdropRadius
        placementParent: root.popupBackdropHost || root
        selectedDate: root.newTaskDue

        onDateCleared: root.newTaskDue = ""
        onDateSelected: value => root.newTaskDue = value
    }
    SelectPopup {
        anchors.fill: parent
        itemActive: item => item.id === (root.activeSelectorKind === "destination" ? root.editingAccountId : root.activeSelectorKind === "list" ? root.editingListId : root.selectedTaskListKey)
        itemColor: item => item && item.color ? item.color : ""
        itemLabel: item => item.label
        model: root.activeSelectorOptions
        opened: root.selectionKind !== ""
        popupWidth: Math.min(420, root.width - 24)
        popupY: root.selectionY

        onDismissed: root.selectionKind = ""
        onItemSelected: item => root.selectOption(item)
    }
    Connections {
        function onTaskListsChanged() {
            if (!root.listOptions.some(item => item.id === root.selectedTaskListKey))
                root.selectedTaskListKey = "";
            if (root.showAddEvent && root.editingTaskSource === "google" && root.editingTaskId === "" && root.editingListId === "") {
                var lists = GoogleService.listsForAccount(root.editingAccountId);
                if (lists.length > 0)
                    root.editingListId = lists[0].id;
            }
        }

        target: GoogleService
    }
}
