pragma ComponentBehavior: Bound

import QtQuick
import "../../"

Item {
    id: root

    readonly property int _multiplier: 10000
    property int _realCount: maximumValue + 1
    property bool interactive: true
    property int maximumValue: 59
    property int rowHeight: 40
    property bool scrollingEnabled: true
    property string unitLabel: ""
    property int value: 0
    readonly property real visualScale: Math.max(0.82, Math.min(1, rowHeight / 40))

    signal valueSelected(int value)

    function selectValue(nextValue) {
        var bounded = Math.max(0, Math.min(maximumValue, nextValue));
        var currentCenter = Math.floor(wheel.currentIndex / _realCount) * _realCount;
        var targetIndex = currentCenter + bounded;
        wheel.currentIndex = targetIndex;
        wheel.positionViewAtIndex(targetIndex, ListView.Center);
        valueSelected(bounded);
    }

    implicitHeight: rowHeight * 3
    implicitWidth: 132
    opacity: interactive ? 1 : 0.42

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
        interactive: root.interactive && root.scrollingEnabled
        model: root._realCount * root._multiplier
        preferredHighlightBegin: height / 2 - root.rowHeight / 2
        preferredHighlightEnd: height / 2 + root.rowHeight / 2
        reuseItems: true
        snapMode: ListView.SnapToItem

        delegate: Item {
            id: delegateItem

            readonly property int distance: Math.abs(index - wheel.currentIndex)
            required property int index
            readonly property int realIndex: index % root._realCount
            readonly property bool selected: index === wheel.currentIndex

            height: root.rowHeight
            width: wheel.width

            opacity: selected ? 1 : distance === 1 ? 0.26 : 0.06
            scale: selected ? 1 : 0.88

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: numberText

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: delegateItem.selected ? -4 : 0
                color: delegateItem.selected ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.72)
                font.family: Config.fontName
                font.features: {
                    "tnum": 1
                }
                font.pixelSize: delegateItem.selected ? Math.max(20, Math.round(23 * root.visualScale)) : Math.max(13, Math.round(15 * root.visualScale))
                font.weight: delegateItem.selected ? Font.ExtraBold : Font.Medium
                renderType: Text.NativeRendering
                text: String(delegateItem.realIndex).padStart(2, "0")

                Behavior on anchors.verticalCenterOffset {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on font.pixelSize {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: numberText.bottom
                anchors.topMargin: -3
                color: Config.alpha(Config.md3.on_surface, 0.5)
                font.capitalization: Font.AllUppercase
                font.family: Config.fontName
                font.letterSpacing: 0.7
                font.pixelSize: Math.max(8, Math.round(9 * root.visualScale))
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
        enabled: root.interactive && root.scrollingEnabled

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
