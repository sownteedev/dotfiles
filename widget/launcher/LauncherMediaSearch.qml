import "../../"
import "../../components/animate" as Animate
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    readonly property int columnCount: width >= 430 ? 3 : 2
    property string mediaKind: "gif"
    property string query: ""
    readonly property var results: provider.results
    property int selectedIndex: -1

    signal resultLaunched

    function copyItem(item) {
        if (!item)
            return;
        var url = String(item.preferredUrl || "");
        var format = String(item.preferredFormat || "");
        if (url === "") {
            if (mediaKind === "gif") {
                url = String(item.gifUrl || item.webpUrl || item.pngUrl || "");
                format = item.gifUrl ? "gif" : item.webpUrl ? "webp" : "png";
            } else {
                url = String(item.webpUrl || item.gifUrl || item.pngUrl || "");
                format = item.webpUrl ? "webp" : item.gifUrl ? "gif" : "png";
            }
        }
        if (url === "")
            return;

        var mimeType = format === "gif" ? "image/gif" : format === "png" ? "image/png" : "image/webp";
        var command = ["python3", Config.quickshellDir + "/backend/python/launcher/klipy_client.py", "copy", "--url", url, "--mime", mimeType];
        if (Config.launcherClipboardAutoPaste)
            command.push("--paste");
        Quickshell.execDetached(command);
        resultLaunched();
    }
    function errorDescription() {
        switch (provider.errorCode) {
        case "missing_api_key":
            return qsTr("Add your KLIPY API key in Settings → Integrations.");
        case "invalid_api_key":
            return qsTr("The configured KLIPY API key was rejected.");
        case "rate_limited":
            return qsTr("The KLIPY request limit has been reached. Try again later.");
        case "offline":
            return qsTr("Connect to the internet and try again.");
        case "process_error":
            return qsTr("The media search helper could not be started.");
        default:
            return qsTr("KLIPY could not return media right now.");
        }
    }
    function errorTitle() {
        return provider.errorCode === "missing_api_key" ? qsTr("KLIPY setup required") : qsTr("Media search unavailable");
    }
    function launchSelected() {
        if (selectedIndex >= 0 && selectedIndex < results.length)
            copyItem(results[selectedIndex]);
    }
    function revealSelection() {
        if (selectedIndex >= 0)
            mediaGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }
    function selectDown() {
        setSelectedIndex(Math.min(results.length - 1, selectedIndex + columnCount));
    }
    function selectFirst() {
        setSelectedIndex(results.length > 0 ? 0 : -1);
    }
    function selectLast() {
        setSelectedIndex(results.length - 1);
    }
    function selectLeft() {
        setSelectedIndex(Math.max(0, selectedIndex - 1));
    }
    function selectNextPage() {
        setSelectedIndex(Math.min(results.length - 1, selectedIndex + columnCount * 3));
    }
    function selectPreviousPage() {
        setSelectedIndex(Math.max(0, selectedIndex - columnCount * 3));
    }
    function selectRight() {
        setSelectedIndex(Math.min(results.length - 1, selectedIndex + 1));
    }
    function selectUp() {
        setSelectedIndex(Math.max(0, selectedIndex - columnCount));
    }
    function setSelectedIndex(index) {
        if (results.length === 0) {
            selectedIndex = -1;
            return;
        }
        selectedIndex = Math.max(0, Math.min(index, results.length - 1));
        revealSelection();
    }
    function statusIcon() {
        if (provider.errorCode === "missing_api_key")
            return "dialog-password-symbolic";
        if (provider.errorCode === "offline")
            return "network-offline-symbolic";
        return "dialog-warning-symbolic";
    }

    implicitHeight: 448

    onResultsChanged: selectedIndex = results.length > 0 ? 0 : -1

    LauncherKlipyProvider {
        id: provider

        kind: root.mediaKind
        query: root.query
    }
    GridView {
        id: mediaGrid

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0
        cellHeight: root.columnCount === 3 ? 132 : 178
        cellWidth: width / root.columnCount
        currentIndex: root.selectedIndex
        flickDeceleration: 6000
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Config.animationDuration(180)
        model: root.results
        reuseItems: true
        visible: root.results.length > 0

        delegate: Item {
            id: mediaDelegate

            required property int index
            required property var modelData
            readonly property bool selected: index === root.selectedIndex

            Accessible.name: modelData.title
            Accessible.role: Accessible.Button
            height: GridView.view.cellHeight
            scale: pointer.containsMouse || selected ? 1.025 : 1
            width: GridView.view.cellWidth

            Behavior on scale {
                NumberAnimation {
                    duration: Config.animationDuration(150)
                    easing.type: Easing.OutCubic
                }
            }

            Accessible.onPressAction: root.copyItem(modelData)

            Rectangle {
                id: card

                anchors.fill: parent
                anchors.margins: 5
                border.color: mediaDelegate.selected ? Config.alpha(Config.md3.primary, 0.78) : pointer.containsMouse ? Config.alpha(Config.md3.outline, 0.5) : Config.alpha(Config.md3.outline_variant, 0.28)
                border.width: mediaDelegate.selected ? 2 : 1
                color: root.mediaKind === "sticker" ? Config.alpha(Config.md3.surface_container_high, 0.72) : Config.md3.surface_container
                radius: 18

                Behavior on border.color {
                    ColorAnimation {
                        duration: Config.animationDuration(140)
                    }
                }

                Image {
                    id: staticPreview

                    anchors.fill: parent
                    anchors.margins: card.border.width
                    asynchronous: true
                    cache: false
                    fillMode: root.mediaKind === "sticker" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    layer.enabled: status === Image.Ready
                    smooth: true
                    source: modelData.previewUrl
                    sourceSize: Qt.size(Math.max(1, card.width * 1.5), Math.max(1, card.height * 1.5))

                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            height: staticPreview.height
                            radius: Math.max(0, card.radius - card.border.width)
                            width: staticPreview.width
                        }
                    }
                }
                AnimatedImage {
                    id: animatedPreview

                    readonly property bool requested: (pointer.containsMouse || mediaDelegate.selected) && String(modelData.animatedUrl || "") !== ""

                    anchors.fill: parent
                    anchors.margins: card.border.width
                    asynchronous: true
                    cache: false
                    fillMode: root.mediaKind === "sticker" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    layer.enabled: visible
                    playing: visible
                    smooth: true
                    source: requested ? modelData.animatedUrl : ""
                    sourceSize: Qt.size(Math.max(1, card.width * 1.5), Math.max(1, card.height * 1.5))
                    visible: requested && status === AnimatedImage.Ready

                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            height: animatedPreview.height
                            radius: Math.max(0, card.radius - card.border.width)
                            width: animatedPreview.width
                        }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Config.alpha(Config.md3.surface_container_lowest, 0.86)
                    height: 28
                    radius: 14
                    visible: pointer.containsMouse || mediaDelegate.selected
                    width: Math.min(parent.width - 16, titleText.implicitWidth + 22)

                    Text {
                        id: titleText

                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 11
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.title
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        root.selectedIndex = index;
                        root.copyItem(modelData);
                    }
                    onEntered: root.selectedIndex = index
                }
            }
        }
    }
    Animate.LoadingIndicator {
        anchors.centerIn: parent
        animated: provider.loading && root.results.length === 0
        color: root.mediaKind === "sticker" ? Config.md3.secondary : Config.md3.primary
        height: 64
        visible: animated
        width: 64
    }
    Column {
        anchors.centerIn: parent
        spacing: 12
        visible: !provider.loading && provider.errorCode !== ""
        width: Math.min(parent.width - 48, 350)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.alpha(provider.errorCode === "missing_api_key" ? Config.md3.tertiary : Config.md3.error, 0.14)
            height: 58
            radius: 19
            width: 58

            IconImage {
                anchors.centerIn: parent
                height: 27
                layer.enabled: true
                source: Quickshell.iconPath(root.statusIcon())
                width: 27

                layer.effect: ColorOverlay {
                    color: provider.errorCode === "missing_api_key" ? Config.md3.tertiary : Config.md3.error
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 17
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            text: root.errorTitle()
            width: parent.width
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.alpha(Config.md3.on_surface_variant, 0.72)
            font.family: Config.fontName
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            text: root.errorDescription()
            width: parent.width
            wrapMode: Text.Wrap
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: !provider.loading && provider.errorCode === "" && root.results.length === 0

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 34
            layer.enabled: true
            source: Quickshell.iconPath(root.mediaKind === "gif" ? "applications-multimedia-symbolic" : "face-smile-symbolic")
            width: 34

            layer.effect: ColorOverlay {
                color: Config.md3.on_surface_variant
            }
        }
        Text {
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: 15
            font.weight: Font.Medium
            text: qsTr("No results found")
        }
    }
}
