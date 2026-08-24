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
    function togglePopup() {
        filterPopup.open = !filterPopup.open;
        filterButton.forceActiveFocus();
    }

    implicitHeight: 40
    implicitWidth: 190
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
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Config.alpha(Config.md3.on_surface, 0.035)
            radius: 13

            RowLayout {
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
                        activeFocusOnTab: true
                        border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.72) : "transparent"
                        border.width: 1
                        color: selected ? Config.md3.primary_container : (typeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent")
                        radius: 10

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

            Accessible.name: WallpaperWorkshopService.activeFilterCount > 0 ? qsTr("Workshop filters, %1 active").arg(WallpaperWorkshopService.activeFilterCount) : qsTr("Workshop filters")
            Accessible.role: Accessible.Button
            Layout.fillHeight: true
            Layout.preferredWidth: 40
            activeFocusOnTab: true
            border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.72) : Config.alpha(Config.md3.outline, 0.18)
            border.width: 1
            color: filterPopup.open || WallpaperWorkshopService.activeFilterCount > 0 ? Config.md3.secondary_container : (filterMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.035))
            radius: 13

            Keys.onEscapePressed: root.closePopup()
            Keys.onReturnPressed: root.togglePopup()
            Keys.onSpacePressed: root.togglePopup()

            IconImage {
                anchors.centerIn: parent
                height: 17
                layer.enabled: true
                source: Quickshell.iconPath("view-filter-symbolic", "preferences-other-symbolic")
                width: 17

                layer.effect: ColorOverlay {
                    color: filterPopup.open || WallpaperWorkshopService.activeFilterCount > 0 ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
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
                visible: WallpaperWorkshopService.activeFilterCount > 0
                width: Math.max(18, countLabel.implicitWidth + 8)

                Text {
                    id: countLabel

                    anchors.centerIn: parent
                    color: Config.md3.on_primary
                    font.family: Config.fontName
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    text: WallpaperWorkshopService.activeFilterCount
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
                    text: WallpaperWorkshopService.activeFilterCount > 0 ? qsTr("%1 active filters").arg(WallpaperWorkshopService.activeFilterCount) : qsTr("Showing the complete catalog")
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
                    id: ageCard

                    height: implicitHeight
                    iconName: "dialog-information-symbolic"
                    title: qsTr("Age rating")
                    width: dashboard.columnWidth
                    x: 0
                    y: 0

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        Repeater {
                            model: root.ageOptions

                            delegate: FilterChip {
                                required property var modelData

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
                    y: 0

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        Repeater {
                            model: root.resolutionOptions

                            delegate: FilterChip {
                                required property var modelData

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
                    y: resolutionCard.height + 12

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        Repeater {
                            model: root.featureOptions

                            delegate: FilterChip {
                                required property string modelData

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
                    y: ageCard.height + 12

                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        spacing: 6

                        Repeater {
                            model: root.genreOptions

                            delegate: FilterChip {
                                required property string modelData

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
        implicitWidth: compact ? chipLabel.implicitWidth + 18 : chipLabel.implicitWidth + 24
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
}
