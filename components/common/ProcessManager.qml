pragma ComponentBehavior: Bound

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import ".."

Item {
    id: root

    property string armedName: ""
    property int armedPid: -1
    readonly property var displayedProcesses: {
        var revision = processRevision;
        var query = searchText.trim().toLowerCase();
        var results = [];
        if (!processList)
            return results;
        for (var index = 0; index < processList.count; index++) {
            var process = processList.get(index);
            if (query === "" || String(process.name || "").toLowerCase().includes(query) || String(process.pid || "").includes(query)) {
                results.push(process);
                if (results.length === 5)
                    break;
            }
        }
        return results;
    }
    readonly property int filteredCount: displayedProcesses.length
    property color lineColor: Config.md3.primary
    readonly property real maximumValue: {
        var maximum = 1;
        for (var index = 0; index < displayedProcesses.length; index++)
            maximum = Math.max(maximum, Number(displayedProcesses[index].val) || 0);
        return maximum;
    }
    property var processList: null
    property int processRevision: 0
    property string searchText: ""
    property int terminatingPid: -1
    property string terminationError: ""
    property string valueSuffix: "%"

    signal terminateRequested(int pid, string name)

    function armTermination(pid, name) {
        armedPid = pid;
        armedName = name;
        confirmTimer.restart();
    }
    function requestTermination(pid, name) {
        if (armedPid !== pid || armedName !== name) {
            armTermination(pid, name);
            return;
        }
        confirmTimer.stop();
        armedName = "";
        armedPid = -1;
        terminateRequested(pid, name);
    }

    implicitHeight: 226

    onProcessRevisionChanged: {
        if (armedPid <= 0 || !processList)
            return;
        for (var index = 0; index < processList.count; index++) {
            if (Number(processList.get(index).pid) === armedPid && String(processList.get(index).name || "") === armedName)
                return;
        }
        armedName = "";
        armedPid = -1;
        confirmTimer.stop();
    }

    Timer {
        id: confirmTimer

        interval: 2500

        onTriggered: {
            root.armedName = "";
            root.armedPid = -1;
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            border.color: searchInput.activeFocus ? Config.alpha(root.lineColor, 0.56) : "transparent"
            border.width: 1
            color: Config.alpha(Config.md3.on_surface, 0.055)
            radius: 12

            Behavior on border.color {
                ColorAnimation {
                    duration: 140
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 7
                spacing: 9

                IconImage {
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: 16
                    layer.enabled: true
                    source: Quickshell.iconPath("system-search-symbolic")

                    layer.effect: ColorOverlay {
                        color: searchInput.activeFocus ? root.lineColor : Config.md3.on_surface_variant
                    }
                }
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    TextInput {
                        id: searchInput

                        activeFocusOnTab: true
                        anchors.fill: parent
                        clip: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: root.searchText
                        verticalAlignment: TextInput.AlignVCenter

                        Keys.onEscapePressed: event => {
                            if (text !== "") {
                                root.searchText = "";
                                event.accepted = true;
                            }
                        }
                        onTextEdited: root.searchText = text
                    }
                    Text {
                        anchors.fill: parent
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        text: qsTr("Search by name or PID")
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text === ""
                    }
                }
                Rectangle {
                    id: clearButton

                    Accessible.name: qsTr("Clear process search")
                    Accessible.role: Accessible.Button
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 28
                    activeFocusOnTab: visible
                    color: clearMouse.containsMouse || activeFocus ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                    radius: 9
                    visible: root.searchText !== ""

                    Keys.onEnterPressed: {
                        root.searchText = "";
                        searchInput.forceActiveFocus();
                    }
                    Keys.onReturnPressed: {
                        root.searchText = "";
                        searchInput.forceActiveFocus();
                    }

                    IconImage {
                        anchors.centerIn: parent
                        height: 14
                        layer.enabled: true
                        source: Quickshell.iconPath("edit-clear-symbolic")
                        width: 14

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface_variant
                        }
                    }
                    MouseArea {
                        id: clearMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            root.searchText = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            Column {
                id: processColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                Repeater {
                    model: root.displayedProcesses

                    delegate: Item {
                        id: processRow

                        required property var modelData
                        readonly property string processName: String(modelData.name || "")
                        readonly property int processPid: Math.trunc(Number(modelData.pid))
                        readonly property real processValue: Number(modelData.val) || 0

                        height: 36
                        width: processColumn.width

                        Rectangle {
                            anchors.bottomMargin: 5
                            anchors.fill: parent
                            color: rowHover.hovered ? Config.alpha(Config.md3.on_surface, 0.055) : "transparent"
                            radius: 9

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            HoverHandler {
                                id: rowHover
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.top: parent.top
                                color: Config.alpha(root.lineColor, 0.11)
                                radius: parent.radius
                                width: parent.width * Math.min(1, processRow.processValue / root.maximumValue)

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 240
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 4
                                spacing: 8

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -2

                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        elide: Text.ElideMiddle
                                        font.family: Config.fontName
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        text: processRow.processName || qsTr("Unknown")
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface_variant
                                        font.family: Config.fontName
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        text: qsTr("PID %1").arg(processRow.processPid)
                                    }
                                }
                                Text {
                                    color: root.lineColor
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    text: processRow.processValue.toFixed(1) + root.valueSuffix
                                }
                                Rectangle {
                                    id: terminateButton

                                    readonly property bool armed: root.armedPid === processRow.processPid
                                    readonly property bool busy: root.terminatingPid === processRow.processPid

                                    Accessible.name: armed ? qsTr("Confirm ending %1").arg(processRow.processName) : qsTr("End %1").arg(processRow.processName)
                                    Accessible.role: Accessible.Button
                                    Layout.preferredHeight: 28
                                    Layout.preferredWidth: armed ? 72 : 28
                                    activeFocusOnTab: true
                                    color: armed ? Config.md3.error_container : (terminateMouse.containsMouse || activeFocus ? Config.alpha(Config.md3.error_container, 0.74) : Config.alpha(Config.md3.on_surface, 0.045))
                                    enabled: processRow.processPid > 1 && root.terminatingPid < 0
                                    opacity: enabled ? 1 : 0.45
                                    radius: 9

                                    Behavior on Layout.preferredWidth {
                                        NumberAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    Keys.onEnterPressed: root.requestTermination(processRow.processPid, processRow.processName)
                                    Keys.onReturnPressed: root.requestTermination(processRow.processPid, processRow.processName)

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        IconImage {
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 14
                                            layer.enabled: true
                                            source: Quickshell.iconPath("process-stop-symbolic")
                                            width: 14

                                            layer.effect: ColorOverlay {
                                                color: terminateButton.armed ? Config.md3.on_error_container : Config.md3.on_surface_variant
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Config.md3.on_error_container
                                            font.family: Config.fontName
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            text: qsTr("Confirm")
                                            visible: terminateButton.armed
                                        }
                                    }
                                    MouseArea {
                                        id: terminateMouse

                                        anchors.fill: parent
                                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        enabled: parent.enabled
                                        hoverEnabled: true

                                        onClicked: root.requestTermination(processRow.processPid, processRow.processName)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: root.filteredCount === 0

                LoadingIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    animated: visible
                    color: Config.md3.primary
                    height: 55
                    visible: !root.processList || root.processList.count === 0
                    width: 55
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Config.md3.outline
                    font.family: Config.fontName
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    text: root.processList && root.processList.count > 0 ? qsTr("No matching processes") : ""
                    visible: text !== ""
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                color: Config.md3.error_container
                height: 28
                radius: 9
                visible: root.terminationError !== ""
                width: Math.min(parent.width, errorText.implicitWidth + 24)

                Text {
                    id: errorText

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    color: Config.md3.on_error_container
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    text: root.terminationError
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
