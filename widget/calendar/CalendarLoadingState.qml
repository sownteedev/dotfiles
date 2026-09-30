import "../../"
import "../../components"
import QtQuick

Item {
    id: root

    LoadingIndicator {
        Accessible.name: qsTr("Loading calendars")
        Accessible.role: Accessible.Indicator
        anchors.centerIn: parent
        animated: root.visible && Config.animationDuration(1) > 0
        color: Config.md3.primary
        height: width
        width: Math.min(88, Math.max(0, root.width - 32), Math.max(0, root.height - 32))
    }
}
