import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    readonly property string iconSource: {
        if (provider === "microsoft")
            return "file://" + Config.quickshellDir + "/assets/icons/calendar-microsoft.svg";
        if (provider === "icloud" || provider === "caldav")
            return "file://" + Config.quickshellDir + "/assets/icons/calendar-icloud.svg";
        return Quickshell.iconPath("goa-account-google-symbolic", "x-office-calendar-symbolic");
    }
    property string provider: "google"
    property color tint: Config.md3.primary

    implicitHeight: 22
    implicitWidth: 22

    IconImage {
        anchors.centerIn: parent
        height: parent.height
        layer.enabled: true
        source: root.iconSource
        width: parent.width

        layer.effect: ColorOverlay {
            color: root.tint
        }
    }
}
