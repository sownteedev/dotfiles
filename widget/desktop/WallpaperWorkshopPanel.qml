import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property string activeTab: "browse"
    property int contentTransitionDirection: 1
    property string deleteArmedId: ""
    readonly property int gridColumns: Math.max(1, Math.floor((browser.width - 40) / 270))
    readonly property bool installedMode: activeTab === "installed"
    property bool open: false
    readonly property string panelErrorMessage: installedMode ? WallpaperWorkshopService.manageErrorMessage : WallpaperWorkshopService.browseErrorMessage
    readonly property string panelStatusMessage: installedMode ? WallpaperWorkshopService.manageStatusMessage : WallpaperWorkshopService.browseStatusMessage

    signal applyRequested(string path, var modified)
    signal closeRequested

    function closePanel() {
        if (!open)
            return;
        open = false;
        closeTimer.restart();
    }
    function selectTab(tab) {
        if (activeTab === tab) {
            if (tab === "installed")
                WallpaperWorkshopService.loadInstalled(true);
            return;
        }
        contentTransition.stop();
        contentTransitionDirection = tab === "installed" ? 1 : -1;
        activeTab = tab;
        deleteArmedId = "";
        if (installedMode)
            WallpaperWorkshopService.loadInstalled(true);
        else {
            searchInput.forceActiveFocus();
            if (WallpaperWorkshopService.configured && WallpaperWorkshopService.results.count === 0 && !WallpaperWorkshopService.searching)
                WallpaperWorkshopService.search("", 1, "trending");
        }
        contentTransition.restart();
    }
    function setNsfwVisible(enabled) {
        if (Config.wallpaperWorkshopShowNsfw === enabled)
            return;
        Config.wallpaperWorkshopShowNsfw = enabled;
    }

    anchors.fill: parent
    color: Config.alpha(Config.md3.scrim, 0.72)
    enabled: open
    opacity: open ? 1 : 0
    visible: open || opacity > 0
    z: 700

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: open = true
    Keys.onEscapePressed: root.closePanel()
    onOpenChanged: {
        if (!open)
            return;
        if (installedMode)
            WallpaperWorkshopService.loadInstalled(true);
        WallpaperWorkshopService.refreshSubscriptions(false);
        if (!installedMode)
            searchInput.forceActiveFocus();
        if (WallpaperWorkshopService.configured && WallpaperWorkshopService.results.count === 0 && !WallpaperWorkshopService.searching)
            WallpaperWorkshopService.search("", 1, "trending");
    }

    Timer {
        id: closeTimer

        interval: 180
        repeat: false

        onTriggered: root.closeRequested()
    }
    Timer {
        id: deleteArmTimer

        interval: 3200
        repeat: false

        onTriggered: root.deleteArmedId = ""
    }
    Connections {
        function onDownloadCompleted(publishedFileId, path, modified) {
            root.applyRequested(path, modified);
        }

        target: WallpaperWorkshopService
    }
    MouseArea {
        anchors.fill: parent

        onClicked: root.closePanel()
    }
    Rectangle {
        id: browser

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.outline, 0.24)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, 0.98)
        height: Math.min(parent.height - 64, 780)
        radius: 24
        width: Math.min(parent.width - 64, 1180)

        MouseArea {
            anchors.fill: parent

            onClicked: mouse => mouse.accepted = true
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredHeight: 46
                    Layout.preferredWidth: 46
                    color: Config.md3.primary_container
                    radius: 15

                    IconImage {
                        anchors.centerIn: parent
                        height: 24
                        layer.enabled: true
                        source: Quickshell.iconPath("steam-symbolic")
                        width: 24

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_primary_container
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        text: qsTr("Steam Workshop")
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 13
                        text: root.panelStatusMessage !== "" ? root.panelStatusMessage : qsTr("Find, install and manage Wallpaper Engine projects")
                    }
                }
                Rectangle {
                    Layout.preferredHeight: 42
                    Layout.preferredWidth: 42
                    color: closeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.10) : Config.alpha(Config.md3.on_surface, 0.055)
                    radius: 14

                    IconImage {
                        anchors.centerIn: parent
                        height: 20
                        layer.enabled: true
                        source: Quickshell.iconPath("window-close-symbolic")
                        width: 20

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface
                        }
                    }
                    MouseArea {
                        id: closeMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.closePanel()
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                border.color: Config.alpha(WallpaperWorkshopService.loginRequired ? Config.md3.tertiary : Config.md3.error, 0.28)
                border.width: 1
                color: WallpaperWorkshopService.loginRequired ? Config.alpha(Config.md3.tertiary_container, 0.72) : Config.alpha(Config.md3.error_container, 0.72)
                radius: 17
                visible: root.panelErrorMessage !== ""

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 10
                    spacing: 12

                    IconImage {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: 22
                        layer.enabled: true
                        source: Quickshell.iconPath(WallpaperWorkshopService.loginRequired ? "dialog-password-symbolic" : "dialog-warning-symbolic")

                        layer.effect: ColorOverlay {
                            color: WallpaperWorkshopService.loginRequired ? Config.md3.on_tertiary_container : Config.md3.on_error_container
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            color: WallpaperWorkshopService.loginRequired ? Config.md3.on_tertiary_container : Config.md3.on_error_container
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            text: WallpaperWorkshopService.loginRequired ? qsTr("SteamCMD sign-in required") : qsTr("Workshop action failed")
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(WallpaperWorkshopService.loginRequired ? Config.md3.on_tertiary_container : Config.md3.on_error_container, 0.78)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 12
                            text: WallpaperWorkshopService.loginRequired ? qsTr("Sign in once in Black Box, then retry the download") : root.panelErrorMessage
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: loginButtonRow.implicitWidth + 28
                        color: loginMouse.pressed ? Config.alpha(Config.md3.on_tertiary_container, 0.16) : (loginMouse.containsMouse ? Config.alpha(Config.md3.on_tertiary_container, 0.11) : Config.md3.tertiary)
                        enabled: !WallpaperWorkshopService.loginRunning
                        opacity: enabled ? 1 : 0.65
                        radius: 14
                        visible: WallpaperWorkshopService.loginRequired

                        Row {
                            id: loginButtonRow

                            anchors.centerIn: parent
                            spacing: 8

                            LoadingIndicator {
                                anchors.verticalCenter: parent.verticalCenter
                                animated: WallpaperWorkshopService.loginRunning
                                height: 18
                                visible: animated
                                width: 18
                            }
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 18
                                layer.enabled: true
                                source: Quickshell.iconPath("utilities-terminal-symbolic")
                                visible: !WallpaperWorkshopService.loginRunning
                                width: 18

                                layer.effect: ColorOverlay {
                                    color: Config.md3.on_tertiary
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                color: Config.md3.on_tertiary
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                text: WallpaperWorkshopService.loginRunning ? qsTr("Signing in…") : qsTr("Login SteamCMD")
                            }
                        }
                        MouseArea {
                            id: loginMouse

                            anchors.fill: parent
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: parent.enabled
                            hoverEnabled: true

                            onClicked: WallpaperWorkshopService.loginSteamCmd()
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    id: primaryTabs

                    Layout.preferredHeight: 44
                    Layout.preferredWidth: 224
                    color: Config.alpha(Config.md3.on_surface, 0.045)
                    radius: 15

                    Rectangle {
                        id: primaryTabIndicator

                        color: Config.md3.primary_container
                        height: parent.height - 8
                        radius: 12
                        width: (parent.width - 11) / 2
                        x: 4 + (root.installedMode ? width + 3 : 0)
                        y: 4

                        Behavior on x {
                            XAnimator {
                                duration: 190
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 3

                        Repeater {
                            model: [
                                {
                                    "icon": "system-search-symbolic",
                                    "label": qsTr("Browse"),
                                    "value": "browse"
                                },
                                {
                                    "icon": "folder-symbolic",
                                    "label": qsTr("Installed"),
                                    "value": "installed"
                                }
                            ]

                            delegate: Rectangle {
                                id: tabChip

                                required property var modelData
                                readonly property bool selected: root.activeTab === modelData.value

                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                color: !selected && tabMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent"
                                radius: 12

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 7

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 16
                                        layer.enabled: true
                                        source: Quickshell.iconPath(tabChip.modelData.icon)
                                        width: 16

                                        layer.effect: ColorOverlay {
                                            color: tabChip.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 140
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: tabChip.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                                        font.family: Config.fontName
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        text: tabChip.modelData.label

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 140
                                            }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: tabMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: root.selectTab(tabChip.modelData.value)
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Rectangle {
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 142
                    border.color: Config.alpha(Config.wallpaperWorkshopShowNsfw ? Config.md3.error : Config.md3.outline, 0.22)
                    border.width: 1
                    color: Config.wallpaperWorkshopShowNsfw ? Config.alpha(Config.md3.error_container, 0.72) : Config.alpha(Config.md3.on_surface, 0.035)
                    radius: 14
                    visible: !root.installedMode && WallpaperWorkshopService.configured

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        IconImage {
                            Layout.preferredHeight: 16
                            Layout.preferredWidth: 16
                            layer.enabled: true
                            source: Quickshell.iconPath(Config.wallpaperWorkshopShowNsfw ? "view-reveal-symbolic" : "view-conceal-symbolic")

                            layer.effect: ColorOverlay {
                                color: Config.wallpaperWorkshopShowNsfw ? Config.md3.on_error_container : Config.md3.on_surface_variant

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 140
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.wallpaperWorkshopShowNsfw ? Config.md3.on_error_container : Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: qsTr("NSFW")

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }
                        }
                        ToggleSwitch {
                            accessibleName: qsTr("Show NSFW Workshop previews")
                            checked: Config.wallpaperWorkshopShowNsfw
                            checkedColor: Config.md3.error

                            onToggled: checked => root.setNsfwVisible(checked)
                        }
                    }
                }
                Rectangle {
                    id: sortTabs

                    readonly property int selectedIndex: WallpaperWorkshopService.sortMode === "popular" ? 1 : (WallpaperWorkshopService.sortMode === "recent" ? 2 : 0)

                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 294
                    color: Config.alpha(Config.md3.on_surface, 0.035)
                    radius: 14
                    visible: !root.installedMode && WallpaperWorkshopService.configured

                    Rectangle {
                        id: sortTabIndicator

                        color: Config.md3.secondary_container
                        height: parent.height - 6
                        radius: 11
                        width: (parent.width - 10) / 3
                        x: 3 + sortTabs.selectedIndex * (width + 2)
                        y: 3

                        Behavior on x {
                            XAnimator {
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 2

                        Repeater {
                            model: [
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
                                }
                            ]

                            delegate: Rectangle {
                                id: sortChip

                                required property var modelData
                                readonly property bool selected: WallpaperWorkshopService.sortMode === modelData.value

                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                color: !selected && sortMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : "transparent"
                                radius: 11

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 110
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    color: sortChip.selected ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    text: sortChip.modelData.label

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 130
                                        }
                                    }
                                }
                                MouseArea {
                                    id: sortMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: WallpaperWorkshopService.search(searchInput.text, 1, sortChip.modelData.value)
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                border.color: searchInput.activeFocus ? Config.alpha(Config.md3.primary, 0.68) : Config.alpha(Config.md3.outline, 0.16)
                border.width: 1
                color: Config.alpha(Config.md3.on_surface, 0.035)
                radius: 17
                visible: !root.installedMode && WallpaperWorkshopService.configured

                IconImage {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    layer.enabled: true
                    source: Quickshell.iconPath("system-search-symbolic")
                    width: 20

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface_variant
                    }
                }
                TextInput {
                    id: searchInput

                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: 48
                    anchors.right: searchAction.left
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 15
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter

                    Keys.onReturnPressed: WallpaperWorkshopService.search(text, 1, WallpaperWorkshopService.sortMode)
                }
                Text {
                    anchors.fill: searchInput
                    color: Config.alpha(Config.md3.on_surface, 0.38)
                    font: searchInput.font
                    text: qsTr("Search Wallpaper Engine Workshop")
                    verticalAlignment: Text.AlignVCenter
                    visible: searchInput.text === ""
                }
                Rectangle {
                    id: searchAction

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: searchMouse.pressed ? Config.md3.primary_container : (searchMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.86) : Config.md3.primary)
                    enabled: !WallpaperWorkshopService.searching
                    height: 38
                    opacity: enabled ? 1 : 0.55
                    radius: 13
                    width: 46

                    IconImage {
                        anchors.centerIn: parent
                        height: 19
                        layer.enabled: true
                        source: Quickshell.iconPath("system-search-symbolic")
                        width: 19

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_primary
                        }
                    }
                    MouseArea {
                        id: searchMouse

                        anchors.fill: parent
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: parent.enabled
                        hoverEnabled: true

                        onClicked: WallpaperWorkshopService.search(searchInput.text, 1, WallpaperWorkshopService.sortMode)
                    }
                }
            }
            Item {
                id: contentHost

                Layout.fillHeight: true
                Layout.fillWidth: true

                Item {
                    id: animatedContent

                    anchors.fill: parent

                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: !root.installedMode && !WallpaperWorkshopService.configured
                        width: Math.min(parent.width - 40, 520)

                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 52
                            layer.enabled: true
                            source: Quickshell.iconPath("dialog-password-symbolic")
                            width: 52

                            layer.effect: ColorOverlay {
                                color: Config.md3.primary
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 19
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("Workshop search needs Steam setup")
                            width: parent.width
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("Add your Steam username and Web API key in Settings → Integrations → Wallpaper Engine")
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                    }
                    LoadingIndicator {
                        anchors.centerIn: parent
                        animated: root.installedMode ? WallpaperWorkshopService.listingInstalled : WallpaperWorkshopService.searching
                        visible: animated
                    }
                    GridView {
                        id: resultGrid

                        anchors.fill: parent
                        cacheBuffer: cellHeight
                        cellHeight: cellWidth * 0.72
                        cellWidth: width / root.gridColumns
                        clip: true
                        model: root.installedMode ? WallpaperWorkshopService.installedResults : WallpaperWorkshopService.results
                        visible: (root.installedMode || WallpaperWorkshopService.configured) && !(root.installedMode ? WallpaperWorkshopService.listingInstalled : WallpaperWorkshopService.searching) && count > 0

                        ScrollBar.vertical: SlimScrollBar {
                        }
                        delegate: WallpaperWorkshopCard {
                            required property var model

                            blurNsfw: !Config.wallpaperWorkshopShowNsfw
                            cancelling: WallpaperWorkshopService.downloadCancelling && WallpaperWorkshopService.downloadingId === String(model.id || "")
                            deleteArmed: root.deleteArmedId === String(model.id || "")
                            downloading: WallpaperWorkshopService.downloadingId === String(model.id || "")
                            height: resultGrid.cellHeight
                            inUse: root.installedMode && String(WallpaperService.currentWallpaper || "") === String(model.path || "")
                            installedMode: root.installedMode
                            removing: WallpaperWorkshopService.removingId === String(model.id || "")
                            wallpaper: model
                            width: resultGrid.cellWidth

                            onApplyRequested: (path, modified) => root.applyRequested(path, modified)
                            onArmDeleteRequested: publishedFileId => {
                                root.deleteArmedId = publishedFileId;
                                deleteArmTimer.restart();
                            }
                            onCancelDownloadRequested: WallpaperWorkshopService.cancelDownload()
                            onDeleteRequested: item => {
                                root.deleteArmedId = "";
                                deleteArmTimer.stop();
                                WallpaperWorkshopService.removeInstalled(item);
                            }
                            onDownloadRequested: item => WallpaperWorkshopService.download(item)
                            onSubscribeRequested: item => WallpaperWorkshopService.openInSteam(item)
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: (root.installedMode || WallpaperWorkshopService.configured) && !(root.installedMode ? WallpaperWorkshopService.listingInstalled : WallpaperWorkshopService.searching) && (root.installedMode ? WallpaperWorkshopService.installedResults.count : WallpaperWorkshopService.results.count) === 0
                        width: Math.max(0, parent.width - 48)

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            text: root.panelErrorMessage !== "" ? (root.installedMode ? qsTr("Installed wallpapers unavailable") : qsTr("Search unavailable")) : (root.installedMode ? qsTr("No installed Workshop wallpapers") : qsTr("No wallpapers found"))
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                        Text {
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            text: root.panelErrorMessage !== "" ? root.panelErrorMessage : (root.installedMode ? qsTr("Downloaded Workshop wallpapers will appear here") : qsTr("Try another search"))
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
            ParallelAnimation {
                id: contentTransition

                OpacityAnimator {
                    duration: 180
                    easing.type: Easing.OutCubic
                    from: 0
                    target: animatedContent
                    to: 1
                }
                XAnimator {
                    duration: 210
                    easing.type: Easing.OutCubic
                    from: root.contentTransitionDirection * 14
                    target: animatedContent
                    to: 0
                }
            }
        }
    }
}
