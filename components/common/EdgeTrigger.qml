import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: edgeTrigger

    required property int edgeSide
    signal triggered

    WlrLayershell.namespace: edgeSide === Qt.LeftEdge ? "edge-left" : "edge-right"
    WlrLayershell.layer: WlrLayer.Top

    color: "transparent"
    exclusiveZone: 0

    anchors.top: true
    anchors.bottom: true
    anchors.left: edgeSide === Qt.LeftEdge
    anchors.right: edgeSide === Qt.RightEdge

    implicitWidth: 2

    MouseArea {
        anchors.fill: parent

        property int startX: 0
        property bool tracking: false

        onPressed: (mouse) => {
            startX = mouse.x;
            tracking = true;
        }

        onPositionChanged: (mouse) => {
            if (!tracking)
                return ;

            var diff = edgeSide === Qt.LeftEdge ? mouse.x - startX : startX - mouse.x;
            if (diff > 30) {
                tracking = false;
                edgeTrigger.triggered();
            }
        }

        onReleased: {
            tracking = false;
        }
        onCanceled: {
            tracking = false;
        }
    }
}
