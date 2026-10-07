import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sownteeshell-idle-dim"
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    // Keep the transparent layer mapped so the dim shade can animate from
    // zero opacity instead of appearing at its final value on first show.
    visible: true

    mask: Region {
    }

    IdleDimShade {
        anchors.fill: parent
    }
}
