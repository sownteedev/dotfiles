import "../.."
import "../../service"
import ".."
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    readonly property int activeFilterCount: (WallhavenService.categories === "111" ? 0 : 1) + (WallhavenService.purity === "111" ? 0 : 1) + (WallhavenService.atleast === "" && WallhavenService.resolutions === "" ? 0 : 1) + (WallhavenService.ratios === "" ? 0 : 1) + (WallhavenService.colors === "" ? 0 : 1) + (WallhavenService.sorting === "toplist" && WallhavenService.order === "desc" && WallhavenService.topRange === "1M" ? 0 : 1) + (Config.wallhavenShowNsfw ? 1 : 0)
    readonly property var colorOptions: ["660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399", "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300", "000000", "999999", "cccccc", "ffffff"]
    readonly property bool popupOpen: filterPopup.visible
    property Item popupParent: null
    readonly property var ratioOptions: ["16x9", "16x10", "21x9", "32x9", "9x16", "1x1", "3x2", "4x3"]
    readonly property var resolutionOptions: ["1280x720", "1920x1080", "1920x1200", "2560x1080", "2560x1440", "3440x1440", "3840x1600", "3840x2160"]
    readonly property var sortingOptions: [
        {
            "label": qsTr("Relevant"),
            "value": "relevance"
        },
        {
            "label": qsTr("Newest"),
            "value": "date_added"
        },
        {
            "label": qsTr("Random"),
            "value": "random"
        },
        {
            "label": qsTr("Views"),
            "value": "views"
        },
        {
            "label": qsTr("Favorites"),
            "value": "favorites"
        },
        {
            "label": qsTr("Toplist"),
            "value": "toplist"
        }
    ]
    readonly property var topRangeOptions: [
        {
            "label": qsTr("1d"),
            "value": "1d"
        },
        {
            "label": qsTr("3d"),
            "value": "3d"
        },
        {
            "label": qsTr("1w"),
            "value": "1w"
        },
        {
            "label": qsTr("1m"),
            "value": "1M"
        },
        {
            "label": qsTr("3m"),
            "value": "3M"
        },
        {
            "label": qsTr("6m"),
            "value": "6M"
        },
        {
            "label": qsTr("1y"),
            "value": "1y"
        }
    ]

    signal searchRequested

    function bitEnabled(bits, index) {
        return String(bits || "000").charAt(index) === "1";
    }
    function closePopup() {
        filterPopup.open = false;
    }
    function currentResolution() {
        return WallhavenService.resolutionMode === "exact" ? WallhavenService.resolutions : WallhavenService.atleast;
    }
    function filterChanged() {
        searchDebounce.restart();
    }
    function resetFilters() {
        WallhavenService.categories = "111";
        WallhavenService.purity = "111";
        WallhavenService.resolutionMode = "atleast";
        WallhavenService.atleast = "";
        WallhavenService.resolutions = "";
        WallhavenService.ratios = "";
        WallhavenService.colors = "";
        WallhavenService.sorting = "toplist";
        WallhavenService.order = "desc";
        WallhavenService.topRange = "1M";
        Config.wallhavenShowNsfw = false;
        filterChanged();
    }
    function setResolution(value) {
        if (value === "") {
            WallhavenService.atleast = "";
            WallhavenService.resolutions = "";
        } else if (WallhavenService.resolutionMode === "exact") {
            WallhavenService.resolutions = value;
            WallhavenService.atleast = "";
        } else {
            WallhavenService.atleast = value;
            WallhavenService.resolutions = "";
        }
        filterChanged();
    }
    function setResolutionMode(mode) {
        if (mode === "any") {
            setResolution("");
            return;
        }
        var value = currentResolution();
        WallhavenService.resolutionMode = mode;
        WallhavenService.atleast = mode === "atleast" ? value : "";
        WallhavenService.resolutions = mode === "exact" ? value : "";
        if (value !== "")
            filterChanged();
    }
    function toggleBit(propertyName, index) {
        var value = String(WallhavenService[propertyName] || "111");
        if (value.length !== 3)
            value = "111";
        if (propertyName === "purity" && index === 2 && Config.wallhavenApiKey.trim() === "")
            return;

        var replacement = value.charAt(index) === "1" ? "0" : "1";
        var next = value.substring(0, index) + replacement + value.substring(index + 1);
        if (next === "000")
            return;

        WallhavenService[propertyName] = next;
        filterChanged();
    }
    function togglePopup() {
        filterPopup.open = !filterPopup.open;
        filterButton.forceActiveFocus();
    }

    implicitHeight: 40
    implicitWidth: 40
    z: filterPopup.visible ? 240 : 0

    Timer {
        id: searchDebounce

        interval: 220
        repeat: false

        onTriggered: root.searchRequested()
    }
    Rectangle {
        id: filterButton

        Accessible.name: root.activeFilterCount > 0 ? qsTr("Wallhaven filters, %1 active").arg(root.activeFilterCount) : qsTr("Wallhaven filters")
        Accessible.role: Accessible.Button
        activeFocusOnTab: true
        anchors.fill: parent
        border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.72) : Config.alpha(Config.md3.outline, 0.14)
        border.width: 1
        color: filterPopup.open || root.activeFilterCount > 0 ? Config.md3.secondary_container : (filterMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.035))
        radius: 13

        Keys.onEscapePressed: root.closePopup()
        Keys.onReturnPressed: root.togglePopup()
        Keys.onSpacePressed: root.togglePopup()

        IconImage {
            anchors.centerIn: parent
            height: 17
            layer.enabled: true
            source: Quickshell.iconPath("view-filter-symbolic")
            width: 17

            layer.effect: ColorOverlay {
                color: filterPopup.open || root.activeFilterCount > 0 ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: -3
            anchors.top: parent.top
            anchors.topMargin: -3
            color: Config.md3.primary
            height: 18
            radius: 9
            visible: root.activeFilterCount > 0
            width: Math.max(18, filterCount.implicitWidth + 8)

            Text {
                id: filterCount

                anchors.centerIn: parent
                color: Config.md3.on_primary
                font.family: Config.fontName
                font.pixelSize: 10
                font.weight: Font.Bold
                text: root.activeFilterCount
            }
        }
        MouseArea {
            id: filterMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: root.togglePopup()
        }
    }
    Item {
        id: filterPopup

        property bool open: false
        readonly property point popupAnchor: {
            root.x;
            root.y;
            filterButton.x;
            filterButton.y;
            filterButton.width;
            filterButton.height;
            return filterButton.mapToItem(root.popupParent || root, filterButton.width / 2, filterButton.height + 8);
        }

        height: Math.min(620, Math.min(parent ? parent.height - popupAnchor.y - 16 : 620, dashboard.implicitHeight + 74))
        opacity: open ? 1 : 0
        parent: root.popupParent || root
        scale: open ? 1 : 0.975
        transformOrigin: Item.Top
        visible: open || opacity > 0
        width: Math.min(860, parent ? parent.width - 32 : 860)
        x: Math.max(16, Math.min(popupAnchor.x - width / 2, parent ? parent.width - width - 16 : popupAnchor.x - width / 2))
        y: popupAnchor.y
        z: 300

        Behavior on opacity {
            OpacityAnimator {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            ScaleAnimator {
                duration: 170
                easing.type: Easing.OutCubic
            }
        }

        ShellShadow {
            cornerRadius: popupSurface.radius
            target: popupSurface
        }
        Rectangle {
            id: popupSurface

            anchors.fill: parent
            border.color: Config.alpha(Config.md3.outline, 0.16)
            border.width: 1
            color: Config.md3.surface_container_high
            radius: 20
        }
        Item {
            id: popupHeader

            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 10
            height: 40

            Column {
                anchors.left: parent.left
                anchors.right: headerActions.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    text: qsTr("Refine Wallhaven")
                }
                Text {
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 11
                    text: root.activeFilterCount > 0 ? qsTr("%1 active filters").arg(root.activeFilterCount) : qsTr("Showing the default catalog")
                }
            }
            Row {
                id: headerActions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                HeaderButton {
                    accent: true
                    accessibleName: qsTr("Reset filters")
                    enabled: root.activeFilterCount > 0
                    iconName: "edit-clear-all-symbolic"

                    onClicked: root.resetFilters()
                }
                HeaderButton {
                    accessibleName: qsTr("Close filters")
                    glyph: "×"

                    onClicked: root.closePopup()
                }
            }
        }
        Flickable {
            id: filterFlickable

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.top: popupHeader.bottom
            anchors.topMargin: 10
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: dashboard.height
            contentWidth: width

            ScrollBar.vertical: SlimScrollBar {
            }

            Item {
                id: dashboard

                readonly property real columnWidth: (width - 12) / 2

                height: implicitHeight
                implicitHeight: Math.max(appearanceCard.y + appearanceCard.height, sortCard.y + sortCard.height)
                width: filterFlickable.width - 8

                FilterCard {
                    id: contentCard

                    height: implicitHeight
                    iconName: "image-x-generic-symbolic"
                    title: qsTr("Content")
                    width: dashboard.columnWidth
                    x: 0
                    y: 0

                    SectionLabel {
                        text: qsTr("Categories")
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        Repeater {
                            model: [qsTr("General"), qsTr("Anime"), qsTr("People")]

                            delegate: FilterChip {
                                required property int index
                                required property string modelData

                                label: modelData
                                selected: root.bitEnabled(WallhavenService.categories, index)

                                onClicked: root.toggleBit("categories", index)
                            }
                        }
                    }
                    SectionLabel {
                        text: qsTr("Purity")
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        Repeater {
                            model: [qsTr("SFW"), qsTr("Sketchy"), qsTr("NSFW")]

                            delegate: FilterChip {
                                readonly property bool available: index !== 2 || Config.wallhavenApiKey.trim() !== ""
                                required property int index
                                required property string modelData

                                accentColor: index === 2 ? Config.md3.error_container : Config.md3.tertiary_container
                                enabled: available
                                label: modelData
                                selected: available && root.bitEnabled(WallhavenService.purity, index)
                                selectedTextColor: index === 2 ? Config.md3.on_error_container : Config.md3.on_tertiary_container

                                onClicked: root.toggleBit("purity", index)
                            }
                        }
                        FilterChip {
                            accentColor: Config.md3.error_container
                            enabled: Config.wallhavenApiKey.trim() !== "" && root.bitEnabled(WallhavenService.purity, 2)
                            label: Config.wallhavenShowNsfw ? qsTr("NSFW visible") : qsTr("NSFW blurred")
                            selected: Config.wallhavenShowNsfw
                            selectedTextColor: Config.md3.on_error_container

                            onClicked: Config.wallhavenShowNsfw = !Config.wallhavenShowNsfw
                        }
                    }
                }
                FilterCard {
                    id: resolutionCard

                    height: implicitHeight
                    iconName: "video-display-symbolic"
                    title: qsTr("Resolution")
                    width: dashboard.columnWidth
                    x: dashboard.columnWidth + 12
                    y: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: [
                                {
                                    "label": qsTr("At least"),
                                    "value": "atleast"
                                },
                                {
                                    "label": qsTr("Exact"),
                                    "value": "exact"
                                },
                                {
                                    "label": qsTr("Any"),
                                    "value": "any"
                                }
                            ]

                            delegate: FilterChip {
                                required property var modelData

                                Layout.fillWidth: true
                                label: modelData.label
                                selected: modelData.value === "any" ? root.currentResolution() === "" : (root.currentResolution() !== "" && WallhavenService.resolutionMode === modelData.value)

                                onClicked: root.setResolutionMode(modelData.value)
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        Repeater {
                            model: root.resolutionOptions

                            delegate: FilterChip {
                                required property string modelData

                                label: modelData.replace("x", " × ")
                                selected: root.currentResolution() === modelData

                                onClicked: root.setResolution(selected ? "" : modelData)
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        CompactField {
                            id: customWidth

                            Layout.fillWidth: true
                            placeholderText: qsTr("Width")

                            validator: IntValidator {
                                bottom: 320
                                top: 16384
                            }
                        }
                        Text {
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 12
                            text: "×"
                        }
                        CompactField {
                            id: customHeight

                            Layout.fillWidth: true
                            placeholderText: qsTr("Height")

                            validator: IntValidator {
                                bottom: 240
                                top: 16384
                            }
                        }
                        IconButton {
                            accessibleName: qsTr("Apply custom resolution")
                            enabled: customWidth.acceptableInput && customHeight.acceptableInput
                            iconName: "checkmark-symbolic"

                            onClicked: root.setResolution(customWidth.text + "x" + customHeight.text)
                        }
                    }
                }
                FilterCard {
                    id: appearanceCard

                    height: implicitHeight
                    iconName: "applications-graphics-symbolic"
                    title: qsTr("Appearance")
                    width: dashboard.columnWidth
                    x: 0
                    y: contentCard.height + 12

                    SectionLabel {
                        text: qsTr("Aspect ratio")
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        FilterChip {
                            label: qsTr("Any")
                            selected: WallhavenService.ratios === ""

                            onClicked: {
                                WallhavenService.ratios = "";
                                root.filterChanged();
                            }
                        }
                        Repeater {
                            model: root.ratioOptions

                            delegate: FilterChip {
                                required property string modelData

                                label: modelData.replace("x", " : ")
                                selected: WallhavenService.ratios === modelData

                                onClicked: {
                                    WallhavenService.ratios = selected ? "" : modelData;
                                    root.filterChanged();
                                }
                            }
                        }
                    }
                    SectionLabel {
                        text: qsTr("Dominant color")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        FilterChip {
                            label: qsTr("Any")
                            selected: WallhavenService.colors === ""

                            onClicked: {
                                WallhavenService.colors = "";
                                root.filterChanged();
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            spacing: 5

                            Repeater {
                                model: root.colorOptions

                                delegate: ColorSwatch {
                                    required property string modelData

                                    colorValue: modelData
                                    selected: WallhavenService.colors.toLowerCase() === modelData

                                    onClicked: {
                                        WallhavenService.colors = selected ? "" : modelData;
                                        root.filterChanged();
                                    }
                                }
                            }
                        }
                    }
                }
                FilterCard {
                    id: sortCard

                    height: implicitHeight
                    iconName: "view-sort-descending-symbolic"
                    title: qsTr("Sort")
                    width: dashboard.columnWidth
                    x: dashboard.columnWidth + 12
                    y: resolutionCard.height + 12

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        Repeater {
                            model: root.sortingOptions

                            delegate: FilterChip {
                                required property var modelData

                                label: modelData.label
                                selected: WallhavenService.sorting === modelData.value

                                onClicked: {
                                    WallhavenService.sorting = modelData.value;
                                    root.filterChanged();
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        SectionLabel {
                            Layout.fillWidth: true
                            text: qsTr("Order")
                        }
                        FilterChip {
                            label: WallhavenService.order === "asc" ? qsTr("Ascending") : qsTr("Descending")
                            selected: true

                            onClicked: {
                                WallhavenService.order = WallhavenService.order === "asc" ? "desc" : "asc";
                                root.filterChanged();
                            }
                        }
                        IconButton {
                            accessibleName: qsTr("Open hot wallpapers")
                            iconName: "external-link-symbolic"

                            onClicked: {
                                root.closePopup();
                                WallhavenService.openPage("https://wallhaven.cc/hot");
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: WallhavenService.sorting === "toplist"

                        SectionLabel {
                            text: qsTr("Toplist period")
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: root.topRangeOptions

                                delegate: FilterChip {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    compact: true
                                    label: modelData.label
                                    selected: WallhavenService.topRange === modelData.value

                                    onClicked: {
                                        WallhavenService.topRange = modelData.value;
                                        root.filterChanged();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component ColorSwatch: Rectangle {
        id: swatch

        required property string colorValue
        property bool selected: false

        signal clicked

        Accessible.name: qsTr("Color %1").arg(colorValue)
        Accessible.role: Accessible.Button
        activeFocusOnTab: true
        border.color: selected || activeFocus ? Config.md3.primary : Config.alpha(Config.md3.outline, 0.28)
        border.width: selected ? 3 : 1
        color: "#" + colorValue
        height: 28
        radius: 9
        scale: swatchMouse.containsMouse ? 1.08 : 1
        width: 28

        Behavior on scale {
            ScaleAnimator {
                duration: 110
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: swatchMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: swatch.clicked()
        }
    }
    component CompactField: TextField {
        Layout.preferredHeight: 32
        color: Config.md3.on_surface
        font.family: Config.fontName
        font.pixelSize: 12
        horizontalAlignment: TextInput.AlignHCenter
        placeholderTextColor: Config.alpha(Config.md3.on_surface_variant, 0.7)
        selectByMouse: true

        background: Rectangle {
            border.color: parent.activeFocus ? Config.alpha(Config.md3.primary, 0.58) : Config.alpha(Config.md3.outline, 0.12)
            border.width: 1
            color: Config.alpha(Config.md3.on_surface, 0.035)
            radius: 10
        }
    }
    component FilterCard: Rectangle {
        id: card

        default property alias cardContent: cardBody.data
        required property string iconName
        required property string title

        border.color: Config.alpha(Config.md3.outline, 0.1)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container_low, 0.88)
        implicitHeight: cardBody.implicitHeight + 28
        radius: 16

        ColumnLayout {
            id: cardBody

            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                IconImage {
                    Layout.preferredHeight: 17
                    Layout.preferredWidth: 17
                    layer.enabled: true
                    source: Quickshell.iconPath(card.iconName, "preferences-other-symbolic")

                    layer.effect: ColorOverlay {
                        color: Config.md3.primary
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    text: card.title
                }
            }
        }
    }
    component FilterChip: Rectangle {
        id: chip

        property color accentColor: Config.md3.primary_container
        property bool compact: false
        property string label: ""
        property bool selected: false
        property color selectedTextColor: Config.md3.on_primary_container

        signal clicked

        Accessible.name: label
        Accessible.role: Accessible.Button
        activeFocusOnTab: true
        border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.74) : (selected ? Config.alpha(Config.md3.primary, 0.24) : Config.alpha(Config.md3.outline, 0.12))
        border.width: 1
        color: selected ? accentColor : (chipMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.025))
        implicitHeight: compact ? 29 : 32
        implicitWidth: compact ? Math.max(38, chipLabel.implicitWidth + 16) : chipLabel.implicitWidth + 24
        opacity: enabled ? 1 : 0.38
        radius: compact ? 9 : 11

        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()

        Text {
            id: chipLabel

            anchors.centerIn: parent
            color: chip.selected ? chip.selectedTextColor : Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: chip.compact ? 10 : 11
            font.weight: chip.selected ? Font.DemiBold : Font.Medium
            text: chip.label
        }
        MouseArea {
            id: chipMouse

            anchors.fill: parent
            cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: chip.enabled
            hoverEnabled: true

            onClicked: chip.clicked()
        }
    }
    component HeaderButton: Rectangle {
        id: headerButton

        property bool accent: false
        required property string accessibleName
        property string glyph: ""
        property string iconName: ""

        signal clicked

        Accessible.name: accessibleName
        Accessible.role: Accessible.Button
        activeFocusOnTab: true
        border.color: accent && enabled ? Config.alpha(Config.md3.secondary, 0.18) : "transparent"
        border.width: 1
        color: accent && enabled ? (headerMouse.containsMouse ? Config.md3.secondary_container : Config.alpha(Config.md3.secondary_container, 0.72)) : (headerMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent")
        height: 32
        opacity: enabled ? 1 : 0.35
        radius: 10
        width: 32

        IconImage {
            anchors.centerIn: parent
            height: 15
            layer.enabled: true
            source: headerButton.iconName === "" ? "" : Quickshell.iconPath(headerButton.iconName, "edit-clear-symbolic")
            visible: headerButton.iconName !== ""
            width: 15

            layer.effect: ColorOverlay {
                color: headerButton.accent ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
            }
        }
        Text {
            anchors.centerIn: parent
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: parent.glyph === "×" ? 19 : 17
            font.weight: Font.Medium
            text: parent.glyph
            visible: headerButton.iconName === ""
        }
        MouseArea {
            id: headerMouse

            anchors.fill: parent
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: parent.enabled
            hoverEnabled: true

            onClicked: parent.clicked()
        }
    }
    component IconButton: Rectangle {
        required property string accessibleName
        required property string iconName

        signal clicked

        Accessible.name: accessibleName
        Accessible.role: Accessible.Button
        Layout.preferredHeight: 32
        Layout.preferredWidth: 32
        activeFocusOnTab: true
        color: iconMouse.containsMouse ? Config.md3.secondary_container : Config.alpha(Config.md3.on_surface, 0.045)
        opacity: enabled ? 1 : 0.35
        radius: 10

        IconImage {
            anchors.centerIn: parent
            height: 14
            layer.enabled: true
            source: Quickshell.iconPath(parent.iconName)
            width: 14

            layer.effect: ColorOverlay {
                color: iconMouse.containsMouse ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
            }
        }
        MouseArea {
            id: iconMouse

            anchors.fill: parent
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: parent.enabled
            hoverEnabled: true

            onClicked: parent.clicked()
        }
    }
    component SectionLabel: Text {
        color: Config.md3.on_surface_variant
        font.family: Config.fontName
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }
}
