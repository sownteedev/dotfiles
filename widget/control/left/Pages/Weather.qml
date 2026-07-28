import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../../../"
import "../../../../components"
import "../../../../service"

Item {
    id: root

    anchors.fill: parent

    Component.onCompleted: WeatherService.active = true
    Component.onDestruction: WeatherService.active = false

    AnimatedWeather {
        anchors.fill: parent
        running: root.visible && !!weatherIcon
        weatherIcon: WeatherService.icon
    }

    // The whole page can scroll vertically on shorter screens while the hourly
    // forecast keeps its own horizontal flick gesture.
    Flickable {
        id: pageFlickable

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: Math.max(weatherContent.implicitHeight, height)
        contentWidth: width
        interactive: contentHeight > height
        visible: WeatherService.hasData

        ColumnLayout {
            id: weatherContent

            spacing: 18
            width: pageFlickable.width
            y: Math.max(0, (pageFlickable.height - implicitHeight) / 2)

            // Current weather: location and condition on the left, values on the right.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 154
                spacing: 18

                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        Text {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 25
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 20
                            renderType: Text.NativeRendering
                            text: WeatherService.countryFlag
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            text: WeatherService.city
                        }
                    }
                    Item {
                        Layout.preferredHeight: 70
                        Layout.preferredWidth: 78

                        IconImage {
                            id: currentWeatherIcon

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: 68
                            layer.enabled: true
                            source: Quickshell.iconPath(WeatherService.icon)
                            width: 68

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                        text: WeatherService.condition
                    }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    Layout.minimumWidth: 175
                    spacing: 0

                    Text {
                        Layout.bottomMargin: 12
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 44
                        font.weight: Font.ExtraBold
                        horizontalAlignment: Text.AlignRight
                        renderType: Text.NativeRendering
                        text: WeatherService.temperature + "°C"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface_variant, 0.75)
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                            renderType: Text.NativeRendering
                            text: WeatherService.tempMax + "° / " + WeatherService.tempMin + "°"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface_variant, 0.75)
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                            renderType: Text.NativeRendering
                            text: "Feels Like " + WeatherService.feelsLike + "°C"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface_variant, 0.75)
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                            renderType: Text.NativeRendering
                            text: "Humidity: " + WeatherService.humidity + "%"
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 108
                clip: true
                color: Config.alpha(Config.md3.surface_container, 0.5)
                radius: 12

                ListView {
                    id: hourlyList

                    anchors.bottomMargin: 0
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    flickDeceleration: 3500
                    model: WeatherService.hourlyForecast
                    orientation: ListView.Horizontal

                    delegate: Item {
                        required property var modelData

                        height: hourlyList.height
                        width: modelData.sunEvent ? 76 : 64

                        Column {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Config.alpha(Config.md3.on_surface_variant, 0.75)
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                renderType: Text.NativeRendering
                                text: modelData.time
                                width: modelData.sunEvent ? 76 : 64
                            }
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 28
                                width: 28

                                IconImage {
                                    id: hourlyIcon

                                    anchors.fill: parent
                                    layer.enabled: true
                                    source: Quickshell.iconPath(modelData.icon)

                                    layer.effect: ColorOverlay {
                                        color: Config.md3.on_surface
                                    }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                                renderType: Text.NativeRendering
                                text: modelData.temperature
                                width: modelData.sunEvent ? 76 : 64
                            }
                        }
                    }
                }
            }

            // Six-day forecast.
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 142
                spacing: 0

                Repeater {
                    model: WeatherService.dailyForecast

                    delegate: Item {
                        id: dayItem

                        required property var modelData

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true

                        Column {
                            anchors.centerIn: parent
                            spacing: 5
                            width: dayItem.width

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Config.alpha(Config.md3.on_surface_variant, 0.75)
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                text: modelData.day
                            }
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 42
                                width: 42

                                IconImage {
                                    anchors.fill: parent
                                    layer.enabled: true
                                    source: Quickshell.iconPath(modelData.icon)

                                    layer.effect: ColorOverlay {
                                        color: Config.md3.on_surface
                                    }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                text: modelData.tempMax + "° / " + modelData.tempMin + "°"
                            }

                            // Always reserve this slot so dry and rainy days align.
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 30
                                width: parent.width

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    visible: modelData.precipitationProbability > 0

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 3

                                        IconImage {
                                            height: 12
                                            layer.enabled: true
                                            source: Quickshell.iconPath("weather-showers-symbolic")
                                            width: 12

                                            layer.effect: ColorOverlay {
                                                color: Config.md3.primary
                                            }
                                        }
                                        Text {
                                            color: Config.md3.primary
                                            font.family: Config.fontName
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            renderType: Text.NativeRendering
                                            text: modelData.precipitationProbability + "%"
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: Config.md3.primary
                                        font.family: Config.fontName
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        renderType: Text.NativeRendering
                                        text: modelData.precipitationAmount > 0 ? modelData.precipitationAmount.toFixed(1) + " mm" : ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Extra current conditions exposed by One Call 3.0.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                color: Config.alpha(Config.md3.surface_container, 0.38)
                radius: 12

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    columnSpacing: 10
                    columns: 3
                    rowSpacing: 10

                    Repeater {
                        model: [
                            {
                                label: "Wind",
                                icon: "weather-windy-symbolic",
                                value: WeatherService.windSpeed.toFixed(1) + " m/s " + WeatherService.windDirection(WeatherService.windDegree)
                            },
                            {
                                label: "UV index",
                                icon: "weather-clear-symbolic",
                                value: WeatherService.uvIndex.toFixed(1)
                            },
                            {
                                label: "Visibility",
                                icon: "view-reveal-symbolic",
                                value: (WeatherService.visibility / 1000).toFixed(1) + " km"
                            },
                            {
                                label: "Pressure",
                                icon: "speedometer-symbolic",
                                value: WeatherService.pressure + " hPa"
                            },
                            {
                                label: "Clouds",
                                icon: "weather-clouds-symbolic",
                                value: WeatherService.cloudiness + "%"
                            },
                            {
                                label: "Dew point",
                                icon: "weather-fog-symbolic",
                                value: WeatherService.dewPoint.toFixed(1) + "°C"
                            }
                        ]

                        delegate: Item {
                            required property int index
                            required property var modelData

                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            Column {
                                anchors.centerIn: parent
                                spacing: 5

                                IconImage {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 24
                                    layer.enabled: true
                                    source: Quickshell.iconPath(modelData.icon)
                                    width: 24

                                    layer.effect: ColorOverlay {
                                        color: Config.md3.on_surface_variant
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    renderType: Text.NativeRendering
                                    text: modelData.value
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Config.md3.on_surface_variant
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    renderType: Text.NativeRendering
                                    text: modelData.label
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: -5
                                anchors.verticalCenter: parent.verticalCenter
                                color: Config.alpha(Config.md3.on_surface_variant, 0.16)
                                height: 42
                                visible: index % 3 !== 2
                                width: 1
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -5
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Config.alpha(Config.md3.on_surface_variant, 0.16)
                                height: 1
                                visible: index < 3
                                width: parent.width * 0.72
                            }
                        }
                    }
                }
            }
        }
    }

    // Initial load and retry state. Existing data remains visible during refreshes.
    Column {
        anchors.centerIn: parent
        spacing: 14
        visible: !WeatherService.hasData

        LoadingIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            animated: !WeatherService.hasData && WeatherService.errorMessage === ""
            color: Config.md3.primary
            height: 100
            visible: WeatherService.errorMessage === ""
            width: 100
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 54
            visible: WeatherService.errorMessage !== ""
            width: 54

            IconImage {
                id: emptyWeatherIcon

                anchors.fill: parent
                layer.enabled: true
                source: Quickshell.iconPath("weather-severe-alert-symbolic")

                layer.effect: ColorOverlay {
                    color: Config.md3.error
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.md3.error
            font.family: Config.fontName
            font.pixelSize: 17
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
            text: "Could not load weather"
            visible: WeatherService.errorMessage !== ""
            width: Math.min(root.width - 40, 360)
            wrapMode: Text.WordWrap
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            color: retryArea.pressed ? Qt.darker(Config.md3.primary, 1.15) : Config.md3.primary
            height: 34
            radius: 17
            visible: WeatherService.errorMessage !== ""
            width: 92

            Text {
                anchors.centerIn: parent
                color: Config.md3.background
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Bold
                text: "Retry"
            }
            MouseArea {
                id: retryArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: WeatherService.fetchWeather()
            }
        }
    }
}
