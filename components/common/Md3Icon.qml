import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

Item {
    id: root

    property color color: Config.md3.on_surface
    property string fallbackIconName: Md3.iconFallbackName(name)
    readonly property bool fallbackIsDirectSource: fallbackIconName.startsWith("file:") || fallbackIconName.startsWith("qrc:") || fallbackIconName.startsWith("image:") || fallbackIconName.startsWith("data:") || fallbackIconName.startsWith("/")
    readonly property url fallbackSource: symbolAvailable || fallbackIconName === "" ? "" : (fallbackIsDirectSource ? fallbackIconName : Quickshell.iconPath(fallbackIconName))
    property bool filled: false
    property int grade: 0
    property string name: ""
    property int opticalSize: Math.max(20, Math.min(48, Math.round(size)))
    property real size: 24
    readonly property bool symbolAvailable: Md3.iconsAvailable && symbolCodepoint > 0
    readonly property int symbolCodepoint: Md3.iconCodepoint(name)
    property int weight: 500

    Accessible.ignored: true
    implicitHeight: size
    implicitWidth: size

    Text {
        anchors.centerIn: parent
        color: root.color
        font.family: Md3.iconFontFamily
        font.pixelSize: root.size
        font.variableAxes: ({
                "FILL": root.filled ? 1 : 0,
                "GRAD": root.grade,
                "opsz": root.opticalSize,
                "wght": root.weight
            })
        horizontalAlignment: Text.AlignHCenter
        renderType: Text.NativeRendering
        text: Md3.iconText(root.name)
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        visible: root.symbolAvailable
    }
    IconImage {
        anchors.centerIn: parent
        height: root.size
        layer.enabled: visible
        source: root.fallbackSource
        visible: !root.symbolAvailable && root.fallbackIconName !== ""
        width: root.size

        layer.effect: ColorOverlay {
            color: root.color
        }
    }
}
