import ".."
import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    readonly property real bodyHeight: bodyLoader.item ? bodyLoader.item.implicitHeight : 0
    readonly property real bodyWidth: bodyLoader.item ? bodyLoader.item.implicitWidth : 0
    readonly property real cornerRadius: 16
    property bool expanded: false
    property string menu: ""

    signal closeRequested
    signal filterChanged
    signal hotRequested

    function titleForMenu() {
        if (menu === "resolution")
            return qsTr("Resolution");

        if (menu === "ratio")
            return qsTr("Aspect ratio");

        if (menu === "color")
            return qsTr("Dominant color");

        return qsTr("Sort wallpapers");
    }

    implicitHeight: bodyHeight + 58
    implicitWidth: bodyWidth + 28
    opacity: expanded ? 1 : 0
    scale: expanded ? 1 : 0.97
    visible: expanded || opacity > 0

    Behavior on opacity {
        OpacityAnimator {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        ScaleAnimator {
            duration: 160
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
        color: Config.md3.surface_container_high
        radius: root.cornerRadius
    }
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 10
        height: 30

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 14
            font.weight: Font.DemiBold
            text: root.titleForMenu()
            width: parent.width - 30
        }
        Rectangle {
            color: closeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.1) : "transparent"
            height: 30
            radius: 9
            width: 30

            IconImage {
                anchors.centerIn: parent
                height: 14
                layer.enabled: true
                source: Quickshell.iconPath("window-close-symbolic")
                width: 14

                layer.effect: ColorOverlay {
                    color: Config.md3.on_surface_variant
                }
            }
            MouseArea {
                id: closeMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: root.closeRequested()
            }
        }
    }
    Loader {
        id: bodyLoader

        active: root.menu !== ""
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 48
        sourceComponent: root.menu === "resolution" ? resolutionComponent : (root.menu === "ratio" ? ratioComponent : (root.menu === "color" ? colorComponent : sortComponent))
    }
    Connections {
        function onCloseRequested() {
            root.closeRequested();
        }
        function onFilterChanged() {
            root.filterChanged();
        }
        function onHotRequested() {
            root.hotRequested();
        }

        ignoreUnknownSignals: true
        target: bodyLoader.status === Loader.Ready ? bodyLoader.item : null
    }
    Component {
        id: resolutionComponent

        WallhavenResolutionPopup {
        }
    }
    Component {
        id: ratioComponent

        WallhavenRatioPopup {
        }
    }
    Component {
        id: colorComponent

        WallhavenColorPopup {
        }
    }
    Component {
        id: sortComponent

        WallhavenSortPopup {
        }
    }
}
