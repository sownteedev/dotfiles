import QtQuick
import "../../service"

Rectangle {
    color: "black"
    opacity: IdleDimService.active ? 0.55 : 0

    Behavior on opacity {
        OpacityAnimator {
            duration: IdleDimService.active ? 450 : 160
            easing.type: Easing.OutCubic
        }
    }
}
