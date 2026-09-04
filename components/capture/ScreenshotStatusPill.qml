import "../.."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    readonly property real desiredWidth: 7 + 10 + 18 + 1 + statusContent.spacing * 3 + statusTitle.implicitWidth + statusDetail.implicitWidth
    property string detailText: ""
    property bool error: false
    property real maximumWidth: 560
    property bool shown: false
    property string titleText: error ? qsTr("OCR failed") : qsTr("Copied")

    Accessible.name: detailText === "" ? titleText : titleText + ": " + detailText
    Accessible.role: Accessible.StaticText
    border.color: Config.alpha(error ? Config.md3.error : Config.md3.primary, 0.3)
    border.width: 1
    color: Config.alpha(error ? Config.md3.error_container : Config.md3.surface_container_high, 0.98)
    height: 30
    opacity: shown && maximumWidth >= 120 ? 1 : 0
    radius: height / 2
    scale: shown && maximumWidth >= 120 ? 1 : 0.96
    visible: shown || opacity > 0
    width: Math.max(0, Math.min(maximumWidth, desiredWidth))

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? 170 : 120
            easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: root.shown ? 170 : 120
            easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

    RowLayout {
        id: statusContent

        anchors.fill: parent
        anchors.leftMargin: 7
        anchors.rightMargin: 10
        spacing: 7

        Rectangle {
            Layout.preferredHeight: 18
            Layout.preferredWidth: 18
            color: root.error ? Config.md3.error : Config.md3.primary
            radius: 9

            Text {
                anchors.centerIn: parent
                color: root.error ? Config.md3.on_error : Config.md3.on_primary
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.Bold
                text: root.error ? "!" : "✓"
            }
        }
        Text {
            id: statusTitle

            color: root.error ? Config.md3.on_error_container : Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 13
            font.weight: Font.DemiBold
            text: root.titleText
        }
        Rectangle {
            Layout.preferredHeight: 14
            Layout.preferredWidth: 1
            color: Config.alpha(root.error ? Config.md3.on_error_container : Config.md3.on_surface_variant, 0.24)
        }
        Text {
            id: statusDetail

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            color: Config.alpha(root.error ? Config.md3.on_error_container : Config.md3.on_surface_variant, 0.82)
            elide: Text.ElideRight
            font.family: Config.fontName
            font.pixelSize: 13
            text: root.detailText
            textFormat: Text.PlainText
        }
    }
}
