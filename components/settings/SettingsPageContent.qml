import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root

    property real maximumContentWidth: 0
    default property alias pageData: content.data
    property real pageSpacing: 14

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
    contentHeight: viewport.height
    contentWidth: availableWidth

    Item {
        id: viewport

        height: content.implicitHeight + 10
        width: root.availableWidth

        ColumnLayout {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.pageSpacing
            width: root.maximumContentWidth > 0 ? Math.min(parent.width, root.maximumContentWidth) : parent.width
        }
    }
}
