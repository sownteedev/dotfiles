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

    readonly property string actionError: GreeterBackgroundService.errorMessage || (installedMode ? WallhavenService.removeErrorMessage : WallhavenService.downloadErrorMessage)
    property string activeTab: "browse"
    readonly property bool collectionsMode: activeTab === "collections"
    property int contentTransitionDirection: 1
    property string deleteArmedId: ""
    readonly property string footerStatus: actionError || resultError || GreeterBackgroundService.statusMessage || (installedMode ? WallhavenService.installedStatusMessage : WallhavenService.statusMessage)
    readonly property int gridColumns: Math.max(1, Math.min(4, Math.floor((browser.width - 56) / 250)))
    readonly property bool installedMode: activeTab === "installed"
    readonly property bool nsfwVisible: Config.wallhavenApiKey.trim() !== "" && Config.wallhavenShowNsfw
    property bool open: false
    readonly property string resultError: installedMode ? WallhavenService.installedErrorMessage : (collectionsMode ? WallhavenService.collectionErrorMessage : WallhavenService.searchErrorMessage)
    readonly property bool resultHasItems: resultModel.count > 0
    readonly property bool resultInitialLoading: resultLoading && !resultHasItems
    readonly property bool resultLoading: installedMode ? WallhavenService.listingInstalled : (collectionsMode ? WallhavenService.loadingCollection || WallhavenService.loadingCollections : WallhavenService.searching)
    readonly property var resultModel: installedMode ? WallhavenService.installedResults : (collectionsMode ? WallhavenService.collectionResults : WallhavenService.results)

    signal applyRequested(string path, var modified)
    signal closeRequested

    function applyDestination(item, destination) {
        var target = String(destination || "desktop");
        var path = String(item.path || "");
        if (path === "") {
            WallhavenService.download(item, target);
            return;
        }
        if (target === "desktop" || target === "both")
            root.applyRequested(path, item.modified || 0);
        if (target === "greetd" || target === "both")
            GreeterBackgroundService.setImage(path);
    }
    function closePanel() {
        if (!open)
            return;

        wallhavenFilters.closePopup();
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
    function positionResultViewAtBeginning() {
        resultGrid.cancelFlick();
        resultGrid.currentIndex = -1;
        resultGrid.forceLayout();
        resultGrid.positionViewAtBeginning();
        resultGrid.contentY = resultGrid.originY;
    }
    function resetResultView() {
        positionResultViewAtBeginning();
        resultViewResetTimer.restart();
    }
    function selectCollection(item) {
        if (!item)
            return;

        resetResultView();
        WallhavenService.loadCollection(String(item.id || ""), String(item.label || ""), 1);
    }
    function selectTab(tab) {
        if (tab === "installed" && wallhavenFilters.activeFilterCount > 0)
            wallhavenFilters.resetFilters();
        if (activeTab === tab) {
            resetResultView();
            if (tab === "collections")
                WallhavenService.loadCollections(true);
            else if (tab === "installed")
                WallhavenService.loadInstalled(true);
            return;
        }
        contentTransition.stop();
        wallhavenFilters.closePopup();
        var oldIndex = activeTab === "browse" ? 0 : (activeTab === "collections" ? 1 : 2);
        var newIndex = tab === "browse" ? 0 : (tab === "collections" ? 1 : 2);
        contentTransitionDirection = newIndex > oldIndex ? 1 : -1;
        activeTab = tab;
        deleteArmedId = "";
        resetResultView();
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
    function setNsfwVisible(enabled) {
        if (Config.wallhavenShowNsfw === enabled)
            return;
        Config.wallhavenShowNsfw = enabled;
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

    Component.onCompleted: {
        WallhavenService.acquirePanel();
        open = true;
    }
    Component.onDestruction: WallhavenService.releasePanel()
    Keys.onEscapePressed: {
        if (wallhavenFilters.popupOpen)
            wallhavenFilters.closePopup();
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
        function onCollectionPageChanged() {
            if (root.collectionsMode)
                root.positionResultViewAtBeginning();
        }
        function onDownloadCompleted(wallpaperId, path, modified, purpose) {
            if (purpose === "greetd")
                return;
            root.applyRequested(path, modified);
        }
        function onPageChanged() {
            if (!root.collectionsMode && !root.installedMode)
                root.positionResultViewAtBeginning();
        }

        target: WallhavenService
    }
    Timer {
        id: resultViewResetTimer

        interval: 0
        repeat: false

        onTriggered: root.positionResultViewAtBeginning()
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
    ShellShadow {
        cornerRadius: browser.radius
        scale: browser.scale
        target: browser
    }
    Rectangle {
        id: browser

        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.outline_variant, 0.34)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container_low, 0.98)
        height: Math.min(parent.height - 40, 920)
        radius: Md3.shape.extraLarge
        scale: root.open ? 1 : 0.975
        width: Math.min(parent.width - 40, 1500)

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
            anchors.rightMargin: 28
            anchors.top: parent.top
            anchors.topMargin: 28
            color: closeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : Config.alpha(Config.md3.on_surface, 0.05)
            height: 40
            radius: Md3.shape.full
            width: 40
            z: 20

            Behavior on color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short2)
                }
            }

            Md3Icon {
                anchors.centerIn: parent
                color: Config.md3.on_surface_variant
                name: "window-close-symbolic"
                size: 18
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
            anchors.margins: Md3.spacing.xl
            spacing: Md3.spacing.md

            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 50
                spacing: 14

                Rectangle {
                    Layout.preferredHeight: 52
                    Layout.preferredWidth: 52
                    color: Config.md3.primary_container
                    radius: Md3.shape.largeIncreased

                    Md3Icon {
                        anchors.centerIn: parent
                        color: Config.md3.on_primary_container
                        name: "preferences-desktop-wallpaper-symbolic"
                        size: 25
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 24
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
                Layout.maximumHeight: 40
                Layout.minimumHeight: 40
                Layout.preferredHeight: 40
                spacing: 8

                Rectangle {
                    id: primaryTabs

                    readonly property int selectedIndex: root.activeTab === "browse" ? 0 : (root.activeTab === "collections" ? 1 : 2)

                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 390
                    border.color: Config.alpha(Config.md3.outline, 0.08)
                    border.width: 1
                    color: Config.alpha(Config.md3.on_surface, 0.03)
                    radius: Md3.shape.full

                    Rectangle {
                        id: primaryTabIndicator

                        color: Config.md3.primary_container
                        height: parent.height - 8
                        radius: Md3.shape.full
                        width: (parent.width - 8 - 12) / 3
                        x: 4 + primaryTabs.selectedIndex * (width + 6)
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
                        spacing: 6

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
                                radius: Md3.shape.full

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

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
                    Layout.preferredHeight: 40
                    visible: root.activeTab === "browse"

                    onAccepted: root.performSearch(1, false)
                }
                WallhavenFilters {
                    id: wallhavenFilters

                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 40
                    popupParent: browser
                    visible: root.activeTab === "browse"

                    onSearchRequested: {
                        root.resetResultView();
                        root.performSearch(1, false);
                    }
                }
                Rectangle {
                    readonly property bool nsfwAvailable: wallhavenFilters.bitEnabled(WallhavenService.purity, 2)

                    Accessible.name: Config.wallhavenShowNsfw ? qsTr("Blur NSFW Wallhaven previews") : qsTr("Show NSFW Wallhaven previews")
                    Accessible.role: Accessible.Button
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: 40
                    activeFocusOnTab: false
                    border.color: Config.alpha(Config.wallhavenShowNsfw ? Config.md3.error : Config.md3.outline, 0.22)
                    border.width: 1
                    color: Config.wallhavenShowNsfw ? Config.md3.error_container : (nsfwMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.035))
                    enabled: nsfwAvailable
                    opacity: enabled ? 1 : 0.38
                    radius: Md3.shape.full
                    visible: root.activeTab === "browse" && Config.wallhavenApiKey.trim() !== ""

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

                    Keys.onReturnPressed: root.setNsfwVisible(!Config.wallhavenShowNsfw)
                    Keys.onSpacePressed: root.setNsfwVisible(!Config.wallhavenShowNsfw)

                    Md3Icon {
                        anchors.centerIn: parent
                        color: Config.wallhavenShowNsfw ? Config.md3.on_error_container : Config.md3.on_surface_variant
                        name: Config.wallhavenShowNsfw ? "view-reveal-symbolic" : "view-conceal-symbolic"
                        size: 20
                    }
                    MouseArea {
                        id: nsfwMouse

                        anchors.fill: parent
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: parent.enabled
                        hoverEnabled: true

                        onClicked: root.setNsfwVisible(!Config.wallhavenShowNsfw)
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6
                    visible: !root.installedMode && root.resultHasItems

                    Rectangle {
                        Accessible.name: qsTr("Previous page")
                        Accessible.role: Accessible.Button
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        activeFocusOnTab: false
                        border.color: "transparent"
                        border.width: 0
                        color: previousMouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : Config.alpha(Config.md3.on_surface, 0.05)
                        enabled: !root.resultLoading && (root.collectionsMode ? WallhavenService.collectionPage > 1 : WallhavenService.page > 1)
                        opacity: enabled ? 1 : 0.35
                        radius: Md3.shape.full

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(Md3.motion.short2)
                            }
                        }

                        Keys.onReturnPressed: root.goToPreviousPage()
                        Keys.onSpacePressed: root.goToPreviousPage()

                        Md3Icon {
                            anchors.centerIn: parent
                            color: Config.md3.on_surface_variant
                            name: "go-previous-symbolic"
                            size: 18
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
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: pageLabel.implicitWidth + 24
                        color: Config.alpha(Config.md3.on_surface, 0.05)
                        radius: Md3.shape.full

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
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        activeFocusOnTab: false
                        border.color: "transparent"
                        border.width: 0
                        color: nextMouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : Config.alpha(Config.md3.on_surface, 0.05)
                        enabled: !root.resultLoading && (root.collectionsMode ? WallhavenService.collectionPage < WallhavenService.collectionLastPage : WallhavenService.page < WallhavenService.lastPage)
                        opacity: enabled ? 1 : 0.35
                        radius: Md3.shape.full

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(Md3.motion.short2)
                            }
                        }

                        Keys.onReturnPressed: root.goToNextPage()
                        Keys.onSpacePressed: root.goToNextPage()

                        Md3Icon {
                            anchors.centerIn: parent
                            color: Config.md3.on_surface_variant
                            name: "go-next-symbolic"
                            size: 18
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
                Item {
                    Layout.fillWidth: true
                    visible: root.activeTab !== "browse"
                }
                Rectangle {
                    readonly property int count: root.collectionsMode ? WallhavenService.collectionTotalResults : WallhavenService.installedResults.count

                    Accessible.name: root.collectionsMode ? qsTr("%1 wallpapers in the selected collection").arg(count) : qsTr("%1 installed wallpapers").arg(count)
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: Math.max(28, collectionCountLabel.implicitWidth + 14)
                    color: Config.md3.primary_container
                    radius: Md3.shape.full
                    visible: root.collectionsMode || root.installedMode

                    Text {
                        id: collectionCountLabel

                        anchors.centerIn: parent
                        color: Config.md3.on_primary_container
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        text: String(parent.count)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.maximumHeight: 34
                Layout.minimumHeight: 34
                Layout.preferredHeight: 34
                spacing: 10
                visible: root.collectionsMode && WallhavenService.accountConfigured && WallhavenService.collections.count > 1

                Flickable {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.maximumHeight: 32
                    Layout.minimumHeight: 32
                    Layout.preferredHeight: 32
                    clip: true
                    contentHeight: height
                    contentWidth: collectionRow.implicitWidth
                    interactive: contentWidth > width

                    Row {
                        id: collectionRow

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: WallhavenService.collections

                            delegate: Rectangle {
                                id: collectionChip

                                required property var model
                                readonly property bool selected: WallhavenService.selectedCollectionId === String(model.id || "")

                                Accessible.name: qsTr("Open collection %1").arg(String(model.label || qsTr("Collection")))
                                Accessible.role: Accessible.Button
                                activeFocusOnTab: false
                                border.color: selected ? Config.alpha(Config.md3.secondary, 0.34) : collectionMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.34) : Config.alpha(Config.md3.outline, 0.12)
                                border.width: 1
                                color: selected ? Config.md3.secondary_container : (collectionMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : Config.alpha(Config.md3.on_surface, 0.045))
                                height: 30
                                radius: Md3.shape.full
                                width: collectionChipContent.implicitWidth + 20

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Keys.onReturnPressed: root.selectCollection(collectionChip.model)
                                Keys.onSpacePressed: root.selectCollection(collectionChip.model)

                                Row {
                                    id: collectionChipContent

                                    anchors.centerIn: parent
                                    spacing: 8

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 15
                                        layer.enabled: true
                                        source: Quickshell.iconPath(collectionChip.selected ? "folder-open-symbolic" : "folder-symbolic")
                                        width: 15

                                        layer.effect: ColorOverlay {
                                            color: collectionChip.selected ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: collectionChip.selected ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                                        font.family: Config.fontName
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        text: String(collectionChip.model.label || qsTr("Collection"))
                                    }
                                }
                                MouseArea {
                                    id: collectionMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: root.selectCollection(collectionChip.model)
                                }
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
                        radius: Md3.shape.full
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
                    animated: root.resultInitialLoading
                    height: 80
                    visible: animated
                    width: 80
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !root.resultInitialLoading && !root.resultHasItems && root.resultError !== "" && !(root.collectionsMode && !WallhavenService.accountConfigured)
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
                    visible: !root.resultInitialLoading && !root.resultHasItems && root.resultError === "" && !(root.collectionsMode && !WallhavenService.accountConfigured) && (root.installedMode || root.collectionsMode || WallhavenService.query !== "")

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
                    cellHeight: cellWidth * 0.67
                    cellWidth: width / root.gridColumns
                    clip: true
                    model: root.resultModel
                    reuseItems: false
                    visible: root.resultHasItems

                    delegate: WallhavenCard {
                        required property var model

                        blurNsfw: !root.nsfwVisible
                        cancelling: WallhavenService.downloadCancelRequested && WallhavenService.downloadingId === String(model.id || "")
                        deleteArmed: root.deleteArmedId === String(model.id || "")
                        downloadBlocked: WallhavenService.downloading && WallhavenService.downloadingId !== String(model.id || "")
                        downloading: WallhavenService.downloadingId === String(model.id || "")
                        greetdBusy: GreeterBackgroundService.busy
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
                        onDestinationRequested: (item, destination) => root.applyDestination(item, destination)
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
                visible: root.footerStatus !== ""

                Text {
                    Layout.fillWidth: true
                    color: root.resultError !== "" || root.actionError !== "" ? Config.md3.error : Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.footerStatus
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
