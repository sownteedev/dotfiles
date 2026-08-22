import QtQuick
import "../../"

Rectangle {
    id: root

    property string accessibleName: ""
    property color backgroundColor: Config.md3.surface_container
    property real minimumSegmentWidth: 112
    property var options: []
    property string selectedValue: ""

    signal selected(string value)

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
    border.color: Config.alpha(Config.md3.outline, 0.16)
    border.width: 1
    color: root.backgroundColor
    implicitHeight: 40
    radius: 12

    Component.onCompleted: Qt.callLater(function () {
        root.revealSelection();
    })
    Keys.onLeftPressed: event => {
        moveSelection(-1);
        event.accepted = true;
    }
    Keys.onRightPressed: event => {
        moveSelection(1);
        event.accepted = true;
    }
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
        leftMargin: 3
        model: root.options
        orientation: ListView.Horizontal
        rightMargin: 3
        spacing: 3

        delegate: Item {
            id: segment

            readonly property bool active: root.selectedValue === modelData.value
            readonly property bool available: root.enabled && modelData.enabled !== false
            readonly property real equalWidth: (segmentView.width - segmentView.leftMargin - segmentView.rightMargin - Math.max(0, segmentView.count - 1) * segmentView.spacing) / Math.max(1, segmentView.count)
            required property var modelData

            Accessible.checked: active
            Accessible.name: String(segment.modelData.label)
            Accessible.role: Accessible.RadioButton
            height: segmentView.height
            opacity: available ? 1.0 : 0.38
            width: Math.max(root.minimumSegmentWidth, equalWidth)

            Accessible.onPressAction: {
                if (segment.available)
                    root.selected(segment.modelData.value);
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 3
                color: segment.active ? Config.md3.primary_container : (segmentArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : "transparent")
                radius: 9

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                color: segment.active ? Config.md3.on_primary_container : Config.md3.on_surface_variant
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
        }
    }
}
