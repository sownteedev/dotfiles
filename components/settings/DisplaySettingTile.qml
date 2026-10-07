import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property color containerColor: Config.md3.surface_container_low
    property string iconName: "video-display-symbolic"
    property string label: ""
    property bool showChevron: true
    property string value: ""

    signal activated(var sourceItem)

    function activate() {
        if (!enabled)
            return;

        activated(root);
    }
    function blend(baseColor, overlayColor, amount) {
        var base = Qt.color(baseColor);
        var overlay = Qt.color(overlayColor);
        var ratio = Math.max(0, Math.min(1, amount));
        var overlayAlpha = overlay.a * ratio;
        var alpha = overlayAlpha + base.a * (1 - overlayAlpha);
        if (alpha <= 0)
            return Qt.rgba(0, 0, 0, 0);
        var baseWeight = base.a * (1 - overlayAlpha);
        return Qt.rgba((overlay.r * overlayAlpha + base.r * baseWeight) / alpha, (overlay.g * overlayAlpha + base.g * baseWeight) / alpha, (overlay.b * overlayAlpha + base.b * baseWeight) / alpha, alpha);
    }

    Accessible.name: qsTr("%1: %2").arg(label).arg(value)
    Accessible.role: Accessible.ComboBox
    Layout.fillWidth: true
    activeFocusOnTab: false
    border.color: "transparent"
    border.width: 0
    color: {
        if (tileMouse.pressed)
            return root.blend(root.containerColor, Config.md3.on_surface, Md3.state.pressed);
        if (tileMouse.containsMouse)
            return root.blend(root.containerColor, Config.md3.on_surface, Md3.state.hover);
        return root.containerColor;
    }
    implicitHeight: 64
    opacity: enabled ? 1 : Md3.state.disabledContent
    radius: Md3.shape.large

    Behavior on color {
        ColorAnimation {
            duration: Config.animationDuration(Md3.motion.short3)
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Config.animationDuration(Md3.motion.short2)
        }
    }

    Accessible.onPressAction: activate()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            activate();
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 36
            Layout.preferredWidth: 36
            color: Config.alpha(root.accentColor, 0.14)
            radius: Md3.shape.medium

            Md3Icon {
                anchors.centerIn: parent
                color: root.accentColor
                filled: true
                name: root.iconName
                size: 20
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: Md3.typography.labelMedium
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                text: root.label
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: Md3.typography.bodyLarge
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                text: root.value
            }
        }
        Md3Icon {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 16
            Layout.preferredWidth: 16
            color: Config.md3.on_surface_variant
            name: "expand_more"
            size: 18
            visible: root.showChevron
        }
    }
    MouseArea {
        id: tileMouse

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: root.activate()
    }
}
