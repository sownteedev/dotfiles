import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Widgets
import "../../"

Rectangle {
    id: root

    property string accessibleName: ""
    property bool animationsReady: false
    property color backgroundColor: Config.md3.surface_container_high
    property real fontPixelSize: Md3.typography.labelLarge
    property int iconSize: 20
    property real minimumSegmentWidth: 64
    property var options: []
    property string selectedValue: ""
    property color selectionColor: Config.md3.primary
    property color selectionContentColor: Config.md3.on_primary
    property int selectionDirection: 1
    property int selectionMotionRevision: 0
    property bool showOptionIcons: false

    signal selected(string value)

    function chooseValue(nextValue) {
        if (!enabled)
            return;

        var next = String(nextValue || "");
        if (next === "")
            return;

        var previousIndex = root.selectedIndex();
        var nextIndex = -1;
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === next) {
                nextIndex = i;
                break;
            }
        }
        var selectionChanged = previousIndex >= 0 && nextIndex >= 0 && previousIndex !== nextIndex;
        if (selectionChanged)
            root.selectionDirection = nextIndex > previousIndex ? 1 : -1;

        root.animationsReady = true;
        root.selected(next);
        if (selectionChanged)
            root.selectionMotionRevision += 1;
    }
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
                chooseValue(options[next].value);
                return;
            }
        }
    }
    function revealSelection() {
        if (segmentView.contentWidth <= segmentView.width)
            return;
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
    function selectionExpansionDirection() {
        var activeIndex = root.selectedIndex();
        var compressedIndex = root.selectionPushIndex();
        if (activeIndex < 0 || compressedIndex < 0)
            return root.selectionDirection >= 0 ? 1 : -1;
        return compressedIndex > activeIndex ? 1 : -1;
    }
    function selectionPushIndex() {
        var activeIndex = root.selectedIndex();
        if (activeIndex < 0 || options.length < 2)
            return -1;

        var pushed = activeIndex + (root.selectionDirection >= 0 ? 1 : -1);
        if (pushed < 0 || pushed >= options.length)
            pushed = activeIndex - (root.selectionDirection >= 0 ? 1 : -1);
        return pushed >= 0 && pushed < options.length ? pushed : -1;
    }
    function syncSelectionIndicator() {
        var index = root.selectedIndex();
        selectionIndicator.selectedButton = index >= 0 ? segmentView.itemAtIndex(index) : null;
    }

    Accessible.name: accessibleName
    Accessible.role: Accessible.Grouping
    activeFocusOnTab: false
    color: "transparent"
    implicitHeight: 48
    radius: Md3.shape.full

    Component.onCompleted: {
        root.revealSelection();
        Qt.callLater(function () {
            root.syncSelectionIndicator();
        });
    }
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
        root.syncSelectionIndicator();
    })
    onSelectedValueChanged: {
        root.revealSelection();
        root.syncSelectionIndicator();
    }
    onVisibleChanged: {
        if (!visible) {
            animationsReady = false;
            selectionIndicator.selectedButton = null;
        } else {
            Qt.callLater(function () {
                root.syncSelectionIndicator();
            });
        }
    }

    ListView {
        id: segmentView

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        currentIndex: root.selectedIndex()
        flickableDirection: Flickable.HorizontalFlick
        interactive: contentWidth > width
        leftMargin: 0
        model: root.options
        orientation: ListView.Horizontal
        rightMargin: 0
        spacing: 4

        delegate: Item {
            id: segment

            readonly property bool active: root.selectedValue === String(modelData.value)
            readonly property bool available: root.enabled && modelData.enabled !== false
            readonly property real equalWidth: (segmentView.width - segmentView.leftMargin - segmentView.rightMargin - Math.max(0, segmentView.count - 1) * segmentView.spacing) / Math.max(1, segmentView.count)
            readonly property bool highlightedByIndicator: active && selectionIndicator.ready && selectionIndicator.selectedButton === segment
            readonly property bool hovered: segmentArea.containsMouse
            readonly property string iconSource: modelData && modelData.iconSource ? String(modelData.iconSource) : ""
            required property int index
            required property var modelData
            readonly property bool pressed: segmentArea.pressed
            property real selectionCompression: 0
            readonly property bool selectionCompressionTarget: root.selectionPushIndex() === index

            Accessible.checked: active
            Accessible.name: String(segment.modelData.label)
            Accessible.role: Accessible.RadioButton
            activeFocusOnTab: false
            height: segmentView.height
            opacity: available ? 1.0 : 0.38
            width: Math.max(root.minimumSegmentWidth, equalWidth)
            z: segment.active ? 1 : 0

            transform: Scale {
                origin.x: segment.index < root.selectedIndex() ? 0 : segment.width
                origin.y: segment.height / 2
                xScale: 1 - segment.selectionCompression
                yScale: 1
            }

            Accessible.onPressAction: {
                if (segment.available)
                    root.chooseValue(segment.modelData.value);
            }
            Keys.onReturnPressed: event => {
                if (segment.available)
                    root.chooseValue(segment.modelData.value);
                event.accepted = true;
            }
            Keys.onSpacePressed: event => {
                if (segment.available)
                    root.chooseValue(segment.modelData.value);
                event.accepted = true;
            }

            Connections {
                function onSelectionMotionRevisionChanged() {
                    if (!root.animationsReady)
                        return;

                    if (segment.selectionCompressionTarget)
                        selectionCompressionAnimation.restart();
                    else {
                        selectionCompressionAnimation.stop();
                        segment.selectionCompression = 0;
                    }
                }

                target: root
            }
            SequentialAnimation {
                id: selectionCompressionAnimation

                PropertyAction {
                    property: "selectionCompression"
                    target: segment
                    value: 0
                }
                Md3NumberAnimation {
                    property: "selectionCompression"
                    role: "microSpatial"
                    target: segment
                    to: segment.width > 0 ? Math.min(0.12, 14 / segment.width) : 0
                }
                Md3NumberAnimation {
                    property: "selectionCompression"
                    role: "microSpatial"
                    target: segment
                    to: 0
                }
            }
            Rectangle {
                id: segmentBackground

                anchors.fill: parent
                bottomLeftRadius: topLeftRadius
                bottomRightRadius: topRightRadius
                color: segment.active ? (segment.highlightedByIndicator ? "transparent" : root.selectionColor) : root.backgroundColor
                topLeftRadius: segment.active || segment.index === 0 ? height / 2 : 4
                topRightRadius: segment.active || segment.index === segmentView.count - 1 ? height / 2 : 4

                Behavior on color {
                    enabled: root.animationsReady

                    Md3ColorAnimation {
                        role: "state"
                    }
                }
                Behavior on topLeftRadius {
                    enabled: root.animationsReady

                    Md3NumberAnimation {
                        role: "microSpatial"
                    }
                }
                Behavior on topRightRadius {
                    enabled: root.animationsReady

                    Md3NumberAnimation {
                        role: "microSpatial"
                    }
                }

                // Expand toward the neighbouring segment without crossing the
                // clipped outer edges or changing the pill's height.
                transform: Scale {
                    origin.x: segment.index === 0 ? 0 : segment.index === segmentView.count - 1 ? segmentBackground.width : segmentBackground.width / 2
                    origin.y: segmentBackground.height / 2
                    xScale: segment.active && segmentView.count > 1 ? 1.02 : 1

                    Behavior on xScale {
                        enabled: root.animationsReady

                        Md3NumberAnimation {
                            role: "microSpatial"
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    bottomLeftRadius: parent.bottomLeftRadius
                    bottomRightRadius: parent.bottomRightRadius
                    color: Config.alpha(segment.active ? root.selectionContentColor : Config.md3.on_surface, segmentArea.pressed ? Md3.state.pressed : segmentArea.containsMouse ? Md3.state.hover : 0)
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    visible: !segment.highlightedByIndicator
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: segment.iconSource !== "" && root.showOptionIcons ? 8 : 0

                IconImage {
                    height: root.iconSize
                    layer.enabled: visible
                    source: segment.iconSource
                    visible: root.showOptionIcons && segment.iconSource !== "" && !segment.highlightedByIndicator
                    width: root.iconSize

                    layer.effect: ColorOverlay {
                        color: segment.active ? root.selectionContentColor : Config.md3.on_surface_variant
                    }
                }
                Text {
                    color: segment.active ? root.selectionContentColor : Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                    font.pixelSize: root.fontPixelSize
                    font.weight: segment.active ? Font.DemiBold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                    text: segment.modelData.label
                    visible: !segment.highlightedByIndicator

                    Behavior on color {
                        enabled: root.animationsReady

                        Md3ColorAnimation {
                            role: "state"
                        }
                    }
                }
            }
            MouseArea {
                id: segmentArea

                anchors.fill: parent
                cursorShape: segment.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: segment.available
                hoverEnabled: true

                onClicked: {
                    root.chooseValue(segment.modelData.value);
                }
            }
        }

        onCountChanged: Qt.callLater(function () {
            root.syncSelectionIndicator();
        })
    }
    Item {
        id: selectionIndicator

        readonly property bool ready: selectedButton !== null && width > 0 && height > 0
        property Item selectedButton: null
        property real selectionExpansion: 0

        enabled: false
        height: selectedButton ? selectedButton.height : 0
        visible: ready
        width: selectedButton ? selectedButton.width : 0
        x: selectedButton ? segmentView.x + selectedButton.x - segmentView.contentX : 0
        y: selectedButton ? segmentView.y + selectedButton.y - segmentView.contentY : 0
        z: 3

        Behavior on height {
            enabled: root.animationsReady && selectionIndicator.ready

            Md3NumberAnimation {
                role: "spatial"
            }
        }
        Behavior on width {
            enabled: root.animationsReady && selectionIndicator.ready

            Md3NumberAnimation {
                role: "spatial"
            }
        }
        Behavior on x {
            enabled: root.animationsReady && selectionIndicator.ready

            Md3NumberAnimation {
                role: "spatial"
            }
        }
        Behavior on y {
            enabled: root.animationsReady && selectionIndicator.ready

            Md3NumberAnimation {
                role: "spatial"
            }
        }

        Rectangle {
            id: selectionSurface

            anchors.fill: parent
            color: root.selectionColor
            radius: Md3.shape.full

            Behavior on color {
                enabled: root.animationsReady

                Md3ColorAnimation {
                    role: "state"
                }
            }
            transform: Scale {
                origin.x: root.selectionExpansionDirection() > 0 ? 0 : selectionSurface.width
                origin.y: selectionSurface.height / 2
                xScale: 1 + selectionIndicator.selectionExpansion
                yScale: 1
            }

            Rectangle {
                anchors.fill: parent
                color: root.selectionContentColor
                opacity: selectionIndicator.selectedButton ? selectionIndicator.selectedButton.pressed ? Md3.state.pressed : selectionIndicator.selectedButton.hovered ? Md3.state.hover : 0 : 0
                radius: Md3.shape.full
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: selectionIndicator.selectedButton && selectionIndicator.selectedButton.iconSource !== "" && root.showOptionIcons ? 8 : 0

            IconImage {
                height: root.iconSize
                layer.enabled: visible
                source: selectionIndicator.selectedButton ? selectionIndicator.selectedButton.iconSource : ""
                visible: root.showOptionIcons && selectionIndicator.selectedButton && selectionIndicator.selectedButton.iconSource !== ""
                width: root.iconSize

                layer.effect: ColorOverlay {
                    color: root.selectionContentColor
                }
            }
            Text {
                color: root.selectionContentColor
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                font.pixelSize: root.fontPixelSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 1
                text: selectionIndicator.selectedButton ? selectionIndicator.selectedButton.modelData.label : ""
            }
        }
        SequentialAnimation {
            id: selectionStretchAnimation

            PropertyAction {
                property: "selectionExpansion"
                target: selectionIndicator
                value: 0
            }
            Md3NumberAnimation {
                property: "selectionExpansion"
                role: "microSpatial"
                target: selectionIndicator
                to: selectionIndicator.selectedButton ? Math.min(0.12, 14 / selectionIndicator.selectedButton.width) : 0
            }
            Md3NumberAnimation {
                property: "selectionExpansion"
                role: "microSpatial"
                target: selectionIndicator
                to: 0
            }
        }
        Connections {
            function onSelectionMotionRevisionChanged() {
                if (!root.animationsReady || !selectionIndicator.selectedButton)
                    return;

                selectionStretchAnimation.restart();
            }

            target: root
        }
    }
}
