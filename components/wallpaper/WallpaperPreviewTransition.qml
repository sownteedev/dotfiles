import QtQuick

Item {
    id: root

    required property bool active
    property int duration: 360
    required property int effectIndex
    required property Item incomingItem
    property bool initialized: false
    required property Item outgoingItem

    signal failed
    signal finished

    function reportFailure() {
        if (active)
            failed();
    }
    function syncActive() {
        animation.stop();
        if (!active)
            return;
        effect.progress = 0;
        if (effect.status === ShaderEffect.Error) {
            Qt.callLater(reportFailure);
            return;
        }
        outgoingSource.scheduleUpdate();
        incomingSource.scheduleUpdate();
        animation.start();
    }

    visible: active

    Component.onCompleted: {
        initialized = true;
        syncActive();
    }
    onActiveChanged: {
        if (initialized)
            syncActive();
    }

    ShaderEffectSource {
        id: outgoingSource

        hideSource: true
        live: false
        sourceItem: root.active ? root.outgoingItem : null
    }
    ShaderEffectSource {
        id: incomingSource

        hideSource: true
        live: false
        sourceItem: root.active ? root.incomingItem : null
    }
    ShaderEffect {
        id: effect

        property var incomingTexture: incomingSource
        property var outgoingTexture: outgoingSource
        property real progress: 0
        property vector2d resolution: Qt.vector2d(width, height)
        property int transitionStyle: root.effectIndex

        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("../../assets/shaders/wallpaper-preview.frag.qsb")

        onStatusChanged: {
            if (status === ShaderEffect.Error) {
                console.warn("[Wallpaper] Preview shader failed:", log);
                animation.stop();
                Qt.callLater(root.reportFailure);
            }
        }
    }
    UniformAnimator {
        id: animation

        duration: root.duration
        easing.type: Easing.InOutSine
        from: 0
        target: effect
        to: 1
        uniform: "progress"

        onFinished: root.finished()
    }
}
