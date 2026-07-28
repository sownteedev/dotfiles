import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

Popup {
    id: root

    property int currentMonth: new Date().getMonth()
    property int currentYear: new Date().getFullYear()
    property string selectedDate: ""

    signal dateCleared
    signal dateSelected(string value)

    function formatDate(date) {
        return String(date.getDate()).padStart(2, "0") + "/" + String(date.getMonth() + 1).padStart(2, "0") + "/" + date.getFullYear();
    }

    focus: true
    height: 380
    modal: true
    width: 320

    background: Rectangle {
        border.color: Config.md3.surface_container_high
        border.width: 1
        color: Config.md3.surface
        radius: 15
    }
    contentItem: ColumnLayout {
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Rectangle {
                color: previousArea.pressed ? Config.md3.surface_container_high : "transparent"
                height: 30
                radius: 15
                width: 30

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath("go-previous-symbolic")
                    width: 16

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface
                    }
                }
                MouseArea {
                    id: previousArea

                    anchors.fill: parent

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
                font.pixelSize: 16
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                text: new Date(root.currentYear, root.currentMonth, 1).toLocaleString(Qt.locale(), "MMMM yyyy")
            }
            Rectangle {
                color: nextArea.pressed ? Config.md3.surface_container_high : "transparent"
                height: 30
                radius: 15
                width: 30

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath("go-next-symbolic")
                    width: 16

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface
                    }
                }
                MouseArea {
                    id: nextArea

                    anchors.fill: parent

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
            locale: monthGrid.locale

            delegate: Text {
                color: Config.md3.outline
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

            delegate: Rectangle {
                color: dayArea.pressed ? Config.md3.surface_container_high : "transparent"
                radius: width / 2

                Text {
                    anchors.centerIn: parent
                    color: model.month === monthGrid.month ? Config.md3.on_surface : Config.md3.surface_container_highest
                    font.family: Config.fontName
                    font.pixelSize: 14
                    text: model.day
                }
                MouseArea {
                    id: dayArea

                    anchors.fill: parent

                    onClicked: {
                        root.dateSelected(root.formatDate(model.date));
                        root.close();
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: clearArea.pressed ? Config.md3.surface_container_high : Config.md3.surface_container
            radius: 10

            Text {
                anchors.centerIn: parent
                color: Config.md3.error
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                text: "Clear Date"
            }
            MouseArea {
                id: clearArea

                anchors.fill: parent

                onClicked: {
                    root.dateCleared();
                    root.close();
                }
            }
        }
    }

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
