import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: edgeTrigger

    property real commitDistance: 30
    required property int edgeSide
    property real revealDistance: 640

    signal dragFinished(bool shouldOpen)
    signal dragMoved(real progress)
    signal dragStarted

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
        property real distance: 0
        property bool tracking: false

        anchors.fill: parent

        onCanceled: {
            if (tracking)
                edgeTrigger.dragFinished(false);
            tracking = false;
            distance = 0;
        }
        onPositionChanged: mouse => {
            if (!tracking)
                return;

            var diff = edgeSide === Qt.LeftEdge ? mouse.x - startX : startX - mouse.x;
            distance = Math.max(0, diff);
            edgeTrigger.dragMoved(Math.min(1, distance / Math.max(1, edgeTrigger.revealDistance)));
        }
        onPressed: mouse => {
            startX = mouse.x;
            distance = 0;
            tracking = true;
            edgeTrigger.dragStarted();
        }
        onReleased: {
            if (tracking)
                edgeTrigger.dragFinished(distance >= edgeTrigger.commitDistance);
            tracking = false;
            distance = 0;
        }
    }
}
