import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    readonly property color accentColor: task.taskSource === "google" ? Config.md3.primary : Config.md3.tertiary
    required property var task

    signal completionRequested(var task)

    Accessible.name: qsTr("Complete %1").arg(task.title || qsTr("task"))
    Accessible.role: Accessible.Grouping
    border.color: Config.alpha(accentColor, cardHover.hovered ? 0.34 : 0.18)
    border.width: 1
    color: cardHover.hovered ? Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.9 : 0.58) : Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.76 : 0.4)
    height: Math.max(82, taskContent.implicitHeight + 28)
    radius: 17

    Behavior on border.color {
        ColorAnimation {
            duration: Config.animationDuration(140)
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Config.animationDuration(140)
        }
    }

    HoverHandler {
        id: cardHover
    }
    RowLayout {
        id: taskContent

        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 28
            Layout.preferredWidth: 28
            border.color: root.accentColor
            border.width: 2
            color: completeArea.containsMouse ? Config.alpha(root.accentColor, completeArea.pressed ? 0.24 : 0.12) : "transparent"
            radius: 14

            Behavior on color {
                ColorAnimation {
                    duration: Config.animationDuration(120)
                }
            }

            IconImage {
                anchors.centerIn: parent
                height: 15
                layer.enabled: true
                opacity: completeArea.containsMouse ? 1 : 0
                source: Quickshell.iconPath("object-select-symbolic")
                width: 15

                layer.effect: ColorOverlay {
                    color: root.accentColor
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animationDuration(120)
                    }
                }
            }
            MouseArea {
                id: completeArea

                Accessible.name: qsTr("Mark %1 complete").arg(root.task.title || qsTr("task"))
                Accessible.role: Accessible.Button
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: root.completionRequested(root.task)
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
                font.weight: Font.Bold
                text: root.task.title || qsTr("Untitled task")
            }
            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.56)
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.Medium
                maximumLineCount: 2
                text: root.task.notes || ""
                visible: Boolean(root.task.notes)
                wrapMode: Text.Wrap
            }
        }
        Rectangle {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.preferredHeight: 32
            Layout.preferredWidth: sourceContent.implicitWidth + 18
            border.color: Config.alpha(root.accentColor, 0.24)
            border.width: 1
            color: Config.alpha(root.accentColor, 0.11)
            radius: 10

            Row {
                id: sourceContent

                anchors.centerIn: parent
                spacing: 6

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 14
                    layer.enabled: true
                    source: Quickshell.iconPath("view-list-symbolic")
                    width: 14

                    layer.effect: ColorOverlay {
                        color: root.accentColor
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accentColor
                    font.family: Config.fontName
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    text: root.task.taskSource === "google" ? qsTr("Google task") : qsTr("Local task")
                }
            }
        }
    }
}
