import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import ".."
import "../../"

Popup {
    id: root

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    property Item placementParent: null
    property string selectedDate: ""

    signal dateCleared
    signal dateSelected(string value)

    function formatDate(date) {
        return String(date.getDate()).padStart(2, "0") + "/" + String(date.getMonth() + 1).padStart(2, "0") + "/" + date.getFullYear();
    }
    function isSameDate(first, second) {
        return first.getDate() === second.getDate() && first.getMonth() === second.getMonth() && first.getFullYear() === second.getFullYear();
    }
    function selectDate(date) {
        root.dateSelected(root.formatDate(date));
        root.close();
    }
    function updatePlacement() {
        if (!placementParent || !parent)
            return;
        var origin = placementParent.mapToItem(parent, 0, 0);
        x = Math.max(8, Math.min(origin.x + (placementParent.width - width) / 2, parent.width - width - 8));
        y = Math.max(8, Math.min(origin.y + (placementParent.height - height) / 2, parent.height - height - 8));
    }

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    focus: true
    height: placementParent ? Responsive.fitWithMargins(430, placementParent.height, 8, 330) : parent ? Responsive.fitWithMargins(430, parent.height, 8, 330) : 430
    modal: true
    padding: 16
    parent: Overlay.overlay
    width: placementParent ? Responsive.fitWithMargins(360, placementParent.width, 8, 300) : parent ? Responsive.fitWithMargins(360, parent.width, 8, 300) : 360

    Overlay.modal: Rectangle {
        color: Config.alpha(Config.md3.scrim, Config.lightTheme ? 0.22 : 0.38)
    }
    background: Item {
        ShellShadow {
            cornerRadius: pickerSurface.radius
            target: pickerSurface
        }
        Rectangle {
            id: pickerSurface

            anchors.fill: parent
            border.color: Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.14 : 0.1)
            border.width: 1
            color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.97 : 0.92)
            radius: Math.min(24, root.width / 2, root.height / 2)
        }
    }
    contentItem: ColumnLayout {
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 8

            Rectangle {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                color: previousArea.pressed ? Config.alpha(Config.md3.on_surface, 0.14) : previousArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.085) : Config.alpha(Config.md3.on_surface, 0.035)
                radius: 20

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(100)
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 18
                    layer.enabled: true
                    source: Quickshell.iconPath("go-previous-symbolic")
                    width: 18

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface
                    }
                }
                MouseArea {
                    id: previousArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        if (root.currentMonth === 0) {
                            root.currentMonth = 11;
                            root.currentYear--;
                        } else {
                            root.currentMonth--;
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                text: new Date(root.currentYear, root.currentMonth, 1).toLocaleString(Qt.locale(), "MMMM yyyy")
                verticalAlignment: Text.AlignVCenter
            }
            Rectangle {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                color: nextArea.pressed ? Config.alpha(Config.md3.on_surface, 0.14) : nextArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.085) : Config.alpha(Config.md3.on_surface, 0.035)
                radius: 20

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(100)
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 18
                    layer.enabled: true
                    source: Quickshell.iconPath("go-next-symbolic")
                    width: 18

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface
                    }
                }
                MouseArea {
                    id: nextArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        if (root.currentMonth === 11) {
                            root.currentMonth = 0;
                            root.currentYear++;
                        } else {
                            root.currentMonth++;
                        }
                    }
                }
            }
        }
        DayOfWeekRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            locale: monthGrid.locale

            delegate: Text {
                color: Config.alpha(Config.md3.on_surface, 0.5)
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                verticalAlignment: Text.AlignVCenter
            }
        }
        MonthGrid {
            id: monthGrid

            Layout.fillHeight: true
            Layout.fillWidth: true
            month: root.currentMonth
            year: root.currentYear

            delegate: Item {
                readonly property bool inCurrentMonth: model.month === monthGrid.month
                readonly property bool selected: root.selectedDate !== "" && root.formatDate(model.date) === root.selectedDate
                readonly property bool today: root.isSameDate(model.date, new Date())

                Rectangle {
                    anchors.centerIn: parent
                    border.color: today && !selected ? Config.alpha(Config.md3.primary, 0.72) : "transparent"
                    border.width: today && !selected ? 1 : 0
                    color: selected ? Config.md3.primary : dayArea.pressed ? Config.alpha(Config.md3.on_surface, 0.16) : dayArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : today ? Config.alpha(Config.md3.primary, 0.1) : "transparent"
                    height: Math.min(38, parent.height - 2, parent.width - 2)
                    radius: height / 2
                    width: height

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(100)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: selected ? Config.md3.on_primary : inCurrentMonth ? Config.alpha(Config.md3.on_surface, 0.88) : Config.alpha(Config.md3.on_surface, 0.24)
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: selected || today ? Font.Bold : Font.Medium
                        text: model.day

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(100)
                            }
                        }
                    }
                }
                MouseArea {
                    id: dayArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.selectDate(model.date)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                border.color: Config.alpha(Config.md3.primary, 0.18)
                border.width: 1
                color: todayArea.pressed ? Config.alpha(Config.md3.primary, 0.18) : todayArea.containsMouse ? Config.alpha(Config.md3.primary, 0.13) : Config.alpha(Config.md3.primary, 0.08)
                radius: 20

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(100)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.primary
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    text: qsTr("Today")
                }
                MouseArea {
                    id: todayArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.selectDate(new Date())
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                border.color: Config.alpha(Config.md3.error, 0.18)
                border.width: 1
                color: clearArea.pressed ? Config.alpha(Config.md3.error, 0.18) : clearArea.containsMouse ? Config.alpha(Config.md3.error, 0.13) : Config.alpha(Config.md3.error, 0.075)
                radius: 20

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(100)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    text: qsTr("Clear")
                }
                MouseArea {
                    id: clearArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        root.dateCleared();
                        root.close();
                    }
                }
            }
        }
    }
    enter: Transition {
        NumberAnimation {
            duration: Config.animationDuration(170)
            easing.type: Easing.OutCubic
            from: 0
            property: "opacity"
            to: 1
        }
    }
    exit: Transition {
        NumberAnimation {
            duration: Config.animationDuration(120)
            easing.type: Easing.InCubic
            from: 1
            property: "opacity"
            to: 0
        }
    }

    onAboutToShow: updatePlacement()
    onOpened: {
        var parts = selectedDate.split("/");
        if (parts.length === 3) {
            var month = parseInt(parts[1], 10) - 1;
            var year = parseInt(parts[2], 10);
            if (!isNaN(month) && !isNaN(year)) {
                currentMonth = month;
                currentYear = year;
                return;
            }
        }
        var today = new Date();
        currentMonth = today.getMonth();
        currentYear = today.getFullYear();
    }
}
