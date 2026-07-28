import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: edgeTrigger

    required property int edgeSide

    signal triggered

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: edgeSide === Qt.LeftEdge ? "edge-left" : "edge-right"
    anchors.bottom: true
    anchors.left: edgeSide === Qt.LeftEdge
    anchors.right: edgeSide === Qt.RightEdge
    anchors.top: true
    color: "transparent"
    exclusiveZone: 0
    implicitWidth: 2

    MouseArea {
        property int startX: 0
        property bool tracking: false

        anchors.fill: parent

        onCanceled: {
            tracking = false;
        }
        onPositionChanged: mouse => {
            if (!tracking)
                return;

            var diff = edgeSide === Qt.LeftEdge ? mouse.x - startX : startX - mouse.x;
            if (diff > 30) {
                tracking = false;
                edgeTrigger.triggered();
            }
        }
        onPressed: mouse => {
            startX = mouse.x;
            tracking = true;
        }
        onReleased: {
            tracking = false;
        }
    }
}
