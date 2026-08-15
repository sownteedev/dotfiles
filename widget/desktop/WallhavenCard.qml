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
    readonly property bool downloaded: installedMode || (Boolean(wallpaper.downloaded) && String(wallpaper.path || "") !== "")
    property bool downloading: false
    readonly property string fileSizeLabel: formatFileSize(Number(wallpaper.file_size || 0))
    property bool inUse: false
    property bool installedMode: false
    readonly property string itemId: String(wallpaper.id || "")
    readonly property bool nsfw: Boolean(wallpaper.nsfw)
    readonly property bool nsfwBlurred: nsfw && blurNsfw
    property bool removing: false
    required property var wallpaper

    signal applyRequested(string path, var modified)
    signal armDeleteRequested(string wallpaperId)
    signal cancelDownloadRequested
    signal deleteRequested(var item)
    signal downloadRequested(var item)
    signal openRequested(string url)

    function formatFileSize(bytes) {
        var size = Number(bytes || 0);
        if (!isFinite(size) || size <= 0)
            return "";

        var units = [qsTr("B"), qsTr("KiB"), qsTr("MiB"), qsTr("GiB")];
        var index = 0;
        while (size >= 1024 && index < units.length - 1) {
            size /= 1024;
            ++index;
        }
        return size.toLocaleString(Qt.locale(), "f", index === 0 || size >= 100 ? 0 : 1) + " " + units[index];
    }
    function triggerDeleteAction() {
        if (deleteArmed)
            deleteRequested(wallpaper);
        else
            armDeleteRequested(itemId);
    }
    function triggerPrimaryAction() {
        if (downloaded)
            applyRequested(String(wallpaper.path || ""), wallpaper.modified || 0);
        else if (downloading)
            cancelDownloadRequested();
        else
            downloadRequested(wallpaper);
    }

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.margins: 6
        color: cardHover.hovered ? Config.md3.surface_container_high : Config.md3.surface_container_low
        radius: 18
        scale: cardHover.hovered ? 1.008 : 1

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on scale {
            ScaleAnimator {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: previewSurface

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            color: Config.md3.surface_container
            height: parent.height - 66
            radius: 18

            Image {
                id: previewImage

                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                layer.enabled: root.nsfwBlurred
                source: String(root.wallpaper.preview || root.wallpaper.path || "")
                sourceSize: Qt.size(560, 360)

                layer.effect: FastBlur {
                    radius: 44
                    transparentBorder: false
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 18

                gradient: Gradient {
                    GradientStop {
                        color: Config.alpha(Config.md3.scrim, 0.08)
                        position: 0
                    }
                    GradientStop {
                        color: "transparent"
                        position: 0.48
                    }
                    GradientStop {
                        color: Config.alpha(Config.md3.scrim, 0.42)
                        position: 1
                    }
                }
            }
            LoadingIndicator {
                anchors.centerIn: parent
                animated: previewImage.status === Image.Loading
                visible: animated && !root.nsfwBlurred
            }
            IconImage {
                anchors.centerIn: parent
                height: 34
                layer.enabled: true
                source: Quickshell.iconPath("image-missing-symbolic")
                visible: previewImage.status === Image.Error
                width: 34

                layer.effect: ColorOverlay {
                    color: Config.md3.on_surface_variant
                }
            }
            Rectangle {
                anchors.centerIn: parent
                color: Config.alpha(Config.md3.surface, 0.88)
                height: 38
                radius: 13
                visible: root.nsfwBlurred
                width: nsfwRow.implicitWidth + 24

                Row {
                    id: nsfwRow

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
                        text: qsTr("NSFW blurred")
                    }
                }
            }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 7

                Rectangle {
                    color: Config.alpha(Config.md3.surface, 0.88)
                    height: 26
                    radius: 9
                    visible: String(root.wallpaper.resolution || "") !== ""
                    width: resolutionText.implicitWidth + 18

                    Text {
                        id: resolutionText

                        anchors.centerIn: parent
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        text: String(root.wallpaper.resolution || "")
                    }
                }
                Rectangle {
                    color: Config.alpha(Config.md3.surface, 0.88)
                    height: 26
                    radius: 9
                    visible: String(root.wallpaper.category || "") !== "" && String(root.wallpaper.category || "") !== "local"
                    width: categoryText.implicitWidth + 18

                    Text {
                        id: categoryText

                        anchors.centerIn: parent
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        text: String(root.wallpaper.category || "").toUpperCase()
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 10

                Rectangle {
                    color: root.inUse ? Config.md3.primary_container : Config.alpha(Config.md3.surface, 0.88)
                    height: 26
                    radius: 9
                    visible: root.inUse || root.downloaded
                    width: stateText.implicitWidth + 18

                    Text {
                        id: stateText

                        anchors.centerIn: parent
                        color: root.inUse ? Config.md3.on_primary_container : Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        text: root.inUse ? qsTr("IN USE") : qsTr("INSTALLED")
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                anchors.left: parent.left
                anchors.leftMargin: 10
                color: Config.alpha(Config.md3.surface, 0.88)
                height: 26
                radius: 9
                visible: root.fileSizeLabel !== ""
                width: sizeRow.implicitWidth + 18

                Row {
                    id: sizeRow

                    anchors.centerIn: parent
                    spacing: 6

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 14
                        layer.enabled: true
                        source: Quickshell.iconPath("drive-harddisk-symbolic")
                        width: 14

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
            anchors.bottomMargin: 9
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            spacing: 6

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: qsTr("wallhaven-%1").arg(root.itemId)
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 11
                    text: root.installedMode ? qsTr("Saved locally") : qsTr("%1 favorites").arg(Number(root.wallpaper.favorites || 0).toLocaleString(Qt.locale(), "f", 0))
                }
            }
            Rectangle {
                id: openAction

                Accessible.name: qsTr("Open on Wallhaven")
                Accessible.role: Accessible.Button
                Layout.preferredHeight: 34
                Layout.preferredWidth: 34
                activeFocusOnTab: visible
                border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.68) : "transparent"
                border.width: 1
                color: openMouse.pressed ? Config.md3.secondary_container : (openMouse.containsMouse ? Config.alpha(Config.md3.secondary_container, 0.72) : Config.alpha(Config.md3.on_surface, 0.06))
                radius: 11
                visible: String(root.wallpaper.url || "") !== ""

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Keys.onReturnPressed: root.openRequested(String(root.wallpaper.url || ""))
                Keys.onSpacePressed: root.openRequested(String(root.wallpaper.url || ""))

                IconImage {
                    anchors.centerIn: parent
                    height: 17
                    layer.enabled: true
                    source: Quickshell.iconPath("internet-web-browser-symbolic")
                    width: 17

                    layer.effect: ColorOverlay {
                        color: openMouse.containsMouse ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                    }
                }
                MouseArea {
                    id: openMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.openRequested(String(root.wallpaper.url || ""))
                }
            }
            Rectangle {
                id: deleteAction

                Accessible.name: root.deleteArmed ? qsTr("Confirm delete") : qsTr("Delete wallpaper")
                Accessible.role: Accessible.Button
                Layout.preferredHeight: 34
                Layout.preferredWidth: 72
                activeFocusOnTab: visible
                border.color: activeFocus ? Config.alpha(Config.md3.error, 0.68) : "transparent"
                border.width: 1
                color: deleteMouse.pressed ? Config.md3.error : (deleteMouse.containsMouse || root.deleteArmed ? Config.md3.error_container : Config.alpha(Config.md3.on_surface, 0.06))
                enabled: !root.removing
                opacity: enabled ? 1 : 0.5
                radius: 11
                visible: root.installedMode && !root.inUse

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Keys.onReturnPressed: root.triggerDeleteAction()
                Keys.onSpacePressed: root.triggerDeleteAction()

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    LoadingIndicator {
                        anchors.verticalCenter: parent.verticalCenter
                        animated: root.removing
                        height: 16
                        visible: animated
                        width: 16
                    }
                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 17
                        layer.enabled: true
                        source: Quickshell.iconPath(root.deleteArmed ? "dialog-warning-symbolic" : "user-trash-symbolic")
                        visible: !root.removing
                        width: 17

                        layer.effect: ColorOverlay {
                            color: deleteMouse.pressed ? Config.md3.on_error : (root.deleteArmed ? Config.md3.on_error_container : Config.md3.on_surface_variant)
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.on_error_container
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        text: root.deleteArmed ? qsTr("Confirm") : qsTr("Delete")
                        visible: !root.removing
                    }
                }
                MouseArea {
                    id: deleteMouse

                    anchors.fill: parent
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: parent.enabled
                    hoverEnabled: true

                    onClicked: root.triggerDeleteAction()
                }
            }
            Rectangle {
                id: primaryAction

                readonly property bool emphasized: primaryMouse.containsMouse || primaryMouse.pressed || activeFocus

                Accessible.name: root.downloaded ? qsTr("Apply wallpaper") : (root.downloading ? qsTr("Cancel download") : qsTr("Download wallpaper"))
                Accessible.role: Accessible.Button
                Layout.preferredHeight: 34
                Layout.preferredWidth: root.downloaded ? 38 : 96
                activeFocusOnTab: true
                border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.72) : "transparent"
                border.width: 1
                color: primaryMouse.pressed ? Config.md3.primary : (primaryAction.emphasized ? Config.alpha(Config.md3.primary, 0.9) : Config.md3.primary_container)
                enabled: !root.inUse && !root.removing && !root.downloadBlocked && (!root.cancelling || root.downloading)
                opacity: enabled ? 1 : 0.42
                radius: 11

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Keys.onReturnPressed: root.triggerPrimaryAction()
                Keys.onSpacePressed: root.triggerPrimaryAction()

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    LoadingIndicator {
                        anchors.verticalCenter: parent.verticalCenter
                        animated: root.downloading && !root.cancelling
                        height: 16
                        visible: animated
                        width: 16
                    }
                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 17
                        layer.enabled: true
                        source: Quickshell.iconPath(root.downloaded ? "media-playback-start-symbolic" : root.downloading ? "process-stop-symbolic" : "folder-download-symbolic")
                        visible: !root.downloading || root.cancelling
                        width: 17

                        layer.effect: ColorOverlay {
                            color: primaryAction.emphasized ? Config.md3.on_primary : Config.md3.on_primary_container
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: primaryAction.emphasized ? Config.md3.on_primary : Config.md3.on_primary_container
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        text: root.downloading ? (root.cancelling ? qsTr("Stopping…") : qsTr("Cancel")) : qsTr("Download")
                        visible: !root.downloaded
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
        HoverHandler {
            id: cardHover
        }
    }
}
