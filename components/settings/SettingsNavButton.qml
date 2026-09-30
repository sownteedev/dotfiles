import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property bool active: false
    property bool compact: false
    property bool dense: false
    property bool expandable: false
    property bool expanded: false
    property bool firstInGroup: true
    property color iconColor: Config.md3.primary
    property color iconForegroundColor: Config.md3.on_primary
    property string iconName: ""
    readonly property real iconSize: rail ? 24 : compact ? 22 : 24
    property url iconSource: ""
    readonly property real iconViewportSize: compact ? 28 : 40
    property bool indented: false
    property bool lastInGroup: true
    property bool rail: false
    property string subtitle: ""
    property string text: ""

    signal clicked

    Accessible.description: root.subtitle
    Accessible.name: root.text
    Accessible.role: Accessible.Button
    activeFocusOnTab: false
    border.color: "transparent"
    border.width: 0
    color: "transparent"
    implicitHeight: rail ? 60 : compact ? 48 : subtitle !== "" ? (dense ? 58 : 72) : dense ? 48 : 52
    radius: Md3.shape.medium

    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }
    Keys.onReturnPressed: event => {
        root.clicked();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        root.clicked();
        event.accepted = true;
    }

    // --- Standard Navigation Drawer Layout (Expanded / Dense) ---
    Rectangle {
        anchors.fill: parent
        bottomLeftRadius: root.lastInGroup ? Md3.shape.large : Md3.spacing.xxs
        bottomRightRadius: bottomLeftRadius
        color: Config.md3.surface_container_low
        topLeftRadius: root.firstInGroup ? Md3.shape.large : Md3.spacing.xxs
        topRightRadius: topLeftRadius
        visible: !root.rail && !root.compact && root.indented
    }
    Rectangle {
        id: navBackground

        anchors.centerIn: parent
        color: root.compact ? Config.md3.secondary_container : Config.md3.surface_container_highest
        height: root.compact ? width : root.height
        opacity: root.active ? 1 : 0
        radius: root.compact ? height / 2 : root.radius
        visible: !root.rail
        width: root.compact ? Math.min(root.width, root.height) : root.width

        Behavior on opacity {
            Md3OpacityAnimator {
                role: "state"
            }
        }
    }
    Rectangle {
        anchors.fill: navBackground
        color: root.active && root.compact ? Config.md3.on_secondary_container : Config.md3.on_surface
        opacity: mouse.pressed ? Md3.state.pressed : mouse.containsMouse ? Md3.state.hover : 0
        radius: navBackground.radius
        visible: !root.rail

        Behavior on color {
            Md3ColorAnimation {
                role: "state"
            }
        }
        Behavior on opacity {
            Md3OpacityAnimator {
                role: "state"
            }
        }
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? (root.width - root.iconViewportSize) / 2 : 12
        anchors.rightMargin: root.compact ? (root.width - root.iconViewportSize) / 2 : 12
        spacing: Md3.spacing.sm
        visible: !root.rail

        Rectangle {
            Layout.preferredHeight: root.iconViewportSize
            Layout.preferredWidth: root.iconViewportSize
            color: root.compact ? "transparent" : root.iconColor
            radius: width / 2
            visible: root.iconName !== "" || root.iconSource.toString() !== ""

            Image {
                Accessible.ignored: true
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                height: width
                source: root.iconSource
                sourceSize: Qt.size(width, height)
                visible: root.iconSource.toString() !== ""
                width: root.compact ? root.iconSize : 32
            }
            Md3Icon {
                anchors.centerIn: parent
                color: root.compact ? (root.active ? Config.md3.on_secondary_container : root.iconColor) : root.iconForegroundColor
                filled: root.active
                name: root.iconName
                size: root.iconSize
                visible: root.iconSource.toString() === ""

                Behavior on color {
                    Md3ColorAnimation {
                        role: "state"
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Md3.spacing.xxs
            visible: !root.compact

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                font.pixelSize: Md3.typeScale.bodyLarge.size
                font.weight: Font.Medium
                text: root.text
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                color: Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                font.pixelSize: Md3.typeScale.bodyMedium.size
                maximumLineCount: 1
                text: root.subtitle
                visible: text !== ""
            }
        }
        Md3Icon {
            color: Config.md3.on_surface_variant
            name: root.expanded ? "expand_more" : "chevron_right"
            size: 20
            visible: root.expandable && !root.compact

            Behavior on color {
                Md3ColorAnimation {
                    role: "state"
                }
            }
        }
    }

    // --- Material 3 Navigation Rail Layout (Compact Pill + Label) ---
    Item {
        id: railItem

        anchors.fill: parent
        visible: root.rail

        Rectangle {
            id: railPill

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 4
            color: root.active ? Config.md3.secondary_container : "transparent"
            height: 32
            radius: height / 2
            width: 56

            Behavior on color {
                Md3ColorAnimation {
                    role: "state"
                }
            }

            Rectangle {
                anchors.fill: parent
                color: root.active ? Config.md3.on_secondary_container : Config.md3.on_surface
                opacity: mouse.pressed ? Md3.state.pressed : mouse.containsMouse ? Md3.state.hover : 0
                radius: parent.radius

                Behavior on opacity {
                    Md3OpacityAnimator {
                        role: "state"
                    }
                }
            }
            Image {
                Accessible.ignored: true
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                height: 22
                source: root.iconSource
                sourceSize: Qt.size(22, 22)
                visible: root.iconSource.toString() !== ""
                width: 22
            }
            Md3Icon {
                anchors.centerIn: parent
                color: root.active ? Config.md3.on_secondary_container : (root.iconColor !== Config.md3.primary ? root.iconColor : Config.md3.on_surface_variant)
                filled: root.active
                name: root.iconName
                size: 24
                visible: root.iconSource.toString() === ""

                Behavior on color {
                    Md3ColorAnimation {
                        role: "state"
                    }
                }
            }
        }
        Text {
            id: railLabel

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: railPill.bottom
            anchors.topMargin: 4
            color: root.active ? Config.md3.on_surface : Config.md3.on_surface_variant
            elide: Text.ElideRight
            font.family: Config.fontName
            font.letterSpacing: Md3.typeScale.labelMedium.letterSpacing
            font.pixelSize: Md3.typeScale.labelMedium.size
            font.weight: root.active ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 1
            text: root.text
            width: Math.max(0, parent.width - 6)

            Behavior on color {
                Md3ColorAnimation {
                    role: "state"
                }
            }
        }
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: root.clicked()
    }
    Md3ToolTip {
        id: compactToolTip

        text: root.text
        visible: (root.rail ? (mouse.containsMouse && railLabel.truncated) : (root.compact && mouse.containsMouse && root.text !== ""))
        x: root.width + 8
        y: (root.height - height) / 2
    }
}
