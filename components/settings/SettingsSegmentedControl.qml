import QtQuick
import "../../"

Rectangle {
    id: root

    property var options: []
    property string selectedValue: ""
    property string accessibleName: ""
    property real minimumSegmentWidth: 112

    signal selected(string value)

    border.color: Config.alpha(Config.md3.outline, 0.24)
    border.width: 1
    color: Config.md3.surface_container_high
    implicitHeight: 44
    radius: 14

    function moveSelection(offset) {
        if (!enabled || options.length === 0)
            return;
        var current = 0;
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === selectedValue) {
                current = i;
                break;
            }
        }
        for (var step = 1; step <= options.length; ++step) {
            var next = (current + offset * step + options.length) % options.length;
            if (options[next].enabled !== false) {
                selected(String(options[next].value));
                return;
            }
        }
    }
    function revealSelection() {
        var index = selectedIndex();
        if (index >= 0)
            segmentView.positionViewAtIndex(index, ListView.Contain);
    }
    function selectedIndex() {
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === selectedValue)
                return i;
        }
        return -1;
    }

    Accessible.name: accessibleName
    Accessible.role: Accessible.Grouping
    activeFocusOnTab: enabled
    Keys.onLeftPressed: event => {
        moveSelection(-1);
        event.accepted = true;
    }
    Keys.onRightPressed: event => {
        moveSelection(1);
        event.accepted = true;
    }
    Component.onCompleted: Qt.callLater(function () {
        root.revealSelection();
    })
    onOptionsChanged: Qt.callLater(function () {
        root.revealSelection();
    })
    onSelectedValueChanged: Qt.callLater(function () {
        root.revealSelection();
    })

    ListView {
        id: segmentView

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        currentIndex: root.selectedIndex()
        flickableDirection: Flickable.HorizontalFlick
        interactive: contentWidth > width
        leftMargin: 4
        model: root.options
        orientation: ListView.Horizontal
        rightMargin: 4
        spacing: 4

        delegate: Rectangle {
            id: segment

            readonly property bool active: root.selectedValue === modelData.value
            readonly property bool available: root.enabled && modelData.enabled !== false
            readonly property real equalWidth: (segmentView.width - segmentView.leftMargin - segmentView.rightMargin - Math.max(0, segmentView.count - 1) * segmentView.spacing) / Math.max(1, segmentView.count)
            required property var modelData

            Accessible.checked: active
            Accessible.name: String(segment.modelData.label)
            Accessible.role: Accessible.RadioButton
            border.color: active ? Config.alpha(Config.md3.primary, 0.5) : "transparent"
            border.width: 1
            color: active ? Config.alpha(Config.md3.primary, 0.16) : (segmentArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : "transparent")
            height: segmentView.height - 8
            opacity: available ? 1.0 : 0.38
            radius: 10
            width: Math.max(root.minimumSegmentWidth, equalWidth)
            y: 4

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                color: segment.active ? Config.md3.primary : Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: segment.active ? Font.DemiBold : Font.Medium
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 1
                text: segment.modelData.label

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
            MouseArea {
                id: segmentArea

                anchors.fill: parent
                cursorShape: segment.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: segment.available
                hoverEnabled: true

                onClicked: root.selected(segment.modelData.value)
            }
            Accessible.onPressAction: {
                if (segment.available)
                    root.selected(segment.modelData.value);
            }
        }
    }
}
