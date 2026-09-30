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

    readonly property var ageOptions: [
        {
            "label": qsTr("Any"),
            "value": ""
        },
        {
            "label": qsTr("Everyone"),
            "value": "Everyone"
        },
        {
            "label": qsTr("Questionable"),
            "value": "Questionable"
        },
        {
            "label": qsTr("Mature"),
            "value": "Mature"
        }
    ]
    readonly property var featureOptions: ["Approved", "Audio Responsive", "3D", "Customizable", "Puppet Warp", "HDR", "Media Integration", "User Shortcut", "Video Texture"]
    readonly property var genreOptions: ["Abstract", "Animal", "Anime", "Cartoon", "CGI", "Cyberpunk", "Fantasy", "Game", "Girls", "Guys", "Landscape", "Medieval", "Memes", "MMD", "Music", "Nature", "Pixel Art", "Relaxing", "Retro", "Sci-Fi", "Sports", "Technology", "Television", "Vehicle"]
    property bool installedMode: false
    readonly property bool popupOpen: filterPopup.visible
    property Item popupParent: null
    readonly property var resolutionOptions: [
        {
            "label": qsTr("Any"),
            "value": ""
        },
        {
            "label": qsTr("Dynamic"),
            "value": "Dynamic Resolution"
        },
        {
            "label": "1280 × 720",
            "value": "1280 x 720"
        },
        {
            "label": "1366 × 768",
            "value": "1366 x 768"
        },
        {
            "label": "1920 × 1080",
            "value": "1920 x 1080"
        },
        {
            "label": "2560 × 1080",
            "value": "2560 x 1080"
        },
        {
            "label": "2560 × 1440",
            "value": "2560 x 1440"
        },
        {
            "label": "3440 × 1440",
            "value": "3440 x 1440"
        },
        {
            "label": "3840 × 1080",
            "value": "3840 x 1080"
        },
        {
            "label": "3840 × 2160",
            "value": "3840 x 2160"
        },
        {
            "label": "5120 × 1440",
            "value": "5120 x 1440"
        },
        {
            "label": "7680 × 1440",
            "value": "7680 x 1440"
        },
        {
            "label": qsTr("Other"),
            "value": "Other Resolution"
        }
    ]
    readonly property var sortOptions: [
        {
            "label": qsTr("Trending"),
            "value": "trending"
        },
        {
            "label": qsTr("Popular"),
            "value": "popular"
        },
        {
            "label": qsTr("Newest"),
            "value": "recent"
        },
        {
            "label": qsTr("Relevance"),
            "value": "relevance"
        },
        {
            "label": qsTr("Most subscribed"),
            "value": "subscribed"
        },
        {
            "label": qsTr("Votes up"),
            "value": "votes_up"
        },
        {
            "label": qsTr("Most played"),
            "value": "played"
        },
        {
            "label": qsTr("Last updated"),
            "value": "updated"
        }
    ]

    signal searchRequested

    function closePopup() {
        filterPopup.open = false;
    }
    function featureLabel(value) {
        var labels = {
            "3D": qsTr("3D"),
            "Approved": qsTr("Approved"),
            "Audio Responsive": qsTr("Audio responsive"),
            "Customizable": qsTr("Customizable"),
            "HDR": qsTr("HDR"),
            "Media Integration": qsTr("Media integration"),
            "Puppet Warp": qsTr("Puppet warp"),
            "User Shortcut": qsTr("User shortcut"),
            "Video Texture": qsTr("Video texture")
        };
        return labels[value] || value;
    }
    function filterChanged() {
        if (!installedMode)
            searchDebounce.restart();
    }
    function genreLabel(value) {
        var labels = {
            "Abstract": qsTr("Abstract"),
            "Animal": qsTr("Animal"),
            "Anime": qsTr("Anime"),
            "CGI": qsTr("CGI"),
            "Cartoon": qsTr("Cartoon"),
            "Cyberpunk": qsTr("Cyberpunk"),
            "Fantasy": qsTr("Fantasy"),
            "Game": qsTr("Game"),
            "Girls": qsTr("Girls"),
            "Guys": qsTr("Guys"),
            "Landscape": qsTr("Landscape"),
            "MMD": qsTr("MMD"),
            "Medieval": qsTr("Medieval"),
            "Memes": qsTr("Memes"),
            "Music": qsTr("Music"),
            "Nature": qsTr("Nature"),
            "Pixel Art": qsTr("Pixel art"),
            "Relaxing": qsTr("Relaxing"),
            "Retro": qsTr("Retro"),
            "Sci-Fi": qsTr("Sci-Fi"),
            "Sports": qsTr("Sports"),
            "Technology": qsTr("Technology"),
            "Television": qsTr("Television"),
            "Vehicle": qsTr("Vehicle")
        };
        return labels[value] || value;
    }
    function sortLabel(mode) {
        for (var index = 0; index < sortOptions.length; ++index) {
            if (sortOptions[index].value === mode)
                return sortOptions[index].label;
        }
        return qsTr("Trending");
    }
    function togglePopup() {
        filterPopup.open = !filterPopup.open;
    }

    implicitHeight: 40
    implicitWidth: 320
    z: filterPopup.visible ? 240 : 0

    onInstalledModeChanged: closePopup()

    Timer {
        id: searchDebounce

        interval: 220
        repeat: false

        onTriggered: root.searchRequested()
    }
    RowLayout {
        anchors.fill: parent
        spacing: 6

        Rectangle {
            id: typeContainer

            readonly property int selectedIndex: WallpaperWorkshopService.typeFilter === "video" ? 1 : (WallpaperWorkshopService.typeFilter === "scene" ? 2 : 0)

            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Config.alpha(Config.md3.on_surface, 0.035)
            radius: Md3.shape.full

            Rectangle {
                id: typeIndicator

                color: Config.md3.primary_container
                height: parent.height - 6
                radius: Md3.shape.full
                width: Math.max(0, (parent.width - 10) / 3)
                x: 3 + typeContainer.selectedIndex * (width + 2)
                y: 3

                Behavior on x {
                    XAnimator {
                        duration: 190
                        easing.type: Easing.OutCubic
                    }
                }
            }
            RowLayout {
                id: typeRow

                anchors.fill: parent
                anchors.margins: 3
                spacing: 2

                Repeater {
                    model: [
                        {
                            "icon": "view-grid-symbolic",
                            "label": qsTr("All types"),
                            "value": "all"
                        },
                        {
                            "icon": "video-x-generic-symbolic",
                            "label": qsTr("Video"),
                            "value": "video"
                        },
                        {
                            "icon": "image-x-generic-symbolic",
                            "label": qsTr("Scene"),
                            "value": "scene"
                        }
                    ]

                    delegate: Rectangle {
                        id: typeButton

                        required property var modelData
                        readonly property bool selected: WallpaperWorkshopService.typeFilter === modelData.value

                        Accessible.name: modelData.label
                        Accessible.role: Accessible.Button
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        activeFocusOnTab: false
                        border.color: "transparent"
                        border.width: 0
                        color: typeMouse.pressed ? Config.alpha(selected ? Config.md3.on_primary_container : Config.md3.on_surface, 0.12) : (typeMouse.containsMouse ? Config.alpha(selected ? Config.md3.on_primary_container : Config.md3.on_surface, 0.08) : "transparent")
                        radius: Md3.shape.full

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(Md3.motion.short2)
                            }
                        }

                        Keys.onReturnPressed: typeMouse.activate()
                        Keys.onSpacePressed: typeMouse.activate()

                        IconImage {
                            anchors.centerIn: parent
                            height: 16
                            layer.enabled: true
                            source: Quickshell.iconPath(typeButton.modelData.icon, "preferences-other-symbolic")
                            width: 16

                            layer.effect: ColorOverlay {
                                color: typeButton.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 140
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: typeMouse

                            function activate() {
                                if (WallpaperWorkshopService.setTypeFilter(typeButton.modelData.value))
                                    root.filterChanged();
                            }

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: activate()
                        }
                    }
                }
            }
        }
        Rectangle {
            id: filterButton

            readonly property bool active: filterPopup.open || WallpaperWorkshopService.activeFilterCount > 0
            readonly property color contentColor: active ? Config.md3.on_secondary_container : (filterMouse.containsMouse ? Config.md3.on_surface : Config.md3.on_surface_variant)

            Accessible.name: WallpaperWorkshopService.activeFilterCount > 0 ? qsTr("Workshop filters, sorted by %1, %2 active").arg(root.sortLabel(WallpaperWorkshopService.sortMode)).arg(WallpaperWorkshopService.activeFilterCount) : qsTr("Workshop filters, sorted by %1").arg(root.sortLabel(WallpaperWorkshopService.sortMode))
            Accessible.role: Accessible.Button
            Layout.fillHeight: true
            Layout.preferredWidth: 154
            activeFocusOnTab: false
            border.color: filterMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.38) : (active ? Config.alpha(Config.md3.secondary, 0.24) : Config.alpha(Config.md3.outline, 0.18))
            border.width: 1
            color: active ? Config.md3.secondary_container : Config.alpha(Config.md3.on_surface, 0.035)
            radius: Md3.shape.full

            Behavior on border.color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short2)
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short2)
                }
            }

            Keys.onEscapePressed: root.closePopup()
            Keys.onReturnPressed: root.togglePopup()
            Keys.onSpacePressed: root.togglePopup()

            Rectangle {
                anchors.fill: parent
                color: filterMouse.pressed ? Config.alpha(filterButton.active ? Config.md3.on_secondary_container : Config.md3.on_surface, 0.12) : (filterMouse.containsMouse ? Config.alpha(filterButton.active ? Config.md3.on_secondary_container : Config.md3.on_surface, 0.08) : "transparent")
                radius: parent.radius

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(Md3.motion.short2)
                    }
                }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 11
                anchors.rightMargin: 10
                spacing: 6

                Md3Icon {
                    Layout.alignment: Qt.AlignVCenter
                    color: filterButton.contentColor
                    name: "view-filter-symbolic"
                    size: 16

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(Md3.motion.short2)
                        }
                    }
                }
                Text {
                    id: sortLabelText

                    Layout.fillWidth: true
                    color: filterButton.contentColor
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    text: root.sortLabel(WallpaperWorkshopService.sortMode)

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(Md3.motion.short2)
                        }
                    }
                }
                Rectangle {
                    id: filterBadge

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: WallpaperWorkshopService.activeFilterCount > 9 ? 24 : 18
                    color: Config.md3.primary
                    opacity: WallpaperWorkshopService.activeFilterCount > 0 ? 1 : 0
                    radius: 9
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animationDuration(Md3.motion.short2)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.on_primary
                        font.family: Config.fontName
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        text: WallpaperWorkshopService.activeFilterCount
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    color: filterButton.contentColor
                    font.family: Config.fontName
                    font.pixelSize: 13
                    text: filterPopup.open ? "⌃" : "⌄"

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(Md3.motion.short2)
                        }
                    }
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
        WheelHandler {
            blocking: true
            target: null
        }
        MouseArea {
            acceptedButtons: Qt.AllButtons
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true

            onWheel: event => event.accepted = true
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
                    text: qsTr("Refine Wallpaper Engine")
                }
                Text {
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 11
                    text: WallpaperWorkshopService.activeFilterCount > 0 ? qsTr("%1 active filters").arg(WallpaperWorkshopService.activeFilterCount) : qsTr("Safe catalog · Trending this week")
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
                    enabled: WallpaperWorkshopService.activeFilterCount > 0
                    iconName: "edit-clear-all-symbolic"

                    onClicked: {
                        if (WallpaperWorkshopService.clearFilters())
                            root.filterChanged();
                    }
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
                implicitHeight: Math.max(genresCard.y + genresCard.height, featuresCard.y + featuresCard.height)
                width: filterFlickable.width - 8

                FilterCard {
                    id: discoveryCard

                    height: implicitHeight
                    iconName: "view-sort-descending-symbolic"
                    title: qsTr("Discovery")
                    width: dashboard.width
                    x: 0
                    y: 0

                    SectionLabel {
                        Layout.fillWidth: true
                        text: qsTr("Sort by")
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columnSpacing: 6
                        columns: 4
                        rowSpacing: 6

                        Repeater {
                            model: root.sortOptions

                            delegate: FilterChip {
                                required property var modelData

                                Layout.fillWidth: true
                                label: modelData.label
                                selected: WallpaperWorkshopService.sortMode === modelData.value

                                onClicked: {
                                    if (WallpaperWorkshopService.setSortMode(modelData.value))
                                        root.filterChanged();
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 18

                        MiniGroup {
                            Layout.fillWidth: true

                            SectionLabel {
                                Layout.fillWidth: true
                                text: qsTr("Tag matching")
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                FilterChip {
                                    Layout.fillWidth: true
                                    label: qsTr("Match all")
                                    selected: WallpaperWorkshopService.matchAllTags

                                    onClicked: {
                                        if (WallpaperWorkshopService.setMatchAllTags(true))
                                            root.filterChanged();
                                    }
                                }
                                FilterChip {
                                    Layout.fillWidth: true
                                    label: qsTr("Match any")
                                    selected: !WallpaperWorkshopService.matchAllTags

                                    onClicked: {
                                        if (WallpaperWorkshopService.setMatchAllTags(false))
                                            root.filterChanged();
                                    }
                                }
                            }
                        }
                        MiniGroup {
                            Layout.fillWidth: true
                            opacity: WallpaperWorkshopService.sortMode === "trending" ? 1 : 0.42

                            SectionLabel {
                                Layout.fillWidth: true
                                text: qsTr("Trending window")
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                FilterChip {
                                    Layout.fillWidth: true
                                    enabled: WallpaperWorkshopService.sortMode === "trending"
                                    label: qsTr("1 day")
                                    selected: WallpaperWorkshopService.trendingDays === 1

                                    onClicked: {
                                        if (WallpaperWorkshopService.setTrendingDays(1))
                                            root.filterChanged();
                                    }
                                }
                                FilterChip {
                                    Layout.fillWidth: true
                                    enabled: WallpaperWorkshopService.sortMode === "trending"
                                    label: qsTr("7 days")
                                    selected: WallpaperWorkshopService.trendingDays === 7

                                    onClicked: {
                                        if (WallpaperWorkshopService.setTrendingDays(7))
                                            root.filterChanged();
                                    }
                                }
                            }
                        }
                        MiniGroup {
                            Layout.fillWidth: true

                            SectionLabel {
                                Layout.fillWidth: true
                                text: qsTr("Content")
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                FilterChip {
                                    Layout.fillWidth: true
                                    accentColor: Config.md3.error_container
                                    label: qsTr("Include NSFW")
                                    selected: WallpaperWorkshopService.includeNsfw
                                    selectedTextColor: Config.md3.on_error_container

                                    onClicked: {
                                        if (WallpaperWorkshopService.setIncludeNsfw(!WallpaperWorkshopService.includeNsfw))
                                            root.filterChanged();
                                    }
                                }
                                FilterChip {
                                    Layout.fillWidth: true
                                    label: qsTr("Recent votes")
                                    selected: WallpaperWorkshopService.includeRecentVotesOnly

                                    onClicked: {
                                        if (WallpaperWorkshopService.setIncludeRecentVotesOnly(!WallpaperWorkshopService.includeRecentVotesOnly))
                                            root.filterChanged();
                                    }
                                }
                            }
                        }
                    }
                }
                FilterCard {
                    id: ageCard

                    height: implicitHeight
                    iconName: "dialog-information-symbolic"
                    title: qsTr("Age rating")
                    width: dashboard.columnWidth
                    x: 0
                    y: discoveryCard.height + 12

                    GridLayout {
                        Layout.fillWidth: true
                        columnSpacing: 6
                        columns: 4
                        rowSpacing: 6

                        Repeater {
                            model: root.ageOptions

                            delegate: FilterChip {
                                required property var modelData

                                Layout.fillWidth: true
                                accentColor: modelData.value === "Mature" ? Config.md3.error_container : Config.md3.primary_container
                                label: modelData.label
                                selected: WallpaperWorkshopService.ageRatingFilter === modelData.value
                                selectedTextColor: modelData.value === "Mature" ? Config.md3.on_error_container : Config.md3.on_primary_container

                                onClicked: {
                                    if (WallpaperWorkshopService.setAgeRatingFilter(modelData.value))
                                        root.filterChanged();
                                }
                            }
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
                    y: discoveryCard.height + 12

                    GridLayout {
                        Layout.fillWidth: true
                        columnSpacing: 6
                        columns: 4
                        rowSpacing: 6

                        Repeater {
                            model: root.resolutionOptions

                            delegate: FilterChip {
                                required property var modelData

                                Layout.fillWidth: true
                                compact: modelData.value !== "" && modelData.value !== "Dynamic Resolution"
                                label: modelData.label
                                selected: WallpaperWorkshopService.resolutionFilter === modelData.value

                                onClicked: {
                                    if (WallpaperWorkshopService.setResolutionFilter(modelData.value))
                                        root.filterChanged();
                                }
                            }
                        }
                    }
                }
                FilterCard {
                    id: featuresCard

                    height: implicitHeight
                    iconName: "preferences-other-symbolic"
                    title: qsTr("Features")
                    width: dashboard.columnWidth
                    x: dashboard.columnWidth + 12
                    y: resolutionCard.y + resolutionCard.height + 12

                    GridLayout {
                        Layout.fillWidth: true
                        columnSpacing: 6
                        columns: 3
                        rowSpacing: 6

                        Repeater {
                            model: root.featureOptions

                            delegate: FilterChip {
                                required property string modelData

                                Layout.fillWidth: true
                                label: root.featureLabel(modelData)
                                selected: WallpaperWorkshopService.containsFilter(WallpaperWorkshopService.featureFilters, modelData)

                                onClicked: {
                                    WallpaperWorkshopService.toggleFeatureFilter(modelData);
                                    root.filterChanged();
                                }
                            }
                        }
                    }
                }
                FilterCard {
                    id: genresCard

                    height: implicitHeight
                    iconName: "applications-graphics-symbolic"
                    title: qsTr("Genres")
                    width: dashboard.columnWidth
                    x: 0
                    y: ageCard.y + ageCard.height + 12

                    GridLayout {
                        Layout.fillWidth: true
                        columnSpacing: 6
                        columns: 4
                        rowSpacing: 6

                        Repeater {
                            model: root.genreOptions

                            delegate: FilterChip {
                                required property string modelData

                                Layout.fillWidth: true
                                label: root.genreLabel(modelData)
                                selected: WallpaperWorkshopService.containsFilter(WallpaperWorkshopService.genreFilters, modelData)

                                onClicked: {
                                    WallpaperWorkshopService.toggleGenreFilter(modelData);
                                    root.filterChanged();
                                }
                            }
                        }
                    }
                }
            }
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
                spacing: 9

                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 28
                    color: Config.alpha(Config.md3.primary, 0.12)
                    radius: 9

                    IconImage {
                        anchors.centerIn: parent
                        height: 15
                        layer.enabled: true
                        source: Quickshell.iconPath(card.iconName, "preferences-other-symbolic")
                        width: 15

                        layer.effect: ColorOverlay {
                            color: Config.md3.primary
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 14
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
        Layout.preferredWidth: 0
        activeFocusOnTab: false
        border.color: selected ? Config.alpha(Config.md3.primary, 0.24) : chipMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.34) : Config.alpha(Config.md3.outline, 0.12)
        border.width: 1
        color: selected ? accentColor : (chipMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.025))
        implicitHeight: compact ? 29 : 31
        implicitWidth: compact ? chipLabel.implicitWidth + 18 : chipLabel.implicitWidth + 24
        radius: compact ? 9 : 11

        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()

        Text {
            id: chipLabel

            anchors.centerIn: parent
            color: chip.selected ? chip.selectedTextColor : Config.md3.on_surface_variant
            elide: Text.ElideRight
            font.family: Config.fontName
            font.pixelSize: chip.compact ? 10 : 12
            font.weight: chip.selected ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
            text: chip.label
            width: Math.max(0, parent.width - 14)
        }
        MouseArea {
            id: chipMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
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
        activeFocusOnTab: false
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
    component MiniGroup: Rectangle {
        id: miniGroup

        default property alias groupContent: groupBody.data

        Layout.preferredWidth: 0
        border.color: Config.alpha(Config.md3.outline, 0.08)
        border.width: 1
        color: Config.alpha(Config.md3.on_surface, 0.025)
        implicitHeight: groupBody.implicitHeight + 20
        radius: 12

        ColumnLayout {
            id: groupBody

            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
        }
    }
    component SectionLabel: Text {
        color: Config.md3.on_surface_variant
        font.family: Config.fontName
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
}
