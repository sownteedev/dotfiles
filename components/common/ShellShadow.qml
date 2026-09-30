import QtQuick
import QtQuick.Effects
import "../../"

RectangularShadow {
    property bool active: true
    property bool componentShadow: false
    required property real cornerRadius
    property int level: -1
    required property Item target

    anchors.fill: target
    blur: level >= 0 ? Md3.elevation.blur(level) : (componentShadow ? Config.shellComponentShadowBlur : Config.shellShadowBlur)
    color: Config.alpha(Config.md3.shadow, level >= 0 ? Md3.elevation.opacity(level) : (componentShadow ? Config.shellComponentShadowOpacity : Config.shellShadowOpacity))
    offset.x: componentShadow ? Config.shellComponentShadowOffsetX : Config.shellShadowOffsetX
    offset.y: level >= 0 ? Md3.elevation.offsetY(level) : (componentShadow ? Config.shellComponentShadowOffsetY : Config.shellShadowOffsetY)
    radius: cornerRadius
    spread: level >= 0 ? Md3.elevation.spread(level) : (componentShadow ? Config.shellComponentShadowSpread : Config.shellShadowSpread)
    visible: active && (componentShadow ? Config.shellComponentShadowEnabled : Config.shellShadowEnabled)
}
