import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root

    readonly property int columnCount: 1
    property real maximumContentWidth: 0
    default property alias pageData: content.data
    property real pageSpacing: 12

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
    contentHeight: viewport.height
    contentWidth: availableWidth

    Item {
        id: viewport

        height: content.implicitHeight + 10
        width: root.availableWidth

        GridLayout {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            columnSpacing: root.pageSpacing
            columns: root.columnCount
            rowSpacing: root.pageSpacing
            uniformCellWidths: true
            width: root.maximumContentWidth > 0 ? Math.min(parent.width, root.maximumContentWidth) : parent.width
        }
    }
}
