import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../service"

PanelWindow {
    id: root

    property bool mapped: false

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-idle-dim"
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    visible: mapped

    mask: Region {
    }

    Connections {
        function onActiveChanged() {
            if (IdleDimService.active) {
                unmapTimer.stop();
                root.mapped = true;
            } else if (root.mapped) {
                unmapTimer.restart();
            }
        }

        target: IdleDimService
    }
    Timer {
        id: unmapTimer

        interval: 220

        onTriggered: {
            if (!IdleDimService.active)
                root.mapped = false;
        }
    }
    IdleDimShade {
        anchors.fill: parent
    }
}
