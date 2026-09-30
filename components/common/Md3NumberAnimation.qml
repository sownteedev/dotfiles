import QtQuick
import "../../"

// Shared MD3 Expressive animation for numeric properties.  Keeping the role
// here prevents each widget from drifting into a different timing curve.
NumberAnimation {
    property string role: "state"

    duration: Config.animationDuration(Md3.motion.durationFor(role))
    easing.type: Md3.motion.easingFor(role)
}
