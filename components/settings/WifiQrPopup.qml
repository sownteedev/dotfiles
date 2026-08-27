import ".."
import "../../"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

FocusScope {
    id: root

    readonly property color backdropColor: Config.md3.scrim
    readonly property real backdropOpacity: Config.lightTheme ? 0.1 : 0.15
    property real backdropRadius: 0
    property bool busy: false
    property string errorText: ""
    readonly property color qrBackgroundColor: Config.lightTheme ? Config.md3.primary_container : Config.md3.on_primary_container
    readonly property color qrForegroundColor: Config.lightTheme ? Config.md3.on_primary_container : Config.md3.primary_container
    property string qrPath: ""
    property bool showing: false
    property string ssid: ""

    signal dismissed
    signal retryRequested

    function close() {
        if (!showing)
            return;

        showing = false;
        if (Config.shellReducedMotion)
            dismissed();
        else
            dismissTimer.restart();
    }

    anchors.fill: parent
    focus: true

    Component.onCompleted: Qt.callLater(function () {
        root.showing = true;
        root.forceActiveFocus();
    })
    Keys.onEscapePressed: event => {
        close();
        event.accepted = true;
    }

    Timer {
        id: dismissTimer

        interval: 120
        repeat: false

        onTriggered: root.dismissed()
    }
    Rectangle {
        anchors.fill: parent
        color: Config.alpha(root.backdropColor, root.showing ? root.backdropOpacity : 0)
        radius: root.backdropRadius

        Behavior on color {
            ColorAnimation {
                duration: Config.shellReducedMotion ? 0 : 140
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        anchors.fill: parent

        onClicked: root.close()
    }
    Item {
        id: cardContainer

        anchors.centerIn: parent
        height: Math.min(root.height - 28, 430)
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.94
        width: Math.min(root.width - 28, 380)

        Behavior on opacity {
            NumberAnimation {
                duration: Config.shellReducedMotion ? 0 : 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.shellReducedMotion ? 0 : 190
                easing.type: Easing.OutBack
            }
        }

        ShellShadow {
            active: root.showing
            cornerRadius: qrCard.radius
            target: qrCard
        }
        Rectangle {
            id: qrCard

            readonly property real qrSize: Math.min(270, width - 44)

            anchors.fill: parent
            border.color: Config.alpha(Config.md3.primary, Config.lightTheme ? 0.18 : 0.26)
            border.width: 1
            color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.97 : 0.92)
            radius: 22

            MouseArea {
                anchors.fill: parent

                onClicked: mouse => mouse.accepted = true
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 42
                        color: Config.alpha(Config.md3.primary, 0.14)
                        radius: 13

                        IconImage {
                            anchors.centerIn: parent
                            height: 22
                            layer.enabled: true
                            source: Quickshell.iconPath("qrscanner-symbolic")
                            width: 22

                            layer.effect: ColorOverlay {
                                color: Config.md3.primary
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            text: qsTr("Share Wi-Fi")
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.52)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 12
                            text: root.ssid
                        }
                    }
                    SettingsActionButton {
                        iconName: "window-close-symbolic"
                        iconOnly: true
                        text: qsTr("Close")

                        onClicked: root.close()
                    }
                }
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: qrCard.qrSize
                    Layout.preferredWidth: qrCard.qrSize

                    Rectangle {
                        anchors.fill: parent
                        border.color: Config.alpha(root.qrForegroundColor, 0.18)
                        border.width: 1
                        color: root.qrBackgroundColor
                        radius: 20
                        visible: root.errorText === ""

                        Image {
                            id: qrImage

                            anchors.fill: parent
                            anchors.margins: 15
                            asynchronous: true
                            cache: false
                            fillMode: Image.PreserveAspectFit
                            smooth: false
                            source: root.qrPath === "" ? "" : "file://" + root.qrPath
                            sourceSize.height: 300
                            sourceSize.width: 300
                            visible: false
                        }
                        LevelAdjust {
                            anchors.fill: qrImage
                            cached: false
                            maximumOutput: root.qrBackgroundColor
                            minimumOutput: root.qrForegroundColor
                            source: qrImage
                            visible: qrImage.status === Image.Ready
                        }
                        BusyIndicator {
                            anchors.centerIn: parent
                            height: 46
                            running: root.busy || qrImage.status === Image.Loading
                            visible: running
                            width: 46
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: root.errorText !== ""
                        width: parent.width - 24

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            color: Config.md3.error
                            font.family: Config.fontName
                            font.pixelSize: 30
                            font.weight: Font.Bold
                            text: "!"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            text: root.errorText
                            wrapMode: Text.Wrap
                        }
                        SettingsActionButton {
                            Layout.alignment: Qt.AlignHCenter
                            enabled: !root.busy
                            iconName: "view-refresh-symbolic"
                            text: qsTr("Try again")

                            onClicked: root.retryRequested()
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.52)
                    font.family: Config.fontName
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Scan this code with a phone to join the network")
                    visible: root.errorText === ""
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
