import "../../"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property bool emphasized: false
    property string headline: ""
    property color headlineColor: Config.md3.on_surface
    property string headlineRole: emphasized ? "titleMedium" : "bodyLarge"
    property real headlineSize: headlineStyle.size
    readonly property var headlineStyle: Md3.typeScale[headlineRole] || Md3.typeScale.bodyLarge
    property int supportingMaximumLineCount: 2
    property string supportingText: ""
    property color supportingTextColor: Config.md3.on_surface_variant

    Layout.minimumWidth: 0
    implicitWidth: 0
    spacing: supportingText === "" ? 0 : Md3.spacing.xxs

    Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        color: root.headlineColor
        elide: Text.ElideRight
        font.family: Config.fontName
        font.letterSpacing: root.headlineStyle.letterSpacing
        font.pixelSize: root.headlineSize
        font.weight: root.emphasized ? (root.headlineStyle.emphasizedWeight || Font.DemiBold) : root.supportingText !== "" ? Md3.typeScale.labelLarge.weight : root.headlineStyle.weight
        lineHeight: root.headlineStyle.lineHeight + Math.max(0, root.headlineSize - root.headlineStyle.size)
        lineHeightMode: Text.FixedHeight
        maximumLineCount: 1
        renderType: Text.NativeRendering
        text: root.headline
        verticalAlignment: Text.AlignVCenter
    }
    Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        color: root.supportingTextColor
        elide: Text.ElideRight
        font.family: Config.fontName
        font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
        font.pixelSize: Md3.typeScale.bodyMedium.size
        font.weight: Md3.typeScale.bodyMedium.weight
        lineHeight: Md3.typeScale.bodyMedium.lineHeight
        lineHeightMode: Text.FixedHeight
        maximumLineCount: root.supportingMaximumLineCount
        renderType: Text.NativeRendering
        text: root.supportingText
        visible: text !== ""
        wrapMode: Text.Wrap
    }
}
