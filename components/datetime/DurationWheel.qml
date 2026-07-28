import QtQuick
import "../../"

Item {
    id: root

    readonly property int _multiplier: 10000
    property int _realCount: maximumValue + 1
    property bool interactive: true
    property int maximumValue: 59
    readonly property int rowHeight: 40
    property string unitLabel: ""
    property int value: 0

    signal valueSelected(int value)

    function selectValue(nextValue) {
        var bounded = Math.max(0, Math.min(maximumValue, nextValue));
        var currentCenter = Math.floor(wheel.currentIndex / _realCount) * _realCount;
        var targetIndex = currentCenter + bounded;
        wheel.currentIndex = targetIndex;
        wheel.positionViewAtIndex(targetIndex, ListView.Center);
        valueSelected(bounded);
    }

    implicitHeight: 126
    implicitWidth: 142
    opacity: interactive ? 1 : 0.48

    Behavior on opacity {
        NumberAnimation {
            duration: 140
        }
    }

    onValueChanged: {
        if (!wheel.moving && (wheel.currentIndex % _realCount) !== value) {
            var currentCenter = Math.floor(wheel.currentIndex / _realCount) * _realCount;
            var targetIndex = currentCenter + value;
            wheel.currentIndex = targetIndex;
            wheel.positionViewAtIndex(targetIndex, ListView.Center);
        }
    }

    ListView {
        id: wheel

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: root.rowHeight * 4
        clip: true
        highlightMoveDuration: 120
        highlightRangeMode: ListView.StrictlyEnforceRange
        interactive: root.interactive
        model: root._realCount * root._multiplier
        preferredHighlightBegin: height / 2 - root.rowHeight / 2
        preferredHighlightEnd: height / 2 + root.rowHeight / 2
        snapMode: ListView.SnapToItem

        delegate: Item {
            id: delegateItem

            readonly property int distance: Math.abs(index - wheel.currentIndex)
            required property int index
            readonly property int realIndex: index % root._realCount
            readonly property bool selected: index === wheel.currentIndex

            height: root.rowHeight
            width: wheel.width

            Item {
                anchors.fill: parent

                Text {
                    id: numberText

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.features: {
                        "tnum": 1
                    }
                    font.pixelSize: delegateItem.selected ? 24 : 17
                    font.weight: delegateItem.selected ? Font.Bold : Font.Medium
                    opacity: delegateItem.selected ? 1 : (delegateItem.distance === 1 ? 0.28 : 0.075)
                    renderType: Text.NativeRendering
                    text: delegateItem.realIndex

                    Behavior on font.pixelSize {
                        NumberAnimation {
                            duration: 110
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 110
                        }
                    }
                }
                Text {
                    anchors.baseline: numberText.baseline
                    anchors.left: numberText.right
                    anchors.leftMargin: 6
                    color: Config.alpha(Config.md3.on_surface, 0.58)
                    font.family: Config.fontName
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    opacity: delegateItem.selected ? 1 : 0
                    renderType: Text.NativeRendering
                    text: root.unitLabel

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 110
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.interactive

                onClicked: root.selectValue(delegateItem.realIndex)
            }
        }

        Component.onCompleted: {
            var startCenter = Math.floor(root._multiplier / 2) * root._realCount;
            wheel.currentIndex = startCenter + root.value;
            wheel.positionViewAtIndex(wheel.currentIndex, ListView.Center);
        }
        onMovementEnded: {
            if (currentIndex >= 0)
                root.valueSelected(currentIndex % root._realCount);
        }
    }
    MouseArea {
        acceptedButtons: Qt.NoButton
        anchors.fill: parent
        enabled: root.interactive

        onWheel: wheelEvent => {
            var direction = wheelEvent.angleDelta.y > 0 ? -1 : 1;
            var targetIndex = wheel.currentIndex + direction;
            wheel.currentIndex = targetIndex;
            wheel.positionViewAtIndex(targetIndex, ListView.Center);
            root.valueSelected(targetIndex % root._realCount);
            wheelEvent.accepted = true;
        }
    }
}
