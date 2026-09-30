pragma ComponentBehavior: Bound
import ".."
import "../.."
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Popup {
    id: root

    property var defaults: ({})
    property var draftValues: ({})
    readonly property real maximumHeight: Math.max(0, parent ? parent.height - 28 : 570)
    readonly property real maximumListHeight: Math.max(0, maximumHeight - 138)
    readonly property real maximumWidth: Math.max(0, parent ? parent.width - 28 : 440)
    property var placementAnchor: null
    readonly property real preferredWidth: Math.max(300, Math.min(350, Math.max(titleMetrics.advanceWidth, subtitleMetrics.advanceWidth) + 136))
    property var propertyItems: []
    property var wallpaper: null
    readonly property string wallpaperSubtitle: wallpaper ? String(wallpaper.title || wallpaper.id || "") : ""

    function applyChanges() {
        var overrides = {};
        for (var index = 0; index < propertyItems.length; ++index) {
            var item = propertyItems[index];
            var value = valueFor(item);
            if (JSON.stringify(value) !== JSON.stringify(item.defaultValue))
                overrides[item.name] = value;
        }
        EngineWallpaperService.savePropertyValues(wallpaper.path, overrides);
        close();
    }
    function cleanLabel(value, name) {
        var label = String(value || "").replace(/<[^>]*>/g, " ").replace(/[\[\]]/g, "").trim();
        if (label === "" || label.startsWith("ui_"))
            label = name === "schemecolor" ? qsTr("Scheme color") : String(name).replace(/[_-]+/g, " ");
        return label;
    }
    function normalizeProperties(rawProperties) {
        var source = rawProperties && typeof rawProperties === "object" ? rawProperties : ({});
        var names = Object.keys(source);
        var normalized = [];
        var nextDefaults = {};
        for (var index = 0; index < names.length; ++index) {
            var name = names[index];
            if (!/^[A-Za-z0-9_.-]{1,128}$/.test(name))
                continue;
            if (String(name).toLowerCase() === "schemecolor")
                continue;
            var item = source[name] || {};
            var type = String(item.type || "text").toLowerCase();
            var options = [];
            if (Array.isArray(item.options)) {
                for (var optionIndex = 0; optionIndex < item.options.length; ++optionIndex) {
                    var option = item.options[optionIndex] || {};
                    options.push({
                        "label": String(option.label === undefined ? option.value : option.label),
                        "value": option.value
                    });
                }
            }
            nextDefaults[name] = item.value;
            normalized.push({
                "defaultValue": item.value,
                "label": cleanLabel(item.text, name),
                "maximum": item.max === undefined ? 1 : item.max,
                "minimum": item.min === undefined ? 0 : item.min,
                "name": name,
                "options": options,
                "order": Number(item.order === undefined ? 1000 : item.order),
                "step": item.step === undefined ? 0.01 : item.step,
                "type": type
            });
        }
        normalized.sort((left, right) => left.order === right.order ? left.label.localeCompare(right.label) : left.order - right.order);
        defaults = nextDefaults;
        return normalized;
    }
    function openFor(item, anchorItem) {
        if (!item || !anchorItem || !parent)
            return;
        placementAnchor = anchorItem;
        reposition();
        wallpaper = item;
        propertyItems = normalizeProperties(item.properties);
        var stored = EngineWallpaperService.propertyValues(item.path);
        draftValues = Object.assign({}, defaults, stored);
        if (!opened)
            open();
        reposition();
    }
    function reposition() {
        if (!placementAnchor || !parent)
            return;
        var point = placementAnchor.mapToItem(parent, 0, 0);
        x = Math.max(14, Math.min(point.x + placementAnchor.width - width, parent.width - width - 14));
        y = Math.max(14, Math.min(point.y + placementAnchor.height + 10, parent.height - height - 14));
    }
    function setDraftValue(name, value) {
        var next = Object.assign({}, draftValues);
        next[name] = value;
        draftValues = next;
    }
    function valueFor(item) {
        return draftValues[item.name] === undefined ? item.defaultValue : draftValues[item.name];
    }

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: false
    focus: true
    height: Math.min(maximumHeight, contentColumn.implicitHeight)
    implicitHeight: contentColumn.implicitHeight
    modal: true
    padding: 0
    popupType: Popup.Item
    width: Math.min(maximumWidth, preferredWidth)
    z: 1000

    background: Item {
        ShellShadow {
            cornerRadius: popupSurface.radius
            target: popupSurface
        }
        Rectangle {
            id: popupSurface

            anchors.fill: parent
            border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.46 : 0.32)
            border.width: 1
            color: Config.md3.surface_container_high
            radius: 20
        }
    }
    contentItem: ColumnLayout {
        id: contentColumn

        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.preferredHeight: 72
            Layout.rightMargin: 14
            spacing: 12

            Rectangle {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                color: Config.md3.primary_container
                radius: 13

                IconImage {
                    anchors.centerIn: parent
                    height: 20
                    layer.enabled: true
                    source: Quickshell.iconPath("preferences-system-symbolic")
                    width: 20

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_primary_container
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    text: titleMetrics.text
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.wallpaperSubtitle
                }
            }
            Rectangle {
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                color: closeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                radius: 12

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath("window-close-symbolic")
                    width: 16

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface_variant
                    }
                }
                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.close()
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.alpha(Config.md3.outline_variant, 0.45)
        }
        ListView {
            id: propertyList

            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.preferredHeight: Math.min(contentHeight, root.maximumListHeight)
            Layout.rightMargin: 20
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: root.propertyItems
            spacing: 6

            ScrollBar.vertical: SlimScrollBar {
            }
            delegate: Rectangle {
                id: propertyCard

                required property var modelData

                color: Config.alpha(Config.md3.surface_container, 0.72)
                height: propertyRow.implicitHeight + 16
                radius: 14
                width: ListView.view.width

                WallpaperScenePropertyRow {
                    id: propertyRow

                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    propertyData: propertyCard.modelData
                    value: root.valueFor(propertyCard.modelData)

                    onValueEdited: value => root.setDraftValue(propertyCard.modelData.name, value)
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.alpha(Config.md3.outline_variant, 0.28)
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.preferredHeight: 64
            Layout.rightMargin: 16
            spacing: 8

            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 84
                color: resetMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.12) : (resetMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : Config.alpha(Config.md3.on_surface, 0.055))
                radius: 12

                Behavior on color {
                    Md3ColorAnimation {
                        role: "state"
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    text: qsTr("Reset")
                }
                MouseArea {
                    id: resetMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.draftValues = Object.assign({}, root.defaults)
                }
            }
            Rectangle {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 92
                color: applyMouse.pressed ? Config.md3.primary_container : (applyMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.86) : Config.md3.primary)
                radius: 12

                Behavior on color {
                    Md3ColorAnimation {
                        role: "state"
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: applyMouse.pressed ? Config.md3.on_primary_container : Config.md3.on_primary
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    text: qsTr("Apply")
                }
                MouseArea {
                    id: applyMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.applyChanges()
                }
            }
        }
    }

    onHeightChanged: {
        if (visible)
            reposition();
    }
    onWidthChanged: {
        if (visible)
            reposition();
    }

    TextMetrics {
        id: titleMetrics

        font.family: Config.fontName
        font.pixelSize: 17
        font.weight: Font.Bold
        text: qsTr("Scene properties")
    }
    TextMetrics {
        id: subtitleMetrics

        font.family: Config.fontName
        font.pixelSize: 12
        text: root.wallpaperSubtitle
    }
}
