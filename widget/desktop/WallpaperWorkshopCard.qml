import "../../"
import "../../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property bool blurNsfw: false
    property bool cancelling: false
    property bool deleteArmed: false
    property bool downloadBlocked: false
    readonly property bool downloaded: installedMode || Boolean(wallpaper.downloaded)
    property bool downloading: false
    readonly property real fileSizeBytes: Number(wallpaper.file_size || 0)
    readonly property string fileSizeLabel: formatFileSize(fileSizeBytes)
    property bool greetdBusy: false
    readonly property bool greetdEligible: String(wallpaper.type || "").toLowerCase() === "video"
    property bool inUse: false
    property bool installedMode: false
    readonly property string itemId: String(wallpaper.id || "")
    readonly property string itemPath: String(wallpaper.path || "")
    readonly property bool nsfw: Boolean(wallpaper.nsfw)
    readonly property bool nsfwBlurred: nsfw && blurNsfw
    property bool removing: false
    readonly property string resolutionLabel: String(wallpaper.resolution || "")
    readonly property bool subscribed: Boolean(wallpaper.subscribed)
    readonly property bool supported: installedMode ? !["web", "application"].includes(String(wallpaper.type || "").toLowerCase()) : wallpaper.supported !== false
    required property var wallpaper

    signal applyRequested(string path, var modified)
    signal armDeleteRequested(string publishedFileId)
    signal cancelDownloadRequested
    signal deleteRequested(var item)
    signal destinationRequested(var item, string destination)
    signal subscribeRequested(var item)

    function formatFileSize(bytes) {
        var size = Number(bytes || 0);
        if (!isFinite(size) || size <= 0)
            return "";
        var units = [qsTr("B"), qsTr("KiB"), qsTr("MiB"), qsTr("GiB")];
        var unitIndex = 0;
        while (size >= 1024 && unitIndex < units.length - 1) {
            size /= 1024;
            ++unitIndex;
        }
        var decimals = unitIndex === 0 || size >= 100 ? 0 : 1;
        return size.toLocaleString(Qt.locale(), "f", decimals) + " " + units[unitIndex];
    }
    function triggerPrimaryAction() {
        destinationPopup.openFor(primaryAction);
    }

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.margins: 8
        border.color: cardMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.42) : Config.alpha(Config.md3.outline, 0.12)
        border.width: 1
        color: cardMouse.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container_low
        radius: 20

        Behavior on border.color {
            ColorAnimation {
                duration: 130
            }
        }

        Rectangle {
            id: previewSurface

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            color: Config.alpha(Config.md3.surface, 0.55)
            height: parent.height - 56
            radius: 20
            z: 2

            Image {
                id: previewImage

                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                layer.enabled: root.nsfwBlurred
                source: root.wallpaper.preview || ""
                sourceSize.height: 320
                sourceSize.width: 520

                layer.effect: FastBlur {
                    radius: root.nsfwBlurred ? 42 : 0
                    transparentBorder: false

                    Behavior on radius {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
            LoadingIndicator {
                anchors.centerIn: parent
                animated: previewImage.status === Image.Loading
                color: Config.md3.primary
                visible: animated && !root.nsfwBlurred
                z: 3
            }
            IconImage {
                anchors.centerIn: parent
                height: 34
                layer.enabled: true
                source: Quickshell.iconPath("image-missing-symbolic")
                visible: previewImage.status === Image.Error && !root.nsfwBlurred
                width: 34
                z: 3

                layer.effect: ColorOverlay {
                    color: Config.md3.on_surface_variant
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 20

                gradient: Gradient {
                    GradientStop {
                        color: "transparent"
                        position: 0.48
                    }
                    GradientStop {
                        color: Config.alpha(Config.md3.surface_container_low, 0.92)
                        position: 1
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                color: Config.alpha(Config.md3.surface, 0.82)
                height: 36
                opacity: root.nsfwBlurred ? 1 : 0
                radius: 12
                visible: root.nsfw && opacity > 0
                width: nsfwLabelRow.implicitWidth + 24
                z: 3

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    id: nsfwLabelRow

                    anchors.centerIn: parent
                    spacing: 7

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 16
                        layer.enabled: true
                        source: Quickshell.iconPath("view-conceal-symbolic")
                        width: 16

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        text: qsTr("NSFW")
                    }
                }
            }
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 7

                Rectangle {
                    color: Config.alpha(Config.md3.surface, 0.84)
                    height: 28
                    radius: 10
                    width: typeLabel.implicitWidth + 18

                    Text {
                        id: typeLabel

                        anchors.centerIn: parent
                        color: root.supported ? Config.md3.on_surface : Config.md3.error
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        text: String(root.wallpaper.type || "unknown").toUpperCase()
                    }
                }
                Rectangle {
                    color: root.inUse ? Config.md3.primary_container : Config.md3.secondary_container
                    height: 27
                    radius: 10
                    visible: root.inUse || root.subscribed || (!root.installedMode && root.downloaded)
                    width: stateLabel.implicitWidth + 18

                    Text {
                        id: stateLabel

                        anchors.centerIn: parent
                        color: root.inUse ? Config.md3.on_primary_container : Config.md3.on_secondary_container
                        font.family: Config.fontName
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        text: root.inUse ? qsTr("IN USE") : root.subscribed ? qsTr("SUBSCRIBED") : qsTr("DOWNLOADED")
                    }
                }
            }
            Rectangle {
                id: steamAction

                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 10
                color: steamMouse.pressed ? Config.md3.primary_container : (steamMouse.containsMouse ? Config.alpha(Config.md3.surface, 0.96) : Config.alpha(Config.md3.surface, 0.86))
                height: 32
                radius: 11
                width: steamActionRow.implicitWidth + 20
                z: 4

                Row {
                    id: steamActionRow

                    anchors.centerIn: parent
                    spacing: 7

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 16
                        layer.enabled: true
                        source: Quickshell.iconPath("steam-symbolic")
                        width: 16

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        text: root.subscribed ? qsTr("Manage") : qsTr("Subscribe")
                    }
                }
                MouseArea {
                    id: steamMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.subscribeRequested(root.wallpaper)
                }
            }
            Rectangle {
                id: resolutionBadge

                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 10
                color: Config.alpha(Config.md3.surface, 0.88)
                height: 28
                radius: 10
                visible: root.resolutionLabel !== ""
                width: resolutionRow.implicitWidth + 18
                z: 4

                Row {
                    id: resolutionRow

                    anchors.centerIn: parent
                    spacing: 6

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 15
                        layer.enabled: true
                        source: Quickshell.iconPath("video-display-symbolic")
                        width: 15

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface_variant
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        text: root.resolutionLabel
                    }
                }
            }
            Rectangle {
                id: fileSizeBadge

                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                anchors.right: parent.right
                anchors.rightMargin: 10
                color: Config.alpha(Config.md3.surface, 0.88)
                height: 28
                radius: 10
                visible: root.fileSizeLabel !== ""
                width: fileSizeRow.implicitWidth + 18
                z: 4

                Row {
                    id: fileSizeRow

                    anchors.centerIn: parent
                    spacing: 6

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 15
                        layer.enabled: true
                        source: Quickshell.iconPath("drive-harddisk-symbolic")
                        width: 15

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface_variant
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        text: root.fileSizeLabel
                    }
                }
            }
        }
        RowLayout {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            spacing: 6
            z: 5

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                text: root.wallpaper.title || root.itemId
            }
            Rectangle {
                id: deleteAction

                Layout.preferredHeight: 36
                Layout.preferredWidth: 36
                color: deleteMouse.pressed ? Config.md3.error_container : (deleteMouse.containsMouse || root.deleteArmed ? Config.alpha(Config.md3.error_container, 0.96) : Config.alpha(Config.md3.on_surface, 0.055))
                radius: 12
                visible: root.installedMode && !root.inUse

                Row {
                    anchors.centerIn: parent

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18
                        layer.enabled: true
                        source: Quickshell.iconPath(root.deleteArmed ? "dialog-warning-symbolic" : "user-trash-symbolic")
                        width: 18

                        layer.effect: ColorOverlay {
                            color: root.deleteArmed ? Config.md3.on_error_container : Config.md3.on_surface_variant
                        }
                    }
                }
                MouseArea {
                    id: deleteMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        if (root.deleteArmed)
                            root.deleteRequested(root.wallpaper);
                        else
                            root.armDeleteRequested(root.itemId);
                    }
                }
            }
            Rectangle {
                id: primaryAction

                Accessible.name: qsTr("Choose wallpaper destination")
                Accessible.role: Accessible.Button
                Layout.preferredHeight: 36
                Layout.preferredWidth: 36
                activeFocusOnTab: true
                color: primaryMouse.pressed ? Config.md3.primary_container : (primaryMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.86) : Config.md3.primary)
                enabled: root.supported && !root.downloading && !root.removing && !root.downloadBlocked
                opacity: enabled ? 1 : 0.5
                radius: 12

                Keys.onReturnPressed: root.triggerPrimaryAction()
                Keys.onSpacePressed: root.triggerPrimaryAction()

                IconImage {
                    anchors.centerIn: parent
                    height: 18
                    layer.enabled: true
                    source: Quickshell.iconPath(root.downloaded ? "preferences-desktop-wallpaper-symbolic" : "folder-download-symbolic")
                    width: 18

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_primary
                    }
                }
                MouseArea {
                    id: primaryMouse

                    anchors.fill: parent
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.enabled
                    hoverEnabled: true

                    onClicked: root.triggerPrimaryAction()
                }
            }
        }
        MouseArea {
            id: cardMouse

            anchors.fill: parent
            cursorShape: root.supported && !root.downloading && !root.removing ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.supported && !root.downloading && !root.removing
            hoverEnabled: true
            z: 1

            onClicked: root.triggerPrimaryAction()
        }
        Rectangle {
            anchors.fill: parent
            color: Config.alpha(Config.md3.surface, 0.76)
            radius: 20
            visible: root.downloading || root.removing
            z: 6

            Column {
                anchors.centerIn: parent
                spacing: 10

                LoadingIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    animated: parent.parent.visible
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: root.removing ? qsTr("Deleting permanently…") : root.cancelling ? qsTr("Cancelling…") : qsTr("Downloading…")
                }
                Rectangle {
                    color: cancelMouse.pressed ? Config.md3.error_container : (cancelMouse.containsMouse ? Config.alpha(Config.md3.error_container, 0.92) : Config.alpha(Config.md3.on_surface, 0.07))
                    enabled: !root.cancelling
                    height: 40
                    opacity: enabled ? 1 : 0.55
                    radius: 13
                    visible: root.downloading
                    width: cancelRow.implicitWidth + 28

                    Row {
                        id: cancelRow

                        anchors.centerIn: parent
                        spacing: 7

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 17
                            layer.enabled: true
                            source: Quickshell.iconPath("process-stop-symbolic")
                            width: 17

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_error_container
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Config.md3.on_error_container
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: root.cancelling ? qsTr("Cancelling") : qsTr("Cancel")
                        }
                    }
                    MouseArea {
                        id: cancelMouse

                        anchors.fill: parent
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: parent.enabled
                        hoverEnabled: true

                        onClicked: root.cancelDownloadRequested()
                    }
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            border.color: card.border.color
            border.width: card.border.width
            color: "transparent"
            radius: card.radius
            z: 7
        }
    }
    WallpaperDestinationPopup {
        id: destinationPopup

        greetdAvailable: root.greetdEligible && !root.greetdBusy

        onDestinationSelected: destination => root.destinationRequested(root.wallpaper, destination)
    }
}
