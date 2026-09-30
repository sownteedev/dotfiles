import QtQuick
import "../../"

// Shared controller for page enter/exit animations.
QtObject {
    id: root

    property int duration: Md3.motion.medium1
    property ParallelAnimation enterAnimation: ParallelAnimation {
        Md3NumberAnimation {
            duration: Config.animationDuration(root.duration)
            property: "opacity"
            role: "enter"
            target: root.targetItem
            to: 1
        }
        Md3NumberAnimation {
            duration: Config.animationDuration(root.duration)
            property: "scale"
            role: "enter"
            target: root.targetItem
            to: 1
        }
    }
    property bool panelActive: false
    required property Item targetItem
    property Connections visibilityConnection: Connections {
        function onVisibleChanged() {
            root.sync();
        }

        target: root.targetItem
    }

    function sync() {
        if (panelActive && targetItem.visible) {
            enterAnimation.restart();
        } else {
            enterAnimation.stop();
            targetItem.opacity = 0;
            targetItem.scale = 0.96;
        }
    }

    Component.onCompleted: sync()
    onPanelActiveChanged: sync()
}
