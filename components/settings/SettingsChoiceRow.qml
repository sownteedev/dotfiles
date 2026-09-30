import "../../"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property bool animationsReady: false
    property string label: ""
    property string note: ""
    property var options: []
    property int selectionDirection: 1
    property int selectionMotionRevision: 0
    property string value: ""

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

        root.value = next;
        if (selectionChanged)
            root.selectionMotionRevision += 1;
        root.selected(next);
    }
    function greatestCommonDivisor(first, second) {
        var a = Math.abs(Number(first) || 0);
        var b = Math.abs(Number(second) || 0);
        while (b > 0) {
            var remainder = a % b;
            a = b;
            b = remainder;
        }
        return a || 1;
    }
    function layoutColumnsFor(optionColumns) {
        var result = 1;
        for (var i = 2; i <= optionColumns; ++i)
            result = leastCommonMultiple(result, i);
        return result;
    }
    function leastCommonMultiple(first, second) {
        var a = Math.max(1, Math.floor(Number(first) || 1));
        var b = Math.max(1, Math.floor(Number(second) || 1));
        return Math.floor(a / greatestCommonDivisor(a, b)) * b;
    }
    function moveSelection(offset) {
        if (!enabled || options.length === 0)
            return;
        var current = 0;
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === value) {
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
    function optionColumnsFor(width) {
        if (options.length === 0)
            return 1;
        if (options.length <= 3)
            return options.length;
        return Responsive.columnsFor(width, 148, options.length, 1, Md3.spacing.xs);
    }
    function selectedIndex() {
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === value)
                return i;
        }
        return -1;
    }
    function selectionExpansionDirection() {
        var activeIndex = selectedIndex();
        var compressedIndex = selectionPushIndex();
        if (activeIndex < 0 || compressedIndex < 0)
            return selectionDirection >= 0 ? 1 : -1;
        return compressedIndex > activeIndex ? 1 : -1;
    }
    function selectionPushIndex() {
        var activeIndex = selectedIndex();
        if (activeIndex < 0 || options.length < 2)
            return -1;

        var direction = selectionDirection >= 0 ? 1 : -1;
        var pushed = activeIndex + direction;
        if (pushed < 0 || pushed >= options.length)
            pushed = activeIndex - direction;
        return pushed >= 0 && pushed < options.length ? pushed : -1;
    }
    function syncSelectionIndicator() {
        var index = root.selectedIndex();
        selectionIndicator.selectedButton = index >= 0 ? optionRepeater.itemAt(index) : null;
    }

    Accessible.description: note
    Accessible.name: label
    Accessible.role: Accessible.Grouping
    Layout.minimumWidth: 0
    Layout.preferredWidth: 1
    activeFocusOnTab: false
    implicitWidth: 0
    spacing: Md3.spacing.xs

    Component.onCompleted: Qt.callLater(function () {
        root.syncSelectionIndicator();
        root.animationsReady = true;
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
        root.syncSelectionIndicator();
    })
    onValueChanged: syncSelectionIndicator()

    SettingsLabelBlock {
        Layout.fillWidth: true
        headline: root.label
        supportingText: root.note
    }
    Item {
        id: choiceFrame

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: optionGrid.implicitHeight

        GridLayout {
            id: optionGrid

            readonly property int layoutColumnCount: root.layoutColumnsFor(optionColumns)
            readonly property int optionColumns: root.optionColumnsFor(width)
            readonly property real optionSpacing: Md3.spacing.xxs

            function columnSpanFor(index) {
                var rowCount = rowItemCount(index);
                return rowCount > 0 ? layoutColumnCount / rowCount : layoutColumnCount;
            }
            function rowItemCount(index) {
                var rowStart = Math.floor(index / optionColumns) * optionColumns;
                return Math.min(optionColumns, Math.max(0, root.options.length - rowStart));
            }

            anchors.fill: parent
            columnSpacing: optionSpacing
            columns: layoutColumnCount
            rowSpacing: Md3.spacing.xs
            uniformCellWidths: true
            z: 1

            Repeater {
                id: optionRepeater

                model: root.options

                delegate: Item {
                    id: optionButton

                    readonly property bool active: root.value === String(modelData.value)
                    readonly property bool available: root.enabled && modelData.enabled !== false
                    readonly property bool firstInRow: index % optionGrid.optionColumns === 0
                    readonly property bool highlightedByIndicator: active && selectionIndicator.ready && selectionIndicator.selectedButton === optionButton
                    readonly property bool hovered: optionMouse.containsMouse
                    required property int index
                    readonly property bool lastInRow: (index + 1) % optionGrid.optionColumns === 0 || index === root.options.length - 1
                    required property var modelData
                    readonly property bool pressed: optionMouse.pressed
                    property real selectionCompression: 0
                    readonly property bool selectionCompressionTarget: root.selectionPushIndex() === index

                    Accessible.checked: active
                    Accessible.name: String(optionButton.modelData.label)
                    Accessible.role: Accessible.RadioButton
                    Layout.columnSpan: optionGrid.columnSpanFor(index)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    activeFocusOnTab: false
                    implicitHeight: 48
                    opacity: available ? 1 : Md3.state.disabledContent

                    transform: Scale {
                        origin.x: optionButton.index < root.selectedIndex() ? 0 : optionButton.width
                        origin.y: optionButton.height / 2
                        xScale: 1 - optionButton.selectionCompression
                        yScale: 1
                    }

                    Accessible.onPressAction: {
                        if (optionButton.available)
                            root.chooseValue(optionButton.modelData.value);
                    }
                    Keys.onReturnPressed: event => {
                        if (!optionButton.available)
                            return;
                        root.chooseValue(optionButton.modelData.value);
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: event => {
                        if (!optionButton.available)
                            return;
                        root.chooseValue(optionButton.modelData.value);
                        event.accepted = true;
                    }

                    Connections {
                        function onSelectionMotionRevisionChanged() {
                            if (!root.animationsReady)
                                return;

                            if (optionButton.selectionCompressionTarget)
                                selectionCompressionAnimation.restart();
                            else {
                                selectionCompressionAnimation.stop();
                                optionButton.selectionCompression = 0;
                            }
                        }

                        target: root
                    }
                    SequentialAnimation {
                        id: selectionCompressionAnimation

                        PropertyAction {
                            property: "selectionCompression"
                            target: optionButton
                            value: 0
                        }
                        Md3NumberAnimation {
                            property: "selectionCompression"
                            role: "microSpatial"
                            target: optionButton
                            to: optionButton.width > 0 ? Math.min(0.12, 14 / optionButton.width) : 0
                        }
                        Md3NumberAnimation {
                            property: "selectionCompression"
                            role: "microSpatial"
                            target: optionButton
                            to: 0
                        }
                    }
                    Rectangle {
                        id: optionSurface

                        anchors.fill: parent
                        bottomLeftRadius: topLeftRadius
                        bottomRightRadius: topRightRadius
                        color: optionButton.active ? (optionButton.highlightedByIndicator ? "transparent" : Config.md3.primary) : Config.md3.surface_container_high
                        topLeftRadius: optionButton.active || optionButton.firstInRow ? height / 2 : Md3.shape.small
                        topRightRadius: optionButton.active || optionButton.lastInRow ? height / 2 : Md3.shape.small

                        Behavior on bottomLeftRadius {
                            enabled: root.animationsReady

                            Md3NumberAnimation {
                                role: "microSpatial"
                            }
                        }
                        Behavior on bottomRightRadius {
                            enabled: root.animationsReady

                            Md3NumberAnimation {
                                role: "microSpatial"
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
                    }
                    Rectangle {
                        id: optionStateLayer

                        anchors.fill: parent
                        bottomLeftRadius: topLeftRadius
                        bottomRightRadius: topRightRadius
                        color: optionButton.active ? Config.md3.on_primary : Config.md3.on_surface
                        opacity: optionMouse.pressed ? Md3.state.pressed : optionMouse.containsMouse ? Md3.state.hover : 0
                        topLeftRadius: optionButton.active || optionButton.firstInRow ? height / 2 : Md3.shape.small
                        topRightRadius: optionButton.active || optionButton.lastInRow ? height / 2 : Md3.shape.small
                        visible: !optionButton.highlightedByIndicator

                        Behavior on bottomLeftRadius {
                            enabled: root.animationsReady

                            Md3NumberAnimation {
                                role: "microSpatial"
                            }
                        }
                        Behavior on bottomRightRadius {
                            enabled: root.animationsReady

                            Md3NumberAnimation {
                                role: "microSpatial"
                            }
                        }
                        Behavior on opacity {
                            enabled: root.animationsReady

                            Md3NumberAnimation {
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
                    }
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        color: optionButton.active ? Config.md3.on_primary : Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                        font.pixelSize: Md3.typeScale.labelLarge.size
                        font.weight: optionButton.active ? Md3.typeScale.labelLarge.emphasizedWeight : Md3.typeScale.labelLarge.weight
                        horizontalAlignment: Text.AlignHCenter
                        text: optionButton.modelData.label
                        verticalAlignment: Text.AlignVCenter
                        visible: !optionButton.highlightedByIndicator

                        Behavior on color {
                            enabled: root.animationsReady

                            Md3ColorAnimation {
                                role: "state"
                            }
                        }
                    }
                    MouseArea {
                        id: optionMouse

                        anchors.fill: parent
                        cursorShape: optionButton.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: optionButton.available
                        hoverEnabled: true

                        onClicked: root.chooseValue(optionButton.modelData.value)
                    }
                }

                // itemAt() does not notify bindings when a delegate is created.
                onItemAdded: (index, item) => {
                    if (index === root.selectedIndex())
                        selectionIndicator.selectedButton = item;
                }
                onItemRemoved: (index, item) => {
                    if (selectionIndicator.selectedButton === item)
                        selectionIndicator.selectedButton = null;
                }
            }
        }
        Rectangle {
            id: selectionIndicator

            readonly property bool ready: selectedButton !== null && width > 0 && height > 0
            property Item selectedButton: null
            property real selectionExpansion: 0

            color: "transparent"
            enabled: false
            height: selectedButton ? selectedButton.height : 0
            visible: ready
            width: selectedButton ? selectedButton.width : 0
            x: selectedButton ? optionGrid.x + selectedButton.x : 0
            y: selectedButton ? optionGrid.y + selectedButton.y : 0
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
                color: Config.md3.primary
                radius: Md3.shape.full

                transform: Scale {
                    origin.x: root.selectionExpansionDirection() > 0 ? 0 : selectionSurface.width
                    origin.y: selectionSurface.height / 2
                    xScale: 1 + selectionIndicator.selectionExpansion
                    yScale: 1
                }

                Rectangle {
                    anchors.fill: parent
                    color: Config.md3.on_primary
                    opacity: selectionIndicator.selectedButton ? selectionIndicator.selectedButton.pressed ? Md3.state.pressed : selectionIndicator.selectedButton.hovered ? Md3.state.hover : 0 : 0
                    radius: Md3.shape.full
                }
            }
            Text {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                color: Config.md3.on_primary
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                font.pixelSize: Md3.typeScale.labelLarge.size
                font.weight: Md3.typeScale.labelLarge.emphasizedWeight
                horizontalAlignment: Text.AlignHCenter
                text: selectionIndicator.selectedButton ? selectionIndicator.selectedButton.modelData.label : ""
                verticalAlignment: Text.AlignVCenter
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
}
