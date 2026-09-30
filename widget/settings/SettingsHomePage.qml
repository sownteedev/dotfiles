import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property var groups: [
        {
            title: qsTr("Personalization"),
            note: qsTr("Your shell, your way"),
            color: Config.md3.primary,
            foreground: Config.md3.on_primary,
            items: [
                {
                    title: qsTr("Bar & Panels"),
                    subtitle: qsTr("Layout, position and widgets"),
                    icon: "view-grid-symbolic",
                    page: 1,
                    section: 1
                },
                {
                    title: qsTr("Launcher"),
                    subtitle: qsTr("Search, apps and clipboard"),
                    icon: "system-search-symbolic",
                    page: 1,
                    section: 2
                },
                {
                    title: qsTr("Notifications"),
                    subtitle: qsTr("Popups, history and rules"),
                    icon: "preferences-system-notifications-symbolic",
                    page: 1,
                    section: 3
                }
            ]
        },
        {
            title: qsTr("Desktop"),
            note: qsTr("Make room for your workflow"),
            color: Config.md3.secondary,
            foreground: Config.md3.on_secondary,
            items: [
                {
                    title: qsTr("Layout"),
                    subtitle: qsTr("Gaps, borders and workspaces"),
                    icon: "view-grid-symbolic",
                    page: 0,
                    section: 1
                },
                {
                    title: qsTr("Keybinds"),
                    subtitle: qsTr("Keyboard shortcuts"),
                    icon: "input-keyboard-symbolic",
                    page: 0,
                    section: 0
                },
                {
                    title: qsTr("Input"),
                    subtitle: qsTr("Keyboard, mouse and touchpad"),
                    icon: "input-mouse-symbolic",
                    page: 0,
                    section: 2
                }
            ]
        },
        {
            title: qsTr("Security"),
            note: qsTr("Lock screen and power behavior"),
            color: Config.md3.tertiary,
            foreground: Config.md3.on_tertiary,
            items: [
                {
                    title: qsTr("Lock & Face"),
                    subtitle: qsTr("Lock screen and authentication"),
                    icon: "system-lock-screen-symbolic",
                    page: 2,
                    section: 0
                },
                {
                    title: qsTr("Idle & Power"),
                    subtitle: qsTr("Timeouts, suspend and Caffeine"),
                    icon: "preferences-system-power-symbolic",
                    page: 2,
                    section: 1
                }
            ]
        }
    ]
    readonly property bool headerActionVisible: false
    readonly property bool headerResetVisible: false
    readonly property string previewPath: WallpaperService.currentMode === "video" ? (WallpaperService.lastVideoFrame || WallpaperService.fallbackVideoThumbnail) : WallpaperService.displayWallpaper
    readonly property url previewSource: previewPath === "" ? "" : previewPath.startsWith("/") ? "file://" + previewPath.split("/").map(encodeURIComponent).join("/") : previewPath

    signal navigateRequested(int page, int section)

    SettingsPageContent {
        id: pageContent

        anchors.fill: parent
        pageSpacing: Md3.spacing.lg

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            color: Config.md3.surface_container_low
            implicitHeight: appearanceContent.implicitHeight + Md3.spacing.lg * 2
            radius: Md3.shape.large

            GridLayout {
                id: appearanceContent

                readonly property bool stacked: width < 620

                anchors.fill: parent
                anchors.margins: Md3.spacing.lg
                columnSpacing: Md3.spacing.lg
                columns: stacked ? 1 : 2
                rowSpacing: Md3.spacing.md

                Rectangle {
                    id: preview

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: appearanceContent.stacked ? Math.min(200, width * 9 / 16) : 200
                    Layout.preferredWidth: 320
                    clip: true
                    color: Config.md3.surface_container_high
                    radius: Md3.shape.medium

                    Image {
                        id: wallpaperImage

                        anchors.fill: parent
                        anchors.margins: Md3.spacing.sm
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        source: root.previewSource
                        sourceSize: Qt.size(640, 360)
                        visible: status === Image.Ready
                    }
                    Md3Icon {
                        anchors.centerIn: parent
                        color: Config.md3.on_surface_variant
                        name: "preferences-desktop-wallpaper-symbolic"
                        size: 40
                        visible: wallpaperImage.status !== Image.Ready
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 360
                    spacing: Md3.spacing.md

                    SettingsLabelBlock {
                        Layout.fillWidth: true
                        emphasized: true
                        headline: qsTr("A desktop that's yours")
                        headlineRole: "titleLarge"
                        supportingText: qsTr("Personalize your wallpaper, colors and shell appearance.")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Md3.spacing.sm

                        Md3Icon {
                            color: Config.md3.on_surface_variant
                            name: Config.lightTheme ? "weather-clear-symbolic" : "dark-mode-symbolic"
                            size: 20
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: Md3.typeScale.bodyMedium.size
                            text: Config.lightTheme ? qsTr("Light appearance") : qsTr("Dark appearance")
                            wrapMode: Text.Wrap
                        }
                    }
                    Row {
                        Accessible.name: qsTr("Current theme colors")
                        Accessible.role: Accessible.StaticText
                        spacing: Md3.spacing.sm

                        Repeater {
                            model: [Config.md3.primary, Config.md3.secondary, Config.md3.tertiary, Config.md3.primary_container, Config.md3.secondary_container]

                            Rectangle {
                                required property color modelData

                                Accessible.ignored: true
                                color: modelData
                                height: 24
                                radius: width / 2
                                width: 24
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: Md3.spacing.sm

                        SettingsActionButton {
                            iconName: "preferences-desktop-theme-symbolic"
                            primary: true
                            text: qsTr("General")

                            onClicked: root.navigateRequested(1, 0)
                        }
                        SettingsActionButton {
                            iconName: "preferences-desktop-wallpaper-symbolic"
                            text: qsTr("Wallpaper")

                            onClicked: root.navigateRequested(1, 4)
                        }
                    }
                }
            }
        }
        GridLayout {
            id: sections

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            columnSpacing: Md3.spacing.lg
            columns: width >= 680 ? 2 : 1
            rowSpacing: Md3.spacing.lg
            uniformCellWidths: true

            Repeater {
                model: root.groups

                SettingsSectionCard {
                    id: sectionCard

                    required property int index
                    required property var modelData

                    Layout.columnSpan: sectionCard.index === 2 ? sections.columns : 1
                    accentColor: sectionCard.modelData.color
                    compact: true
                    headerOutside: true
                    note: sectionCard.modelData.note
                    title: sectionCard.modelData.title

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        columnSpacing: Md3.spacing.sm
                        columns: sectionCard.index === 2 ? sections.columns : 1
                        rowSpacing: Md3.spacing.xxs
                        uniformCellWidths: true

                        Repeater {
                            model: sectionCard.modelData.items

                            SettingsNavButton {
                                id: shortcut

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                expandable: true
                                iconColor: sectionCard.modelData.color
                                iconForegroundColor: sectionCard.modelData.foreground
                                iconName: shortcut.modelData.icon
                                subtitle: shortcut.modelData.subtitle
                                text: shortcut.modelData.title

                                onClicked: root.navigateRequested(shortcut.modelData.page, shortcut.modelData.section)
                            }
                        }
                    }
                }
            }
        }
    }
}
