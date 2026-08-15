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

    readonly property string actionError: installedMode ? WallhavenService.removeErrorMessage : WallhavenService.downloadErrorMessage
    property string activeTab: "browse"
    readonly property bool collectionsMode: activeTab === "collections"
    property int contentTransitionDirection: 1
    property string deleteArmedId: ""
    readonly property int gridColumns: Math.max(1, Math.floor((browser.width - 44) / 280))
    readonly property bool installedMode: activeTab === "installed"
    readonly property bool nsfwVisible: Config.wallhavenApiKey.trim() !== "" && Config.wallhavenShowNsfw
    property bool open: false
    readonly property string resultError: installedMode ? WallhavenService.installedErrorMessage : (collectionsMode ? WallhavenService.collectionErrorMessage : WallhavenService.searchErrorMessage)
    readonly property bool resultLoading: installedMode ? WallhavenService.listingInstalled : (collectionsMode ? WallhavenService.loadingCollection || WallhavenService.loadingCollections : WallhavenService.searching)
    readonly property var resultModel: installedMode ? WallhavenService.installedResults : (collectionsMode ? WallhavenService.collectionResults : WallhavenService.results)

    signal applyRequested(string path, var modified)
    signal closeRequested

    function closePanel() {
        if (!open)
            return;

        browseControls.closePopup();
        open = false;
        closeTimer.restart();
    }
    function goToNextPage() {
        if (collectionsMode)
            WallhavenService.loadCollection(WallhavenService.selectedCollectionId, WallhavenService.selectedCollectionLabel, WallhavenService.collectionPage + 1);
        else
            performSearch(WallhavenService.page + 1, true);
    }
    function goToPreviousPage() {
        if (collectionsMode)
            WallhavenService.loadCollection(WallhavenService.selectedCollectionId, WallhavenService.selectedCollectionLabel, WallhavenService.collectionPage - 1);
        else
            performSearch(WallhavenService.page - 1, true);
    }
    function performSearch(page, preserveRandomSeed) {
        WallhavenService.search(wallhavenSearch.text, page || 1, WallhavenService.sorting, preserveRandomSeed === true);
    }
    function resetResultView() {
        resultGrid.currentIndex = -1;
        resultGrid.positionViewAtBeginning();
        resultGrid.forceLayout();
    }
    function selectCollection(item) {
        if (!item)
            return;

        resetResultView();
        WallhavenService.loadCollection(String(item.id || ""), String(item.label || ""), 1);
    }
    function selectTab(tab) {
        if (activeTab === tab) {
            resetResultView();
            if (tab === "collections")
                WallhavenService.loadCollections(true);
            else if (tab === "installed")
                WallhavenService.loadInstalled(true);
            return;
        }
        contentTransition.stop();
        browseControls.closePopup();
        var oldIndex = activeTab === "browse" ? 0 : (activeTab === "collections" ? 1 : 2);
        var newIndex = tab === "browse" ? 0 : (tab === "collections" ? 1 : 2);
        contentTransitionDirection = newIndex > oldIndex ? 1 : -1;
        activeTab = tab;
        deleteArmedId = "";
        Qt.callLater(() => {
            return root.resetResultView();
        });
        if (collectionsMode) {
            WallhavenService.loadCollections(false);
        } else if (installedMode) {
            WallhavenService.loadInstalled(true);
        } else {
            wallhavenSearch.focusInput();
            if (WallhavenService.results.count === 0 && !WallhavenService.searching)
                performSearch(1);
        }
        contentTransition.restart();
    }

    anchors.fill: parent
    color: Config.alpha(Config.md3.scrim, 0.72)
    enabled: open
    opacity: open ? 1 : 0
    visible: open || opacity > 0
    z: 700

    Behavior on opacity {
        OpacityAnimator {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: open = true
    Keys.onEscapePressed: {
        if (browseControls.openMenu !== "")
            browseControls.closePopup();
        else
            root.closePanel();
    }
    onOpenChanged: {
        if (!open)
            return;

        if (collectionsMode) {
            WallhavenService.loadCollections(false);
        } else if (installedMode) {
            WallhavenService.loadInstalled(true);
        } else {
            wallhavenSearch.focusInput();
            if (WallhavenService.results.count === 0 && !WallhavenService.searching)
                performSearch(1);
        }
    }

    Connections {
        function onDownloadCompleted(wallpaperId, path, modified) {
            root.applyRequested(path, modified);
        }

        target: WallhavenService
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
    MouseArea {
        anchors.fill: parent

        onClicked: root.closePanel()
    }
    Rectangle {
        id: browser

        anchors.centerIn: parent
        color: Config.alpha(Config.md3.surface_container, 0.985)
        height: Math.min(parent.height - 64, 800)
        radius: 28
        scale: root.open ? 1 : 0.975
        width: Math.min(parent.width - 64, 1200)

        Behavior on scale {
            ScaleAnimator {
                duration: 210
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: mouse => {
                return mouse.accepted = true;
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 20
            color: closeMouse.containsMouse ? Config.md3.surface_container_highest : Config.alpha(Config.md3.on_surface, 0.055)
            height: 40
            radius: 14
            width: 40
            z: 20

            IconImage {
                anchors.centerIn: parent
                height: 15
                layer.enabled: true
                source: Quickshell.iconPath("window-close-symbolic")
                width: 15

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
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 48
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
                        source: Quickshell.iconPath("preferences-desktop-wallpaper-symbolic", "image-x-generic-symbolic")
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
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        text: qsTr("Wallhaven")
                    }
                    Text {
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 13
                        text: root.installedMode ? qsTr("Manage wallpapers saved on this device") : (root.collectionsMode ? qsTr("Your synced wallpaper collections") : qsTr("Discover high-resolution static wallpapers"))
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.maximumHeight: 42
                Layout.minimumHeight: 42
                Layout.preferredHeight: 42
                spacing: 12

                Rectangle {
                    id: primaryTabs

                    readonly property int selectedIndex: root.activeTab === "browse" ? 0 : (root.activeTab === "collections" ? 1 : 2)

                    Layout.preferredHeight: 42
                    Layout.preferredWidth: 330
                    color: Config.alpha(Config.md3.on_surface, 0.045)
                    radius: 14

                    Rectangle {
                        id: primaryTabIndicator

                        color: Config.md3.primary_container
                        height: parent.height - 8
                        radius: 11
                        width: (parent.width - 12) / 3
                        x: 4 + primaryTabs.selectedIndex * (width + 2)
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
                        spacing: 2

                        Repeater {
                            model: [
                                {
                                    "icon": "system-search-symbolic",
                                    "label": qsTr("Browse"),
                                    "value": "browse"
                                },
                                {
                                    "icon": "folder-symbolic",
                                    "label": qsTr("Collections"),
                                    "value": "collections"
                                },
                                {
                                    "icon": "folder-download-symbolic",
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
                                color: !selected && tabMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : "transparent"
                                radius: 11

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 15
                                        layer.enabled: true
                                        source: Quickshell.iconPath(tabChip.modelData.icon)
                                        width: 15

                                        layer.effect: ColorOverlay {
                                            color: tabChip.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: tabChip.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                                        font.family: Config.fontName
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        text: tabChip.modelData.label
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
                WallhavenSearchBar {
                    id: wallhavenSearch

                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.minimumWidth: 280
                    Layout.preferredHeight: 42
                    visible: root.activeTab === "browse"

                    onAccepted: root.performSearch(1, false)
                }
                Item {
                    Layout.fillWidth: true
                    visible: root.activeTab !== "browse"
                }
                Rectangle {
                    Layout.preferredHeight: 42
                    Layout.preferredWidth: installedRefreshRow.implicitWidth + 20
                    color: installedRefreshMouse.containsMouse ? Config.md3.secondary_container : Config.alpha(Config.md3.on_surface, 0.06)
                    enabled: !WallhavenService.listingInstalled
                    opacity: enabled ? 1 : 0.65
                    radius: 13
                    visible: root.installedMode

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Row {
                        id: installedRefreshRow

                        anchors.centerIn: parent
                        spacing: 7

                        LoadingIndicator {
                            anchors.verticalCenter: parent.verticalCenter
                            animated: WallhavenService.listingInstalled
                            height: 16
                            visible: animated
                            width: 16
                        }
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 16
                            layer.enabled: true
                            source: Quickshell.iconPath("view-refresh-symbolic")
                            visible: !WallhavenService.listingInstalled
                            width: 16

                            layer.effect: ColorOverlay {
                                color: installedRefreshMouse.containsMouse ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            color: installedRefreshMouse.containsMouse ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: qsTr("%1 installed").arg(WallhavenService.installedResults.count)
                        }
                    }
                    MouseArea {
                        id: installedRefreshMouse

                        anchors.fill: parent
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: parent.enabled
                        hoverEnabled: true

                        onClicked: WallhavenService.loadInstalled(true)
                    }
                }
            }
            WallhavenBrowseControls {
                id: browseControls

                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                visible: root.activeTab === "browse"

                onSearchRequested: root.performSearch(1, false)
            }
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                clip: true
                contentWidth: collectionRow.implicitWidth
                interactive: contentWidth > width
                visible: root.collectionsMode && WallhavenService.accountConfigured && WallhavenService.collections.count > 0

                Row {
                    id: collectionRow

                    spacing: 7

                    Repeater {
                        model: WallhavenService.collections

                        delegate: Rectangle {
                            required property var model

                            color: WallhavenService.selectedCollectionId === String(model.id || "") ? Config.md3.secondary_container : Config.alpha(Config.md3.on_surface, 0.055)
                            height: 38
                            radius: 12
                            width: collectionLabel.implicitWidth + 26

                            Text {
                                id: collectionLabel

                                anchors.centerIn: parent
                                color: WallhavenService.selectedCollectionId === String(parent.model.id || "") ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                                font.family: Config.fontName
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                text: qsTr("%1 · %2").arg(String(parent.model.label || qsTr("Collection"))).arg(Number(parent.model.count || 0))
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: root.selectCollection(parent.model)
                            }
                        }
                    }
                }
            }
            Item {
                id: animatedContent

                Layout.fillHeight: true
                Layout.fillWidth: true

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root.collectionsMode && !WallhavenService.accountConfigured
                    width: Math.min(parent.width - 40, 540)

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 50
                        layer.enabled: true
                        source: Quickshell.iconPath("dialog-password-symbolic")
                        width: 50

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
                        text: qsTr("Connect your Wallhaven account")
                        width: parent.width
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Add your username and API key in Settings → Integrations → Wallhaven")
                        width: parent.width
                        wrapMode: Text.Wrap
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: settingsMouse.containsMouse ? Config.md3.primary : Config.md3.primary_container
                        height: 40
                        radius: 13
                        width: settingsLabel.implicitWidth + 26

                        Text {
                            id: settingsLabel

                            anchors.centerIn: parent
                            color: settingsMouse.containsMouse ? Config.md3.on_primary : Config.md3.on_primary_container
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: qsTr("Open Settings")
                        }
                        MouseArea {
                            id: settingsMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: {
                                root.closePanel();
                                StateManager.showSettingsHub();
                            }
                        }
                    }
                }
                LoadingIndicator {
                    anchors.centerIn: parent
                    animated: root.resultLoading
                    visible: animated
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !root.resultLoading && root.resultError !== "" && !(root.collectionsMode && !WallhavenService.accountConfigured)
                    width: Math.min(parent.width - 40, 620)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Config.md3.error
                        font.family: Config.fontName
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        text: root.resultError
                        width: parent.width
                        wrapMode: Text.Wrap
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: !root.resultLoading && root.resultError === "" && root.resultModel.count === 0 && !(root.collectionsMode && !WallhavenService.accountConfigured)

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 42
                        layer.enabled: true
                        source: Quickshell.iconPath(root.installedMode ? "folder-download-symbolic" : (root.collectionsMode ? "folder-symbolic" : "system-search-symbolic"))
                        width: 42

                        layer.effect: ColorOverlay {
                            color: Config.md3.primary
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        text: root.installedMode ? qsTr("No installed Wallhaven wallpapers") : (root.collectionsMode ? qsTr("This collection is empty") : qsTr("No wallpapers found"))
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 12
                        text: root.installedMode ? qsTr("Downloaded wallpapers will appear here") : (root.collectionsMode ? qsTr("Choose another collection or refresh") : qsTr("Try another query or resolution filter"))
                    }
                }
                GridView {
                    id: resultGrid

                    anchors.fill: parent
                    cacheBuffer: cellHeight
                    cellHeight: cellWidth * 0.76
                    cellWidth: width / root.gridColumns
                    clip: true
                    model: root.resultModel
                    reuseItems: false
                    visible: !root.resultLoading && root.resultError === "" && count > 0

                    delegate: WallhavenCard {
                        required property var model

                        blurNsfw: !root.nsfwVisible
                        cancelling: WallhavenService.downloadCancelRequested && WallhavenService.downloadingId === String(model.id || "")
                        deleteArmed: root.deleteArmedId === String(model.id || "")
                        downloadBlocked: WallhavenService.downloading && WallhavenService.downloadingId !== String(model.id || "")
                        downloading: WallhavenService.downloadingId === String(model.id || "")
                        height: resultGrid.cellHeight
                        inUse: String(WallpaperService.currentWallpaper || "") === String(model.path || "")
                        installedMode: root.installedMode
                        removing: WallhavenService.removingId === String(model.id || "")
                        wallpaper: model
                        width: resultGrid.cellWidth

                        onApplyRequested: (path, modified) => {
                            return root.applyRequested(path, modified);
                        }
                        onArmDeleteRequested: wallpaperId => {
                            root.deleteArmedId = wallpaperId;
                            deleteArmTimer.restart();
                        }
                        onCancelDownloadRequested: WallhavenService.cancelDownload()
                        onDeleteRequested: item => {
                            root.deleteArmedId = "";
                            deleteArmTimer.stop();
                            WallhavenService.removeInstalled(item);
                        }
                        onDownloadRequested: item => {
                            return WallhavenService.download(item);
                        }
                        onOpenRequested: url => {
                            return WallhavenService.openPage(url);
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    color: root.resultError !== "" || root.actionError !== "" ? Config.md3.error : Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.actionError || root.resultError || (root.installedMode ? WallhavenService.installedStatusMessage : WallhavenService.statusMessage)
                }
                Rectangle {
                    Accessible.name: qsTr("Previous page")
                    Accessible.role: Accessible.Button
                    activeFocusOnTab: visible && enabled
                    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.68) : "transparent"
                    border.width: 1
                    color: previousMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                    enabled: root.collectionsMode ? WallhavenService.collectionPage > 1 : WallhavenService.page > 1
                    height: 36
                    opacity: enabled ? 1 : 0.35
                    radius: 12
                    visible: !root.installedMode && !root.resultLoading && root.resultModel.count > 0
                    width: 36

                    Keys.onReturnPressed: root.goToPreviousPage()
                    Keys.onSpacePressed: root.goToPreviousPage()

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.on_surface
                        font.pixelSize: 18
                        text: "‹"
                    }
                    MouseArea {
                        id: previousMouse

                        anchors.fill: parent
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: parent.enabled
                        hoverEnabled: true

                        onClicked: root.goToPreviousPage()
                    }
                }
                Rectangle {
                    color: Config.alpha(Config.md3.on_surface, 0.045)
                    height: 36
                    radius: 12
                    visible: !root.installedMode && !root.resultLoading && root.resultModel.count > 0
                    width: pageLabel.implicitWidth + 20

                    Text {
                        id: pageLabel

                        anchors.centerIn: parent
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: root.collectionsMode ? qsTr("%1 / %2").arg(WallhavenService.collectionPage).arg(WallhavenService.collectionLastPage) : qsTr("%1 / %2").arg(WallhavenService.page).arg(WallhavenService.lastPage)
                    }
                }
                Rectangle {
                    Accessible.name: qsTr("Next page")
                    Accessible.role: Accessible.Button
                    activeFocusOnTab: visible && enabled
                    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.68) : "transparent"
                    border.width: 1
                    color: nextMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : Config.alpha(Config.md3.on_surface, 0.06)
                    enabled: root.collectionsMode ? WallhavenService.collectionPage < WallhavenService.collectionLastPage : WallhavenService.page < WallhavenService.lastPage
                    height: 36
                    opacity: enabled ? 1 : 0.35
                    radius: 12
                    visible: !root.installedMode && !root.resultLoading && root.resultModel.count > 0
                    width: 36

                    Keys.onReturnPressed: root.goToNextPage()
                    Keys.onSpacePressed: root.goToNextPage()

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.on_surface
                        font.pixelSize: 18
                        text: "›"
                    }
                    MouseArea {
                        id: nextMouse

                        anchors.fill: parent
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: parent.enabled
                        hoverEnabled: true

                        onClicked: root.goToNextPage()
                    }
                }
            }
            ParallelAnimation {
                id: contentTransition

                OpacityAnimator {
                    duration: 170
                    easing.type: Easing.OutCubic
                    from: 0
                    target: animatedContent
                    to: 1
                }
                XAnimator {
                    duration: 210
                    easing.type: Easing.OutCubic
                    from: root.contentTransitionDirection * 16
                    target: animatedContent
                    to: 0
                }
            }
        }
    }
}
