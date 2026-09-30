import "../../"
import ".."
import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root

    property bool available: false
    property string iconName: "audio-volume-muted-symbolic"
    property real maximumValue: 1
    property bool muted: false
    property bool popupOpen: false
    property real value: 0

    signal muteRequested
    signal volumeChanged(real value)

    function keepOpen() {
        if (!available)
            return;
        closeTimer.stop();
        popupOpen = true;
    }
    function scheduleClose() {
        if (!volumeSlider.pressed && !buttonHover.hovered && !volumePopupHover.hovered)
            closeTimer.restart();
    }

    implicitHeight: 36
    implicitWidth: 36
    z: popupOpen ? 10 : 0

    onAvailableChanged: {
        if (!available) {
            closeTimer.stop();
            popupOpen = false;
        }
    }

    Md3IconButton {
        id: volumeButton

        Accessible.name: root.muted ? qsTr("Unmute player") : qsTr("Mute player")
        anchors.fill: parent
        checkable: true
        checked: root.muted
        containerSize: 32
        enabled: root.available
        iconName: root.iconName
        iconSize: 20
        objectName: "musicVolumeButton"

        onClicked: root.muteRequested()

        HoverHandler {
            id: buttonHover

            onHoveredChanged: {
                if (hovered)
                    root.keepOpen();
                else
                    root.scheduleClose();
            }
        }
    }
    Popup {
        id: volumePopup

        closePolicy: Popup.NoAutoClose
        dim: false
        enabled: root.available
        focus: false
        height: 124
        modal: false
        padding: 0
        popupType: Popup.Item
        visible: root.popupOpen
        width: 40
        x: Math.round((root.width - width) / 2)
        y: -height
        z: 100

        background: Rectangle {
            border.color: Config.alpha(Config.md3.outline_variant, 0.36)
            border.width: 1
            color: Config.md3.surface_container_high
            radius: width / 2
        }
        contentItem: Item {
            HoverHandler {
                id: volumePopupHover

                onHoveredChanged: {
                    if (hovered)
                        root.keepOpen();
                    else
                        root.scheduleClose();
                }
            }
            Slider {
                id: volumeSlider

                Accessible.name: qsTr("Player volume")
                anchors.bottomMargin: 10
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.topMargin: 10
                enabled: root.available
                from: 0
                hoverEnabled: true
                live: true
                objectName: "musicVolumeSlider"
                orientation: Qt.Vertical
                stepSize: 0.01
                to: Math.max(0.01, root.maximumValue)
                value: root.value

                background: Rectangle {
                    color: Config.alpha(Config.md3.on_surface, 0.14)
                    height: volumeSlider.availableHeight
                    radius: width / 2
                    width: 4
                    x: volumeSlider.leftPadding + (volumeSlider.availableWidth - width) / 2
                    y: volumeSlider.topPadding

                    Rectangle {
                        anchors.bottom: parent.bottom
                        color: root.muted ? Config.md3.outline : Config.md3.primary
                        height: parent.height * volumeSlider.position
                        radius: parent.radius
                        width: parent.width
                    }
                }
                handle: Rectangle {
                    color: root.muted ? Config.md3.outline : Config.md3.primary
                    height: 12
                    radius: width / 2
                    scale: volumeSlider.pressed ? 1.2 : volumeSlider.hovered ? 1.08 : 1
                    width: 12
                    x: volumeSlider.leftPadding + (volumeSlider.availableWidth - width) / 2
                    y: volumeSlider.topPadding + volumeSlider.visualPosition * (volumeSlider.availableHeight - height)

                    Behavior on scale {
                        NumberAnimation {
                            duration: Config.animationDuration(Md3.motion.short2)
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                onMoved: root.volumeChanged(value)
                onPressedChanged: {
                    if (pressed)
                        root.keepOpen();
                    else
                        root.scheduleClose();
                }
            }
        }
        enter: Transition {
            NumberAnimation {
                duration: Config.animationDuration(Md3.motion.short3)
                easing.type: Easing.OutCubic
                from: 0
                property: "opacity"
                to: 1
            }
        }
        exit: Transition {
            NumberAnimation {
                duration: Config.animationDuration(Md3.motion.short2)
                easing.type: Easing.InCubic
                from: 1
                property: "opacity"
                to: 0
            }
        }
    }
    Timer {
        id: closeTimer

        interval: 140
        repeat: false

        onTriggered: root.popupOpen = false
    }
}
