import ".."
import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property int dimDuration: 5
    property int displayTimeout: 600
    property int lockTimeout: 600
    property string profileLabel: qsTr("Shared policy")
    property string sleepAction: "suspend"
    property int sleepTimeout: 0
    readonly property var steps: [
        {
            "icon": "system-lock-screen-symbolic",
            "label": qsTr("Lock"),
            "value": durationLabel(lockTimeout)
        },
        {
            "icon": "display-brightness-symbolic",
            "label": qsTr("Dim"),
            "value": dimDuration > 0 && displayTimeout > dimDuration ? qsTr("%1 before off").arg(durationLabel(dimDuration)) : qsTr("Inactive")
        },
        {
            "icon": "video-display-symbolic",
            "label": qsTr("Display off"),
            "value": durationLabel(displayTimeout)
        },
        {
            "icon": sleepAction === "hibernate" ? "weather-snow-symbolic" : "weather-clear-night-symbolic",
            "label": sleepActionLabel(sleepAction),
            "value": sleepAction === "none" ? qsTr("Disabled") : durationLabel(sleepTimeout)
        }
    ]

    function durationLabel(seconds) {
        var value = Math.max(0, Math.round(Number(seconds) || 0));
        if (value === 0)
            return qsTr("Never");
        if (value < 60)
            return value === 1 ? qsTr("1 second") : qsTr("%1 seconds").arg(value);
        if (value % 3600 === 0) {
            var hours = value / 3600;
            return hours === 1 ? qsTr("1 hour") : qsTr("%1 hours").arg(hours);
        }
        if (value % 60 === 0) {
            var minutes = value / 60;
            return minutes === 1 ? qsTr("1 minute") : qsTr("%1 minutes").arg(minutes);
        }
        return qsTr("%1 min %2 sec").arg(Math.floor(value / 60)).arg(value % 60);
    }
    function sleepActionLabel(action) {
        switch (String(action || "none")) {
        case "hibernate":
            return qsTr("Hibernate");
        case "suspend-then-hibernate":
            return qsTr("Suspend → Hibernate");
        case "suspend":
            return qsTr("Suspend");
        default:
            return qsTr("Sleep");
        }
    }

    color: Config.alpha(Config.md3.on_surface, 0.035)
    implicitHeight: summary.implicitHeight + 24
    radius: 14

    ColumnLayout {
        id: summary

        anchors.fill: parent
        anchors.margins: 12
        spacing: 9

        Text {
            Layout.fillWidth: true
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: 12
            font.weight: Font.DemiBold
            text: root.profileLabel
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: 8
            columns: root.width >= 760 ? 4 : 2
            rowSpacing: 8
            uniformCellWidths: true

            Repeater {
                model: root.steps

                delegate: Rectangle {
                    id: stepTile

                    required property var modelData

                    Layout.fillWidth: true
                    color: Config.alpha(root.accentColor, 0.075)
                    implicitHeight: 62
                    radius: 11

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 9

                        Rectangle {
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: 32
                            color: Config.alpha(root.accentColor, 0.14)
                            radius: 10

                            IconImage {
                                anchors.centerIn: parent
                                height: 17
                                layer.enabled: true
                                source: Quickshell.iconPath(stepTile.modelData.icon)
                                width: 17

                                layer.effect: ColorOverlay {
                                    color: root.accentColor
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                text: stepTile.modelData.label
                            }
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface_variant
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 11
                                text: stepTile.modelData.value
                            }
                        }
                    }
                }
            }
        }
    }
}
