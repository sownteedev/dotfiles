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
            Layout.fillWidth: true
            Layout.preferredHeight: 50

            // To do / Done toggle
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Config.alpha(Config.md3.on_surface, 0.08)
                height: 36
                radius: 18
                width: 120

                Rectangle {
                    color: Config.md3.primary
                    height: 30
                    layer.enabled: true
                    radius: 15
                    width: (parent.width - 6) / 2
                    x: 3 + currentTab * width
                    y: 3

                    layer.effect: DropShadow {
                        color: Config.alpha(Config.md3.background, 0.5)
                        radius: 4
                        samples: 9
                        verticalOffset: 2
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 0

                    Repeater {
                        model: [
                            {
                                label: "To do",
                                icon: "view-list-symbolic",
                                value: 0
                            },
                            {
                                label: "Done",
                                icon: "checkbox-checked-symbolic",
                                value: 1
                            }
                        ]

                        delegate: Item {
                            required property var modelData

                            height: parent.height
                            width: parent.width / 2

                            IconImage {
                                anchors.centerIn: parent
                                height: 22
                                layer.enabled: true
                                source: Quickshell.iconPath(modelData.icon)
                                width: 22

                                layer.effect: ColorOverlay {
                                    color: currentTab === modelData.value ? Config.md3.on_primary : Config.alpha(Config.md3.on_surface, 0.75)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 200
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
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                color: Config.alpha(Config.md3.on_surface, 0.08)
                height: 36
                radius: 18
                width: 190

                Rectangle {
                    color: Config.md3.secondary
                    height: 30
                    radius: 15
                    width: (parent.width - 6) / 2
                    x: 3 + (taskSource === "google" ? width : 0)
                    y: 3

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
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
                                label: "Local",
                                value: "local"
                            },
                            {
                                label: "Google",
                                value: "google"
                            }
                        ]

                        delegate: Item {
                            required property var modelData

                            height: parent.height
                            width: parent.width / 2

                            Rectangle {
                                anchors.fill: parent
                                color: modelData.value === "google" && root.googleDropHovered ? Config.alpha(Config.md3.primary, 0.22) : "transparent"
                                radius: 15
                            }
                            Text {
                                anchors.centerIn: parent
                                color: taskSource === modelData.value ? Config.md3.on_secondary : Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.Bold
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
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Config.alpha(Config.md3.on_surface, addButtonArea.pressed ? 0.16 : 0.09)
                height: 40
                radius: 20
                width: 40

                IconImage {
                    anchors.centerIn: parent
                    height: 20
                    layer.enabled: true
                    source: Quickshell.iconPath("list-add-symbolic")
                    width: 20

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface
                    }
                }
                MouseArea {
                    id: addButtonArea

                    anchors.fill: parent

                    onClicked: root.openNewTask()
                }
            }
        }
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                visible: filteredTasks.length === 0 && !(taskSource === "google" && GoogleService.isLoadingTasks)

                IconImage {
                    Layout.alignment: Qt.AlignHCenter
                    height: 48
                    layer.enabled: true
                    source: Quickshell.iconPath("view-list-symbolic")
                    width: 48

                    layer.effect: ColorOverlay {
                        color: Config.alpha(Config.md3.on_surface_variant, 0.3)
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: Config.alpha(Config.md3.on_surface, 0.3)
                    font.family: Config.fontName
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    text: taskSource === "google" ? (GoogleService.taskActionBusy || GoogleService.isLoadingTasks ? "Syncing…" : "No Google tasks") : "No local tasks"
                }
            }
            ListView {
                id: taskList

                anchors.fill: parent
                clip: true
                model: filteredTasks
                spacing: 15

                delegate: Item {
                    height: contentCol.implicitHeight + 40
                    width: taskList.width

                    Rectangle {
                        anchors.fill: parent
                        color: Config.md3.error
                        radius: 20
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
                                text: "Delete"
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
                        color: Qt.tint(Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.58 : 0.22), Config.alpha(Config.md3.error, Math.min(1.0, Math.abs(swipeX) / 80)))
                        height: parent.height
                        opacity: syncDragging ? 0.78 : taskSyncing ? 0.6 : 1
                        radius: 20
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
                            anchors.fill: parent
                            enabled: !cardContent.taskSyncing && !googleSyncHandle.syncPressed

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
                            id: contentCol

                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 15

                            Rectangle {
                                border.color: Config.md3.primary
                                border.width: 2
                                color: modelData.status === "completed" ? Config.md3.primary : "transparent"
                                height: 24
                                radius: 12
                                width: 24

                                IconImage {
                                    anchors.centerIn: parent
                                    height: 14
                                    layer.enabled: true
                                    source: Quickshell.iconPath("object-select-symbolic")
                                    visible: modelData.status === "completed"
                                    width: 14

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
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 14
                                    font.strikeout: modelData.status === "completed"
                                    font.weight: Font.Bold
                                    text: modelData.title || "No Title"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.outline
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    text: modelData.notes || ""
                                    visible: modelData.notes ? true : false
                                }
                            }
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: 92
                                border.color: Config.alpha(Config.md3.primary, 0.32)
                                border.width: 1
                                color: Config.alpha(Config.md3.primary, 0.14)
                                radius: 9
                                visible: modelData.due ? true : false

                                Text {
                                    id: dueText

                                    anchors.centerIn: parent
                                    color: Config.md3.primary
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    text: {
                                        if (!modelData.due)
                                            return "";
                                        var d = new Date(modelData.due);
                                        return String(d.getDate()).padStart(2, '0') + "/" + String(d.getMonth() + 1).padStart(2, '0') + "/" + d.getFullYear();
                                    }
                                }
                            }
                            Item {
                                id: googleSyncHandle

                                property bool completedDrag: false
                                property real pressSceneY: 0
                                property bool syncPressed: false

                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: 36
                                visible: taskSource === "local" && GoogleService.authenticated

                                Rectangle {
                                    anchors.fill: parent
                                    border.color: Config.alpha(Config.md3.primary, 0.35)
                                    border.width: 1
                                    color: Config.alpha(Config.md3.primary, 0.12)
                                    radius: 10

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
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !cardContent.taskSyncing
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

        placementParent: root
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
