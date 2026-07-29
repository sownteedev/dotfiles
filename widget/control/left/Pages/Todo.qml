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
    property var filteredTasks: {
        var list = [];
        if (typeof GoogleService === 'undefined' || !GoogleService.allTasks)
            return list;
        for (var i = 0; i < GoogleService.allTasks.length; i++) {
            var task = GoogleService.allTasks[i];
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
    property string newTaskDue: ""
    property string newTaskNotes: ""
    property string newTaskTitle: ""
    property bool showAddEvent: false

    function openNewTask() {
        editingTaskId = "";
        newTaskTitle = "";
        newTaskDue = "";
        newTaskNotes = "";
        showAddEvent = true;
    }

    anchors.fill: parent

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

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
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: addButtonArea.pressed ? Config.md3.surface_container_high : Config.md3.surface_container
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

                    onClicked: {
                        if (GoogleService.requireAuthentication("todo-add"))
                            root.openNewTask();
                    }
                }
            }
        }
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                visible: filteredTasks.length === 0 && (typeof GoogleService === 'undefined' || !GoogleService.isLoadingTasks)

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
                    text: "No tasks"
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

                        property real swipeX: 0

                        color: Qt.tint(Config.md3.surface_container, Config.alpha(Config.md3.error, Math.min(1.0, Math.abs(swipeX) / 80)))
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
                            anchors.fill: parent

                            onClicked: {
                                if (cardContent.swipeX < 0) {
                                    cardContent.swipeX = 0;
                                    return;
                                }

                                editingTaskId = modelData.id;
                                newTaskTitle = modelData.title || "";
                                newTaskNotes = modelData.notes || "";
                                if (modelData.due) {
                                    var d = new Date(modelData.due);
                                    newTaskDue = String(d.getDate()).padStart(2, '0') + "/" + String(d.getMonth() + 1).padStart(2, '0') + "/" + d.getFullYear();
                                } else {
                                    newTaskDue = "";
                                }
                                showAddEvent = true;
                            }
                        }
                        DragHandler {
                            target: null
                            xAxis.enabled: true
                            yAxis.enabled: false

                            onActiveChanged: {
                                if (!active) {
                                    if (cardContent.swipeX < -80) {
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

                                    onClicked: {
                                        var newStatus = modelData.status === "completed" ? "needsAction" : "completed";
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
                                Layout.preferredWidth: dueText.implicitWidth + 18
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
                        }
                    }
                }
            }
        }
    }
    Rectangle {
        id: addEventPanel

        color: Config.md3.surface
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
                color: saveBtn.pressed ? Config.alpha(Config.md3.primary, 0.8) : Config.md3.primary
                radius: 15

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.background
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: "Save"
                }
                MouseArea {
                    id: saveBtn

                    anchors.fill: parent

                    onClicked: {
                        var isoDue = undefined;
                        if (newTaskDue) {
                            var parts = newTaskDue.split("/");
                            if (parts.length === 3) {
                                isoDue = parts[2] + "-" + parts[1] + "-" + parts[0];
                            }
                        }

                        if (editingTaskId) {
                            GoogleService.updateTask("@default", editingTaskId, newTaskTitle, isoDue, newTaskNotes, undefined);
                        } else {
                            GoogleService.createTask("@default", newTaskTitle, isoDue, newTaskNotes);
                        }
                        showAddEvent = false;
                    }
                }
            }
        }
    }
    DatePickerPopup {
        id: datePickerPopup

        anchors.centerIn: parent
        selectedDate: root.newTaskDue

        onDateCleared: root.newTaskDue = ""
        onDateSelected: value => root.newTaskDue = value
    }
    Connections {
        function onAuthenticationSucceeded(context) {
            if (context === "todo-add")
                root.openNewTask();
        }

        target: GoogleService
    }
    GoogleAuthPanel {
        anchors.fill: parent
    }
}
