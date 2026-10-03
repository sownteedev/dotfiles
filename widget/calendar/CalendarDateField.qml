import "../../components"
import "../../"
import "lunar.js" as Lunar
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string accessibleDescription: qsTr("Choose date")
    property date value: new Date()

    signal clicked

    function formatDate() {
        return root.value.toLocaleDateString(Qt.locale(), Locale.LongFormat);
    }

    Accessible.description: root.accessibleDescription
    Accessible.name: qsTr("%1, %2 lunar").arg(root.formatDate()).arg(Lunar.getLunarFullString(root.value))
    Accessible.role: Accessible.Button
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredHeight: 56
    activeFocusOnTab: false
    border.color: dateMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.56) : Config.alpha(Config.md3.outline, 0.22)
    border.width: 1
    color: Config.md3.surface_container_low
    radius: Md3.shape.medium

    Behavior on border.color {
        ColorAnimation {
            duration: Config.animationDuration(Md3.motion.short3)
        }
    }

    Accessible.onPressAction: root.clicked()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: Config.md3.on_surface
        opacity: dateMouse.pressed ? Md3.state.pressed : dateMouse.containsMouse ? Md3.state.hover : 0
        radius: Math.max(0, root.radius - 1)

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(Md3.motion.short2)
                easing.type: Md3.motion.standard
            }
        }
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 15
        spacing: Md3.spacing.sm

        Md3Icon {
            Layout.preferredHeight: 22
            Layout.preferredWidth: 22
            color: Config.md3.primary
            name: "calendar_month"
            size: 22
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 1

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                font.pixelSize: 15
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                text: root.formatDate()
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
                font.pixelSize: 12
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                text: qsTr("%1 lunar").arg(Lunar.getLunarFullString(root.value))
            }
        }
        Md3Icon {
            Layout.preferredHeight: 20
            Layout.preferredWidth: 20
            color: Config.md3.on_surface_variant
            name: "expand_more"
            size: 20
        }
    }
    MouseArea {
        id: dateMouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: root.clicked()
    }
}
