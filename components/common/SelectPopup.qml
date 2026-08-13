import QtQuick
import Qt5Compat.GraphicalEffects
import "../../"

Item {
    id: root

    property color accentColor: Config.md3.primary
    property var itemActive: function (item) {
        return false;
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
        Qt.callLater(function () {
            if (!root.opened || popupItems.count === 0)
                return;

            const values = root.model || [];
            let activeIndex = -1;
            for (let i = 0; i < values.length; ++i) {
                if (root.itemVisible(values[i]) && root.itemActive(values[i])) {
                    activeIndex = i;
                    break;
                }
            }

            if (activeIndex >= 0)
                popupItems.positionViewAtIndex(activeIndex, ListView.Center);
            else
                popupItems.positionViewAtBeginning();
        });
    }

    opacity: opened ? 1 : 0
    visible: opened || opacity > 0

    onModelChanged: {
        if (opened)
            positionCurrentItem();
    }
    onOpenedChanged: {
        if (opened)
            positionCurrentItem();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    MouseArea {
        anchors.fill: parent

        onPressed: root.dismissed()
    }
    Item {
        anchors.fill: parent

        transform: Scale {
            origin.x: popupCard.x + popupCard.width - 32
            origin.y: root.openAbove ? popupCard.y + popupCard.height : popupCard.y
            xScale: root.opened ? 1 : 0.85
            yScale: root.opened ? 1 : 0.85

            Behavior on xScale {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutBack
                }
            }
            Behavior on yScale {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutBack
                }
            }
        }

        Rectangle {
            id: popupCard

            readonly property real desiredHeight: root.visibleItemCount * root.rowHeight + 16

            border.color: Config.alpha(Config.md3.on_surface, 0.08)
            border.width: 1
            color: Config.md3.surface_container
            height: Responsive.fit(desiredHeight, root.maxPopupHeight, root.rowHeight + 16)
            layer.enabled: root.opened
            radius: 12
            width: Responsive.fit(root.popupWidth, root.width - root.rightMargin - 12, 180)
            x: Math.max(0, root.width - width - root.rightMargin)
            y: Math.max(12, Math.min(root.popupY, root.height - height - 12))

            layer.effect: DropShadow {
                color: Config.alpha(Config.black, 0.4)
                radius: 10
                samples: 15
                transparentBorder: true
                verticalOffset: 4
            }

            ListView {
                id: popupItems

                anchors.fill: parent
                anchors.margins: 8
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                model: root.model

                delegate: Rectangle {
                    id: row

                    readonly property bool included: root.itemVisible(modelData)
                    required property var modelData
                    readonly property bool selected: root.itemActive(modelData)

                    color: rowMouse.containsMouse ? Config.md3.surface_container_high : "transparent"
                    height: included ? root.rowHeight : 0
                    radius: 8
                    visible: included
                    width: ListView.view.width

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: checkmark.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.selected ? root.accentColor : Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: row.selected ? Font.Bold : Font.Medium
                        text: root.itemLabel(row.modelData)
                    }
                    Text {
                        id: checkmark

                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.accentColor
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        text: "✓"
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
        Rectangle {
            id: caret

            border.color: Config.alpha(Config.md3.on_surface, 0.08)
            border.width: 1
            color: Config.md3.surface_container
            height: 12
            rotation: 45
            width: 12
            x: popupCard.x + popupCard.width - 32 - width / 2
            y: root.openAbove ? popupCard.y + popupCard.height - height / 2 : popupCard.y - height / 2
        }
        Rectangle {
            color: Config.md3.surface_container
            height: 10
            width: 20
            x: caret.x - 4
            y: root.openAbove ? popupCard.y + popupCard.height - height : popupCard.y
        }
    }
}
