import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../service"

Item {
    id: root

    property bool compact: false
    property bool serviceAcquired: false
    readonly property string temperatureText: WeatherService.hasData ? WeatherService.temperature + "°" : WeatherService.loading ? "…" : "--°"

    function syncService() {
        if (visible && !serviceAcquired) {
            WeatherService.acquire();
            serviceAcquired = true;
        } else if (!visible && serviceAcquired) {
            WeatherService.release();
            serviceAcquired = false;
        }
    }

    Accessible.name: WeatherService.hasData ? qsTr("%1, %2 degrees Celsius").arg(WeatherService.condition).arg(WeatherService.temperature) : qsTr("Weather unavailable")
    implicitHeight: Math.max(22, weatherLayout.implicitHeight)
    implicitWidth: weatherLayout.implicitWidth

    Component.onCompleted: syncService()
    Component.onDestruction: {
        if (serviceAcquired)
            WeatherService.release();
    }
    onVisibleChanged: syncService()

    RowLayout {
        id: weatherLayout

        anchors.fill: parent
        spacing: root.compact ? 4 : 6

        IconImage {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: root.compact ? 19 : 22
            Layout.preferredWidth: Layout.preferredHeight
            layer.enabled: true
            source: Quickshell.iconPath(WeatherService.icon || "weather-none-available-symbolic")

            layer.effect: ColorOverlay {
                color: WeatherService.hasData ? Config.md3.primary : Config.md3.on_surface_variant
            }
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            color: WeatherService.hasData ? Config.md3.on_surface : Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: root.compact ? 13 : 14
            font.weight: Font.Bold
            renderType: Text.NativeRendering
            text: root.temperatureText
        }
    }
}
