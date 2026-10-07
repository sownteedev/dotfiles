import QtQuick
import "../../service"

Rectangle {
    id: root

    readonly property bool fadingIn: targetOpacity > renderedOpacity + 0.001
    property real renderedOpacity: 0
    readonly property real targetOpacity: IdleDimService.active ? IdleDimService.dimOpacity : 0

    color: "black"
    opacity: renderedOpacity

    Behavior on renderedOpacity {
        NumberAnimation {
            duration: root.fadingIn ? 700 : 160
            easing.type: root.fadingIn ? Easing.InOutCubic : Easing.OutCubic
        }
    }

    Component.onCompleted: renderedOpacity = targetOpacity

    Connections {
        function onActiveChanged() {
            root.renderedOpacity = root.targetOpacity;
        }
        function onDimOpacityChanged() {
            if (IdleDimService.active)
                root.renderedOpacity = root.targetOpacity;
        }

        target: IdleDimService
    }
}
