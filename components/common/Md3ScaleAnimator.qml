import QtQuick
import "../../"

ScaleAnimator {
    property string role: "transform"

    duration: Config.animationDuration(Md3.motion.durationFor(role))
    easing.type: Md3.motion.easingFor(role)
}
