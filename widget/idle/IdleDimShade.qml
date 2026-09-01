import QtQuick
import "../.."
import "../../service"

Rectangle {
    color: "black"
    opacity: IdleDimService.active ? IdleDimService.dimOpacity : 0

    Behavior on opacity {
        OpacityAnimator {
            duration: IdleDimService.active ? 450 : 160
            easing.type: Easing.OutCubic
        }
    }
}
