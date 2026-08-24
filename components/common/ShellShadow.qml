import QtQuick
import QtQuick.Effects
import "../../"

RectangularShadow {
    property bool active: true
    property bool componentShadow: false
    required property real cornerRadius
    required property Item target

    anchors.fill: target
    blur: componentShadow ? Config.shellComponentShadowBlur : Config.shellShadowBlur
    color: Config.alpha(Config.md3.shadow, componentShadow ? Config.shellComponentShadowOpacity : Config.shellShadowOpacity)
    offset.x: componentShadow ? Config.shellComponentShadowOffsetX : Config.shellShadowOffsetX
    offset.y: componentShadow ? Config.shellComponentShadowOffsetY : Config.shellShadowOffsetY
    radius: cornerRadius
    spread: componentShadow ? Config.shellComponentShadowSpread : Config.shellShadowSpread
    visible: active && (componentShadow ? Config.shellComponentShadowEnabled : Config.shellShadowEnabled)
}
