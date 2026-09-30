import QtQuick
import "../../"

OpacityAnimator {
    property string role: "state"

    duration: Config.animationDuration(Md3.motion.durationFor(role))
    easing.type: Md3.motion.easingFor(role)
}
