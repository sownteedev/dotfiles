pragma Singleton
import ".."
import QtQuick

QtObject {
    readonly property WebAccountConnection steam: WebAccountConnection {
        provider: "steam"
    }
    readonly property WebAccountConnection wallhaven: WebAccountConnection {
        provider: "wallhaven"
    }
}
