import QtQuick

ShaderEffect {
    id: root

    required property real progress
    property vector2d resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
    property var source

    signal failed

    fragmentShader: Qt.resolvedUrl("./greeter-exit.frag.qsb")

    onStatusChanged: {
        if (status === ShaderEffect.Error) {
            console.warn("[Greeter] Exit blur unavailable:", log);
            root.failed();
        }
    }
}
