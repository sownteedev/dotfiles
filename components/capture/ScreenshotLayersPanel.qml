import "../../"
import ".."
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    readonly property real addImageButtonWidth: 48
    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    property string draggedLayerId: ""
    property bool dragging: false
    property bool imageInsertEnabled: true
    readonly property real layerCardSpacing: 6
    readonly property real layerCardWidth: 168
    readonly property real layerStride: layerCardWidth + layerCardSpacing
    required property var layers
    property string selectedLayerId: ""

    signal imageInsertRequested
    signal layerOrderRequested(var layerIds)
    signal layerRemoveRequested(string layerId)
    signal layerSelected(string layerId)
    signal layerVisibilityRequested(string layerId, bool visible)

    function beginLayerDrag(layerId, sourceIndex, proxyX) {
        draggedLayerId = String(layerId || "");
        dragSourceIndex = Number(sourceIndex);
        dragTargetIndex = dragSourceIndex;
        dragging = draggedLayerId !== "" && dragSourceIndex >= 0;
        updateLayerDrag(proxyX);
    }
    function commitLayerOrder() {
        var layerIds = [];
        for (var i = 0; i < layerModel.count; ++i)
            layerIds.push(String(layerModel.get(i).layerId));
        layerOrderRequested(layerIds);
    }
    function displacementFor(index, layerId) {
        if (!dragging || String(layerId) === draggedLayerId || dragSourceIndex === dragTargetIndex)
            return 0;
        if (dragSourceIndex < dragTargetIndex && index > dragSourceIndex && index <= dragTargetIndex)
            return -layerStride;
        if (dragSourceIndex > dragTargetIndex && index >= dragTargetIndex && index < dragSourceIndex)
            return layerStride;
        return 0;
    }
    function finishLayerDrag(proxy) {
        if (!dragging)
            return;

        var sourceIndex = dragSourceIndex;
        var targetIndex = dragTargetIndex;
        dragging = false;
        draggedLayerId = "";
        dragSourceIndex = -1;
        dragTargetIndex = -1;
        if (proxy) {
            proxy.x = 0;
            proxy.y = 0;
        }
        if (sourceIndex >= 0 && targetIndex >= 0 && sourceIndex !== targetIndex)
            layerModel.move(sourceIndex, targetIndex, 1);
        commitLayerOrder();
    }
    function indexForLayer(layerId) {
        var id = String(layerId || "");
        for (var i = 0; i < layerModel.count; ++i) {
            if (String(layerModel.get(i).layerId) === id)
                return i;
        }
        return -1;
    }
    function moveLayer(layerId, targetIndex) {
        var sourceIndex = indexForLayer(layerId);
        var target = Math.max(0, Math.min(Number(targetIndex), layerModel.count - 1));
        if (sourceIndex < 0 || sourceIndex === target)
            return;
        layerModel.move(sourceIndex, target, 1);
    }
    function moveLayerByKeyboard(layerId, offset) {
        var sourceIndex = indexForLayer(layerId);
        if (sourceIndex < 0)
            return;
        moveLayer(layerId, sourceIndex + offset);
        commitLayerOrder();
        layerSelected(layerId);
    }
    function syncLayers() {
        if (dragging)
            return;

        for (var modelIndex = layerModel.count - 1; modelIndex >= 0; --modelIndex) {
            var existingId = String(layerModel.get(modelIndex).layerId);
            var stillExists = false;
            for (var sourceIndex = 0; sourceIndex < layers.length; ++sourceIndex) {
                if (String(layers[sourceIndex].layerId || "") === existingId) {
                    stillExists = true;
                    break;
                }
            }
            if (!stillExists)
                layerModel.remove(modelIndex);
        }

        for (var i = 0; i < layers.length; ++i) {
            var layer = layers[i];
            var layerId = String(layer.layerId || "");
            var layerName = String(layer.layerName || qsTr("Image"));
            var baseLayer = Boolean(layer.isBase);
            var layerVisible = !Boolean(layer.hidden);
            var currentIndex = indexForLayer(layerId);

            if (currentIndex < 0) {
                layerModel.insert(i, {
                    "layerId": layerId,
                    "layerName": layerName,
                    "baseLayer": baseLayer,
                    "layerVisible": layerVisible
                });
            } else if (currentIndex !== i) {
                layerModel.move(currentIndex, i, 1);
            }

            var currentLayer = layerModel.get(i);
            if (String(currentLayer.layerName) !== layerName)
                layerModel.setProperty(i, "layerName", layerName);
            if (Boolean(currentLayer.baseLayer) !== baseLayer)
                layerModel.setProperty(i, "baseLayer", baseLayer);
            if (Boolean(currentLayer.layerVisible) !== layerVisible)
                layerModel.setProperty(i, "layerVisible", layerVisible);
        }

        while (layerModel.count > layers.length)
            layerModel.remove(layerModel.count - 1);
    }
    function updateLayerDrag(proxyX) {
        if (!dragging || dragSourceIndex < 0 || layerModel.count < 1)
            return;
        var absoluteCenter = dragSourceIndex * layerStride + Number(proxyX);
        dragTargetIndex = Math.max(0, Math.min(Math.round(absoluteCenter / layerStride), layerModel.count - 1));
    }

    Accessible.name: qsTr("Image layers, ordered from bottom to top")
    Accessible.role: Accessible.Grouping
    border.color: Config.alpha(Config.md3.outline_variant, 0.42)
    border.width: 1
    color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.96 : 0.94)
    implicitHeight: 64
    implicitWidth: Math.min(730, 16 + addImageButtonWidth + layerCardSpacing + layers.length * layerCardWidth + Math.max(0, layers.length - 1) * layerCardSpacing)
    radius: 18

    Component.onCompleted: syncLayers()
    onLayersChanged: Qt.callLater(function () {
        root.syncLayers();
    })

    ListModel {
        id: layerModel

        dynamicRoles: true
    }
    ListView {
        id: layerList

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: addImageButton.left
        anchors.rightMargin: root.layerCardSpacing
        anchors.top: parent.top
        anchors.topMargin: 8
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        flickableDirection: Flickable.HorizontalFlick
        interactive: !root.dragging && contentWidth > width
        model: layerModel
        orientation: ListView.Horizontal
        spacing: root.layerCardSpacing

        delegate: Item {
            id: layerSlot

            required property bool baseLayer
            property bool draggedDuringPress: false
            required property int index
            required property string layerId
            required property string layerName
            required property bool layerVisible
            readonly property bool selected: root.selectedLayerId === layerId

            Accessible.name: qsTr("Layer %1: %2").arg(index + 1).arg(layerName)
            Accessible.role: Accessible.ListItem
            activeFocusOnTab: true
            height: layerList.height
            width: root.layerCardWidth
            z: root.dragging && layerSlot.layerId === root.draggedLayerId ? 100 : 0

            Accessible.onPressAction: root.layerSelected(layerSlot.layerId)
            Keys.onDeletePressed: event => {
                if (!layerSlot.baseLayer)
                    root.layerRemoveRequested(layerSlot.layerId);
                event.accepted = true;
            }
            Keys.onEnterPressed: root.layerSelected(layerSlot.layerId)
            Keys.onLeftPressed: event => {
                root.moveLayerByKeyboard(layerSlot.layerId, -1);
                event.accepted = true;
            }
            Keys.onReturnPressed: root.layerSelected(layerSlot.layerId)
            Keys.onRightPressed: event => {
                root.moveLayerByKeyboard(layerSlot.layerId, 1);
                event.accepted = true;
            }
            Keys.onSpacePressed: event => {
                root.layerSelected(layerSlot.layerId);
                event.accepted = true;
            }

            Item {
                id: dragProxy

                height: layerSlot.height
                opacity: 0
                width: layerSlot.width

                onXChanged: {
                    if (layerPointer.drag.active)
                        root.updateLayerDrag(x);
                }
            }
            Rectangle {
                id: layerVisual

                border.color: layerSlot.selected || layerSlot.activeFocus ? Config.alpha(Config.md3.primary, 0.72) : Config.alpha(Config.md3.outline_variant, 0.26)
                border.width: 1
                color: layerSlot.selected ? Config.md3.primary_container : layerPointer.containsMouse ? Config.md3.surface_container_highest : Config.md3.surface_container
                height: parent.height
                radius: 12
                scale: layerPointer.drag.active ? 1 : layerPointer.pressed ? 0.97 : 1
                width: parent.width
                x: root.dragging && layerSlot.layerId === root.draggedLayerId ? dragProxy.x : root.displacementFor(layerSlot.index, layerSlot.layerId)

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(100)
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animationDuration(100)
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on x {
                    enabled: root.dragging && layerSlot.layerId !== root.draggedLayerId

                    NumberAnimation {
                        duration: Config.animationDuration(120)
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 34
                    anchors.right: parent.right
                    anchors.rightMargin: layerSlot.baseLayer ? 7 : 31
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        color: layerSlot.selected ? Config.md3.primary : Config.md3.surface_container_highest
                        height: 30
                        radius: 9
                        width: 30

                        Text {
                            anchors.centerIn: parent
                            color: layerSlot.selected ? Config.md3.on_primary : Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            text: layerSlot.index + 1
                        }
                    }
                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 16
                        layer.enabled: true
                        source: Quickshell.iconPath(layerSlot.baseLayer ? "camera-photo-symbolic" : "image-x-generic-symbolic")
                        width: 16

                        layer.effect: ColorOverlay {
                            color: !layerSlot.layerVisible ? Config.md3.outline : layerSlot.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: !layerSlot.layerVisible ? Config.md3.outline : layerSlot.selected ? Config.md3.on_primary_container : Config.md3.on_surface
                        elide: Text.ElideMiddle
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: layerSlot.selected ? Font.DemiBold : Font.Medium
                        text: layerSlot.layerName
                        width: Math.max(30, layerVisual.width - 108 - (layerSlot.baseLayer ? 0 : 22))
                    }
                }
            }
            MouseArea {
                id: layerPointer

                acceptedButtons: Qt.LeftButton
                anchors.fill: parent
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.axis: Drag.XAxis
                drag.maximumX: (layerModel.count - layerSlot.index - 1) * root.layerStride
                drag.minimumX: -layerSlot.index * root.layerStride
                drag.smoothed: false
                drag.target: dragProxy
                hoverEnabled: true
                preventStealing: true

                drag.onActiveChanged: {
                    if (drag.active) {
                        layerSlot.draggedDuringPress = true;
                        root.beginLayerDrag(layerSlot.layerId, layerSlot.index, dragProxy.x);
                    }
                }
                onCanceled: {
                    if (layerSlot.draggedDuringPress)
                        root.finishLayerDrag(dragProxy);
                    layerSlot.draggedDuringPress = false;
                }
                onClicked: {
                    if (!layerSlot.draggedDuringPress)
                        root.layerSelected(layerSlot.layerId);
                }
                onPressed: {
                    layerSlot.draggedDuringPress = false;
                    root.layerSelected(layerSlot.layerId);
                }
                onReleased: {
                    if (layerSlot.draggedDuringPress)
                        root.finishLayerDrag(dragProxy);
                    layerSlot.draggedDuringPress = false;
                }
            }
            Rectangle {
                id: visibilityButton

                Accessible.name: layerSlot.layerVisible ? qsTr("Hide layer") : qsTr("Show layer")
                Accessible.role: Accessible.Button
                activeFocusOnTab: true
                anchors.left: layerVisual.left
                anchors.leftMargin: 5
                anchors.verticalCenter: layerVisual.verticalCenter
                border.color: activeFocus ? Config.md3.primary : "transparent"
                border.width: 1
                color: visibilityPointer.pressed ? Config.alpha(Config.md3.primary, 0.2) : visibilityPointer.containsMouse ? Config.alpha(Config.md3.primary, 0.12) : "transparent"
                height: 24
                radius: 8
                width: 24
                z: 3

                Accessible.onPressAction: root.layerVisibilityRequested(layerSlot.layerId, !layerSlot.layerVisible)
                Keys.onEnterPressed: root.layerVisibilityRequested(layerSlot.layerId, !layerSlot.layerVisible)
                Keys.onReturnPressed: root.layerVisibilityRequested(layerSlot.layerId, !layerSlot.layerVisible)
                Keys.onSpacePressed: event => {
                    root.layerVisibilityRequested(layerSlot.layerId, !layerSlot.layerVisible);
                    event.accepted = true;
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath(layerSlot.layerVisible ? "view-visible-symbolic" : "view-conceal-symbolic")
                    width: 16

                    layer.effect: ColorOverlay {
                        color: layerSlot.selected ? Config.md3.on_primary_container : layerSlot.layerVisible ? Config.md3.on_surface_variant : Config.md3.outline
                    }
                }
                MouseArea {
                    id: visibilityPointer

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.layerVisibilityRequested(layerSlot.layerId, !layerSlot.layerVisible)
                }
            }
            Rectangle {
                id: removeButton

                Accessible.name: qsTr("Remove layer")
                Accessible.role: Accessible.Button
                anchors.right: layerVisual.right
                anchors.rightMargin: 5
                anchors.verticalCenter: layerVisual.verticalCenter
                color: removePointer.pressed ? Config.alpha(Config.md3.error, 0.24) : removePointer.containsMouse ? Config.alpha(Config.md3.error, 0.15) : "transparent"
                height: 22
                radius: 7
                visible: !layerSlot.baseLayer
                width: 22
                z: 3

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    text: "×"
                }
                MouseArea {
                    id: removePointer

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.layerRemoveRequested(layerSlot.layerId)
                }
            }
        }
    }
    Rectangle {
        id: addImageButton

        Accessible.description: qsTr("Insert another image as a movable layer.")
        Accessible.name: qsTr("Add image layer")
        Accessible.role: Accessible.Button
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        border.color: addImagePointer.containsMouse ? Config.alpha(Config.md3.primary, 0.42) : Config.alpha(Config.md3.outline_variant, 0.3)
        border.width: 1
        color: addImagePointer.pressed ? Config.md3.primary_container : addImagePointer.containsMouse ? Config.md3.surface_container_highest : Config.md3.surface_container
        enabled: root.imageInsertEnabled
        height: layerList.height
        opacity: enabled ? 1 : 0.48
        radius: 12
        scale: addImagePointer.pressed ? 0.94 : 1
        width: root.addImageButtonWidth

        Behavior on border.color {
            ColorAnimation {
                duration: Config.animationDuration(100)
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Config.animationDuration(100)
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(100)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(100)
                easing.type: Easing.OutCubic
            }
        }

        Accessible.onPressAction: {
            if (addImageButton.enabled)
                root.imageInsertRequested();
        }

        Item {
            anchors.centerIn: parent
            height: 26
            width: 26

            IconImage {
                anchors.centerIn: parent
                height: 21
                layer.enabled: true
                source: Quickshell.iconPath("insert-image-symbolic", "image-x-generic-symbolic")
                width: 21

                layer.effect: ColorOverlay {
                    color: Config.md3.on_surface_variant
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                color: Config.md3.primary
                height: 14
                radius: 7
                width: 14

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.on_primary
                    font.family: Config.fontName
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    text: "+"
                }
            }
        }
        MouseArea {
            id: addImagePointer

            anchors.fill: parent
            cursorShape: addImageButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: addImageButton.enabled
            hoverEnabled: true

            onClicked: root.imageInsertRequested()
        }
        ScreenshotToolTip {
            description: qsTr("Insert another image as a movable layer.")
            title: qsTr("Add image layer")
            visible: addImagePointer.containsMouse && addImagePointer.enabled
            x: (addImageButton.width - width) / 2
            y: -height - 9
        }
    }
}
