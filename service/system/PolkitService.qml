pragma Singleton
import Quickshell.Services.Polkit
import QtQuick

QtObject {
    id: root

    readonly property bool active: nativeAgent.isActive
    readonly property var flow: nativeAgent.flow
    property PolkitAgent nativeAgent: PolkitAgent {
        id: nativeAgent

        path: "/org/quickshell/PolkitAgent"

        onIsRegisteredChanged: {
            console.info("[PolkitService] Agent registered:", isRegistered);
        }
    }
    readonly property bool registered: nativeAgent.isRegistered
}
