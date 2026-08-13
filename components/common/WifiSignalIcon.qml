import QtQuick
import "../../"

Item {
    id: root

    property color color: Config.md3.on_surface
    property bool connected: true
    property bool connectivityIssue: false
    property int signalStrength: 100
    readonly property string glyph: {
        if (!connected)
            return "󰤭"; // wifi-strength-off
        if (connectivityIssue)
            return "󰤩"; // wifi-strength-4-alert
        if (signalStrength > 80)
            return "󰤨"; // wifi-strength-4
        if (signalStrength > 60)
            return "󰤥"; // wifi-strength-3
        if (signalStrength > 40)
            return "󰤢"; // wifi-strength-2
        return "󰤟"; // wifi-strength-1
    }

    implicitHeight: 24
    implicitWidth: 24

    Text {
        anchors.centerIn: parent
        color: root.color
        font.family: "Material Design Icons Desktop"
        font.pixelSize: Math.max(1, Math.min(root.width, root.height) * 0.92)
        renderType: Text.NativeRendering
        text: root.glyph

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }
    }
}
