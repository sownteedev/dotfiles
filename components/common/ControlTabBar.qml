pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../"
import ".."

TabSwipeNavigation {
    id: root

    property bool compact: false
    property bool hideLabelWhenCompact: true
    property int iconSize: 26
    property var icons: []
    property var labels: []
    property int motionDuration: Config.animationDuration(Md3.motion.short3)
    property int showWifiIconIndex: -1
    property bool wifiConnected: true
    property bool wifiIssue: false
    property int wifiSignal: 100

    Accessible.role: Accessible.PageTabList
    count: labels.length
    implicitHeight: 44

    RowLayout {
        anchors.fill: parent
        spacing: root.compact ? 10 : 20

        Item {
            Layout.fillWidth: true
        }
        Repeater {
            model: root.labels.length

            delegate: Rectangle {
                id: tabButton

                property real animatedWidth: desiredWidth
                readonly property real desiredWidth: isActive && !(root.compact && root.hideLabelWhenCompact) ? tabContent.implicitWidth + 36 : 44
                required property int index
                readonly property bool isActive: index === root.currentIndex

                Accessible.name: root.labels[index]
                Accessible.role: Accessible.PageTab
                Layout.preferredHeight: 40
                Layout.preferredWidth: animatedWidth
                color: isActive ? Config.md3.primary : (tabMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.06) : "transparent")
                radius: 22

                Behavior on animatedWidth {
                    NumberAnimation {
                        duration: root.motionDuration
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: root.motionDuration
                    }
                }

                ShellShadow {
                    active: tabButton.isActive
                    componentShadow: true
                    cornerRadius: parent.radius
                    target: parent
                    z: -1
                }
                Row {
                    id: tabContent

                    anchors.centerIn: parent
                    spacing: 10

                    WifiSignalIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        color: tabButton.isActive ? Config.md3.on_primary : Config.md3.on_surface
                        connected: root.wifiConnected
                        connectivityIssue: root.wifiIssue
                        height: 26
                        signalStrength: root.wifiSignal
                        visible: index === root.showWifiIconIndex
                        width: 26
                    }
                    Md3Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        color: tabButton.isActive ? Config.md3.on_primary : Config.md3.on_surface_variant
                        filled: tabButton.isActive
                        name: root.icons[index] || ""
                        size: root.iconSize
                        visible: index !== root.showWifiIconIndex

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(Md3.motion.short3)
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.on_primary
                        font.family: Config.fontName
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        text: root.labels[index]
                        visible: tabButton.isActive && !(root.compact && root.hideLabelWhenCompact)
                    }
                }
                MouseArea {
                    id: tabMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.requested(index)
                }
            }
        }
        Item {
            Layout.fillWidth: true
        }
    }
}
