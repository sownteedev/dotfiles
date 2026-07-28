import QtQuick

// Shared controller for page enter/exit animations.
QtObject {
    id: root

    property int duration: 250
    property ParallelAnimation enterAnimation: ParallelAnimation {
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.OutQuad
            property: "opacity"
            target: root.targetItem
            to: 1
        }
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.OutQuad
            property: "scale"
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
