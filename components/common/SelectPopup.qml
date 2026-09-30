import QtQuick
import ".."
import "../../"

Item {
    id: root

    property color accentColor: Config.md3.primary
    property real anchorWidth: 0
    property real anchorX: -1
    property var itemActive: function (item) {
        return false;
    }
    property var itemColor: function (item) {
        return item && item.color ? item.color : "";
    }
    property var itemLabel: function (item) {
        return item && item.label ? item.label : "";
    }
    property var itemVisible: function (item) {
        return true;
    }
    property real maxPopupHeight: Math.max(0, height - 24)
    property var model: []
    property bool openAbove: false
    property bool opened: false
    property real popupWidth: 260
    property real popupY: 0
    property real rightMargin: 12
    property real rowHeight: 46
    property real shadowOpacity: 1
    readonly property int visibleItemCount: {
        var count = 0;
        var values = model || [];
        for (var i = 0; i < values.length; ++i) {
            if (itemVisible(values[i]))
                ++count;
        }
        return count;
    }

    signal dismissed
    signal itemSelected(var item)

    function positionCurrentItem() {
        if (!root.opened || popupItems.count === 0)
            return;

        popupItems.forceLayout();
        const values = root.model || [];
        let activeIndex = -1;
        for (let i = 0; i < values.length; ++i) {
            if (root.itemVisible(values[i]) && root.itemActive(values[i])) {
                activeIndex = i;
                break;
            }
        }

        popupItems.currentIndex = activeIndex;
        if (activeIndex >= 0)
            popupItems.positionViewAtIndex(activeIndex, ListView.Center);
        else
            popupItems.positionViewAtBeginning();
    }

    opacity: opened ? 1 : 0
    visible: opened || opacity > 0

    Behavior on opacity {
        Md3OpacityAnimator {
            role: root.opened ? "enter" : "exit"
        }
    }

    onModelChanged: {
        if (opened)
            positionCurrentItem();
    }
    onOpenedChanged: {
        if (opened)
            positionCurrentItem();
    }

    MouseArea {
        anchors.fill: parent

        onPressed: root.dismissed()
    }
    Item {
        height: parent.height
        width: parent.width
        y: root.opened ? 0 : (root.openAbove ? Md3.spacing.xs : -Md3.spacing.xs)

        Behavior on y {
            Md3NumberAnimation {
                role: root.opened ? "enter" : "exit"
            }
        }

        ShellShadow {
            active: root.visible
            cornerRadius: popupCard.radius
            level: 2
            opacity: root.shadowOpacity
            target: popupCard
        }
        Rectangle {
            id: popupCard

            readonly property real desiredHeight: root.visibleItemCount * root.rowHeight + 16

            border.color: Config.alpha(Config.md3.outline_variant, 0.48)
            border.width: 1
            color: Config.md3.surface_container_high
            height: Responsive.fit(desiredHeight, root.maxPopupHeight, root.rowHeight + 16)
            radius: Md3.shape.large
            width: Responsive.fit(root.popupWidth, root.width - root.rightMargin - 12, 180)
            x: Math.max(0, root.width - width - root.rightMargin)
            y: Math.max(12, Math.min(root.popupY, root.height - height - 12))

            ListView {
                id: popupItems

                anchors.fill: parent
                anchors.margins: Md3.spacing.xs
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                model: root.model

                delegate: Rectangle {
                    id: row

                    readonly property string badgeColor: String(root.itemColor(modelData) || "")
                    readonly property bool hasColorBadge: badgeColor !== "" && badgeColor !== "transparent"
                    readonly property bool included: root.itemVisible(modelData)
                    required property var modelData
                    readonly property bool selected: root.itemActive(modelData)

                    Accessible.checked: selected
                    Accessible.name: root.itemLabel(modelData)
                    Accessible.role: Accessible.MenuItem
                    color: selected ? Config.md3.secondary_container : "transparent"
                    height: included ? root.rowHeight : 0
                    radius: Md3.shape.medium
                    visible: included
                    width: ListView.view.width

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: row.selected ? Config.md3.on_secondary_container : Config.md3.on_surface
                        opacity: rowMouse.pressed ? Md3.state.pressed : rowMouse.containsMouse ? Md3.state.hover : 0
                        radius: Math.max(0, row.radius - 1)

                        Behavior on opacity {
                            Md3NumberAnimation {
                                role: "state"
                            }
                        }
                    }
                    Rectangle {
                        id: colorDot

                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.badgeColor
                        height: 8
                        radius: 4
                        visible: row.hasColorBadge
                        width: 8
                    }
                    Text {
                        anchors.left: row.hasColorBadge ? colorDot.right : parent.left
                        anchors.leftMargin: row.hasColorBadge ? 8 : 12
                        anchors.right: checkmark.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.selected ? Config.md3.on_secondary_container : Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                        font.pixelSize: Md3.typeScale.labelLarge.size
                        font.weight: row.selected ? Font.DemiBold : Md3.typeScale.labelLarge.weight
                        text: root.itemLabel(row.modelData)
                    }
                    Md3Icon {
                        id: checkmark

                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.selected ? Config.md3.on_secondary_container : root.accentColor
                        filled: true
                        name: "checkmark-symbolic"
                        size: 18
                        visible: row.selected
                    }
                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.itemSelected(row.modelData)
                    }
                }
            }
        }
        // Keep the small pointer from the previous popup design.  When an
        // anchor is supplied, point it at the trigger instead of using a
        // hard-coded position near the popup's right edge.
        Rectangle {
            id: caret

            readonly property real centerX: root.anchorX >= 0 && root.anchorWidth > 0 ? root.anchorX + root.anchorWidth / 2 : popupCard.x + popupCard.width - 32

            color: Config.md3.surface_container_high
            height: 8
            rotation: 45
            width: 8
            x: Math.max(popupCard.x + 16, Math.min(popupCard.x + popupCard.width - 16, centerX)) - width / 2
            y: root.openAbove ? popupCard.y + popupCard.height - height / 2 : popupCard.y - height / 2
            z: 0
        }
        Rectangle {
            color: Config.md3.surface_container_high
            height: 8
            width: 16
            x: caret.x - 4
            y: root.openAbove ? popupCard.y + popupCard.height - height : popupCard.y
            z: 1
        }
    }
}
