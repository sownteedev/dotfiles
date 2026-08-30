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

    property int currentTab: 0 // 0: To do, 1: Done
    property string editingTaskId: ""
    property string editingTaskSource: "local"
    property var filteredTasks: {
        var list = [];
        var sourceTasks = taskSource === "google" ? GoogleService.allTasks : LocalTaskService.tasks;
        if (!sourceTasks)
            return list;
        for (var i = 0; i < sourceTasks.length; i++) {
            var task = sourceTasks[i];
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
    property bool googleDropHovered: false
    property string newTaskDue: ""
    property string newTaskNotes: ""
    property string newTaskTitle: ""
    readonly property Item popupBackdropHost: controlLeftWindow.topPopupBackdropHost
    readonly property real popupBackdropRadius: controlLeftWindow.topPopupBackdropRadius
    property bool showAddEvent: false
    property string taskSource: "local"

    function openNewTask() {
        editingTaskId = "";
        editingTaskSource = taskSource;
        newTaskTitle = "";
        newTaskDue = "";
        newTaskNotes = "";
        titleField.text = "";
        notesField.text = "";
        showAddEvent = true;
    }
    function openTask(task) {
        editingTaskId = String(task.id || "");
        editingTaskSource = taskSource;
        newTaskTitle = task.title || "";
        newTaskNotes = task.notes || "";
        titleField.text = newTaskTitle;
        notesField.text = newTaskNotes;
        if (task.due) {
            var d = new Date(task.due);
            newTaskDue = String(d.getDate()).padStart(2, '0') + "/" + String(d.getMonth() + 1).padStart(2, '0') + "/" + d.getFullYear();
        } else {
            newTaskDue = "";
        }
        showAddEvent = true;
    }
    function syncLocalTask(taskId) {
        var stableTaskId = String(taskId || "");
        if (stableTaskId === "")
            return;
        // Enqueue before changing the model. Switching source destroys the
        // Local delegate that owns the click/drag callback.
        if (LocalTaskService.syncToGoogle(stableTaskId)) {
            taskSource = "google";
            return;
        }
        Quickshell.execDetached(["notify-send", "-a", "Todo", "-u", "normal", "-h", "boolean:transient:true", "Could not start Google sync", LocalTaskService.syncError || "The local task could not be queued"]);
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
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.maximumWidth: 190
                    Layout.minimumWidth: 100
                    border.color: Config.alpha(Config.md3.on_surface, 0.08)
                    border.width: 1
                    color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.72 : 0.38)
                    radius: 14

                    Rectangle {
                        color: Config.md3.secondary_container
                        height: parent.height - 6
                        radius: 11
                        width: (parent.width - 6) / 2
                        x: 3 + (taskSource === "google" ? width : 0)
                        y: 3

                        Behavior on x {
                            NumberAnimation {
                                duration: Config.animationDuration(220)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Repeater {
                            model: [
                                {
                                    label: qsTr("Local"),
                                    value: "local"
                                },
                                {
                                    label: qsTr("Google"),
                                    value: "google"
                                }
                            ]

                            delegate: Item {
                                required property var modelData

                                Accessible.name: modelData.label
                                Accessible.role: Accessible.Button
                                height: parent.height
                                width: parent.width / 2

                                Rectangle {
                                    anchors.fill: parent
                                    color: modelData.value === "google" && root.googleDropHovered ? Config.alpha(Config.md3.primary, 0.18) : "transparent"
                                    radius: 11
                                }
                                Text {
                                    anchors.centerIn: parent
                                    color: taskSource === modelData.value ? Config.md3.on_secondary_container : Config.alpha(Config.md3.on_surface, 0.64)
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    text: modelData.label
                                }
                                DropArea {
                                    anchors.fill: parent
                                    enabled: modelData.value === "google" && GoogleService.authenticated
                                    keys: ["local-task"]
                                    z: 1

                                    onDropped: drop => {
                                        root.googleDropHovered = false;
                                        if (drop.source && drop.source.localTaskId) {
                                            root.syncLocalTask(drop.source.localTaskId);
                                            drop.acceptProposedAction();
                                        }
                                    }
                                    onEntered: root.googleDropHovered = true
                                    onExited: root.googleDropHovered = false
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    z: 2

                                    onClicked: {
                                        if (modelData.value === "google" && !GoogleService.authenticated) {
                                            GoogleService.requireAuthentication("todo-google-tab");
                                            return;
                                        }
                                        root.taskSource = modelData.value;
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
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
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ProductivityEmptyState {
                actionText: qsTr("Add task")
                actionVisible: currentTab === 0
                anchors.centerIn: parent
                busy: taskSource === "google" && (GoogleService.taskActionBusy || GoogleService.isLoadingTasks)
                description: {
                    if (busy)
                        return qsTr("Fetching the latest task list");
                    if (currentTab === 1)
                        return qsTr("Completed tasks will appear here");
                    return qsTr("Create a task to start organizing your day");
                }
                iconName: currentTab === 0 ? "view-list-symbolic" : "checkbox-checked-symbolic"
                title: {
                    if (busy)
                        return qsTr("Syncing tasks…");
                    if (currentTab === 1)
                        return qsTr("Nothing completed yet");
                    return taskSource === "google" ? qsTr("No Google tasks") : qsTr("No local tasks");
                }
                visible: filteredTasks.length === 0
                width: Math.min(parent.width - 40, 320)

                onActionTriggered: root.openNewTask()
            }
            ListView {
                id: taskList

                anchors.fill: parent
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                model: filteredTasks
                spacing: 10

                delegate: Item {
                    required property var modelData

                    height: Math.max(80, taskContent.implicitHeight + 28)
                    width: taskList.width

                    Rectangle {
                        anchors.fill: parent
                        color: Config.md3.error
                        radius: 17
                        visible: cardContent.swipeX < 0

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
                                text: qsTr("Delete")
                            }
                        }
                    }
                    Rectangle {
                        id: cardContent

                        property string localTaskId: taskSource === "local" ? String(modelData.id || "") : ""
                        property real swipeX: 0
                        property real syncDragY: 0
                        property bool syncDragging: false
                        readonly property bool taskSyncing: taskSource === "local" && LocalTaskService.isSyncing(modelData.id)

                        Drag.active: syncDragging
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: 20
                        Drag.keys: ["local-task"]
                        Drag.supportedActions: Qt.CopyAction
                        border.color: taskCardMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.28) : Config.alpha(Config.md3.on_surface, 0.08)
                        border.width: 1
                        color: Qt.tint(taskCardMouse.pressed ? Config.alpha(Config.md3.primary, 0.13) : taskCardMouse.containsMouse ? Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.9 : 0.58) : Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.76 : 0.4), Config.alpha(Config.md3.error, Math.min(1.0, Math.abs(swipeX) / 80)))
                        height: parent.height
                        opacity: syncDragging ? 0.78 : taskSyncing ? 0.6 : modelData.status === "completed" ? 0.72 : 1
                        radius: 17
                        scale: syncDragging ? 0.97 : 1
                        width: parent.width
                        x: swipeX
                        y: syncDragY
                        z: syncDragging ? 20 : 0

                        Behavior on swipeX {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        MouseArea {
                            id: taskCardMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !cardContent.taskSyncing && !googleSyncHandle.syncPressed
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
                            enabled: !cardContent.taskSyncing && !googleSyncHandle.syncPressed
                            target: null
                            xAxis.enabled: true
                            yAxis.enabled: false

                            onActiveChanged: {
                                if (!active) {
                                    if (cardContent.swipeX < -80) {
                                        if (taskSource === "local")
                                            LocalTaskService.deleteTask(modelData.id);
                                        else
                                            GoogleService.deleteTask("@default", modelData.id);
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
                            id: taskContent

                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Rectangle {
                                border.color: Config.md3.primary
                                border.width: 2
                                color: modelData.status === "completed" ? Config.md3.primary : "transparent"
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
                                    enabled: !cardContent.taskSyncing

                                    onClicked: {
                                        var newStatus = modelData.status === "completed" ? "needsAction" : "completed";
                                        if (taskSource === "local")
                                            LocalTaskService.updateTask(modelData.id, undefined, undefined, undefined, newStatus);
                                        else
                                            GoogleService.updateTask("@default", modelData.id, undefined, undefined, undefined, newStatus);
                                    }
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
                                    font.weight: Font.Bold
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
                                    text: modelData.notes || ""
                                    visible: Boolean(modelData.notes)
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
                                        font.weight: Font.Bold
                                        text: {
                                            if (!modelData.due)
                                                return "";
                                            var dueDate = new Date(modelData.due);
                                            var shortDate = String(dueDate.getDate()).padStart(2, "0") + "/" + String(dueDate.getMonth() + 1).padStart(2, "0");
                                            return taskList.width < 420 ? shortDate : shortDate + "/" + dueDate.getFullYear();
                                        }
                                    }
                                }
                            }
                            Item {
                                id: googleSyncHandle

                                property bool completedDrag: false
                                property real pressSceneY: 0
                                property bool syncPressed: false

                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredHeight: 36
                                Layout.preferredWidth: 40
                                visible: taskSource === "local" && GoogleService.authenticated

                                Rectangle {
                                    anchors.fill: parent
                                    border.color: Config.alpha(Config.md3.primary, syncMouse.containsMouse ? 0.42 : 0.26)
                                    border.width: 1
                                    color: syncMouse.pressed ? Config.alpha(Config.md3.primary, 0.2) : syncMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.15) : Config.alpha(Config.md3.primary, 0.1)
                                    radius: 11

                                    IconImage {
                                        anchors.centerIn: parent
                                        height: 19
                                        layer.enabled: true
                                        opacity: cardContent.taskSyncing ? 0.5 : 1
                                        source: "file://" + Config.quickshellDir + "/assets/icons/cloud-upload.svg"
                                        width: 19

                                        layer.effect: ColorOverlay {
                                            color: Config.md3.primary
                                        }
                                    }
                                }
                                MouseArea {
                                    id: syncMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !cardContent.taskSyncing
                                    hoverEnabled: true
                                    preventStealing: true

                                    onCanceled: {
                                        googleSyncHandle.completedDrag = false;
                                        googleSyncHandle.syncPressed = false;
                                        cardContent.syncDragging = false;
                                        cardContent.syncDragY = 0;
                                    }
                                    onClicked: {
                                        var shouldSync = !googleSyncHandle.completedDrag;
                                        googleSyncHandle.completedDrag = false;
                                        if (shouldSync)
                                            root.syncLocalTask(modelData.id);
                                    }
                                    onPositionChanged: mouse => {
                                        var scenePoint = googleSyncHandle.mapToItem(null, mouse.x, mouse.y);
                                        var offset = scenePoint.y - googleSyncHandle.pressSceneY;
                                        if (pressed && offset < -8) {
                                            cardContent.syncDragging = true;
                                            cardContent.syncDragY = offset;
                                        }
                                    }
                                    onPressed: mouse => {
                                        googleSyncHandle.completedDrag = false;
                                        googleSyncHandle.syncPressed = true;
                                        googleSyncHandle.pressSceneY = googleSyncHandle.mapToItem(null, mouse.x, mouse.y).y;
                                        cardContent.swipeX = 0;
                                    }
                                    onReleased: {
                                        googleSyncHandle.syncPressed = false;
                                        if (cardContent.syncDragging) {
                                            googleSyncHandle.completedDrag = true;
                                            cardContent.Drag.drop();
                                            cardContent.syncDragging = false;
                                            cardContent.syncDragY = 0;
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
                    text: editingTaskId ? "Edit task" : "Add task"
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

                ColumnLayout {
                    id: formLayout

                    spacing: 25
                    width: formFlickable.width

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
                color: newTaskTitle.trim() !== "" ? (saveBtn.pressed ? Config.alpha(Config.md3.primary, 0.8) : Config.md3.primary) : Config.alpha(Config.md3.on_surface, 0.10)
                radius: 15

                Text {
                    anchors.centerIn: parent
                    color: newTaskTitle.trim() !== "" ? Config.md3.on_primary : Config.md3.outline
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: "Save"
                }
                MouseArea {
                    id: saveBtn

                    anchors.fill: parent
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: newTaskTitle.trim() !== ""

                    onClicked: {
                        var isoDue = undefined;
                        if (newTaskDue) {
                            var parts = newTaskDue.split("/");
                            if (parts.length === 3) {
                                isoDue = parts[2] + "-" + parts[1] + "-" + parts[0];
                            }
                        }

                        if (editingTaskId) {
                            if (editingTaskSource === "local")
                                LocalTaskService.updateTask(editingTaskId, newTaskTitle, isoDue, newTaskNotes, undefined);
                            else
                                GoogleService.updateTask("@default", editingTaskId, newTaskTitle, isoDue, newTaskNotes, undefined);
                        } else {
                            if (editingTaskSource === "google" && GoogleService.authenticated)
                                GoogleService.createTask("@default", newTaskTitle, isoDue, newTaskNotes);
                            else
                                LocalTaskService.createTask(newTaskTitle, isoDue, newTaskNotes);
                        }
                        editingTaskId = "";
                        newTaskTitle = "";
                        newTaskDue = "";
                        newTaskNotes = "";
                        titleField.text = "";
                        notesField.text = "";
                        showAddEvent = false;
                    }
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
    Connections {
        function onAuthenticatedChanged() {
            if (!GoogleService.authenticated && root.taskSource === "google")
                root.taskSource = "local";
        }
        function onAuthenticationSucceeded(context) {
            if (context === "todo-google-tab")
                root.taskSource = "google";
        }

        target: GoogleService
    }
    Connections {
        function onSyncFinished(taskId, succeeded) {
            if (succeeded) {
                root.taskSource = "google";
                return;
            }
            root.taskSource = "local";
            Quickshell.execDetached(["notify-send", "-a", "Todo", "-u", "normal", "-h", "boolean:transient:true", "Google Tasks sync failed", LocalTaskService.syncError || "The local task was kept on this device"]);
        }

        target: LocalTaskService
    }
    GoogleAuthPanel {
        anchors.fill: parent
    }
}
