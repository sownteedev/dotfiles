import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../../../"
import "../../../../components"
import "../../../../service"

Item {
    id: root

    readonly property bool animationActive: visible && !WeatherService.hasData
    readonly property bool missingApiKey: String(Config.apiWeather || "").trim() === ""

    anchors.fill: parent

    Component.onCompleted: WeatherService.acquire()
    Component.onDestruction: WeatherService.release()

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
                        text: WeatherService.formatTemperature(WeatherService.temperature)
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
                            text: WeatherService.formatTemperature(WeatherService.tempMax, 0, false) + " / " + WeatherService.formatTemperature(WeatherService.tempMin, 0, false)
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface_variant, 0.75)
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignRight
                            renderType: Text.NativeRendering
                            text: qsTr("Feels Like %1").arg(WeatherService.formatTemperature(WeatherService.feelsLike))
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
                border.color: Config.alpha(Config.md3.on_surface, 0.07)
                border.width: 1
                clip: true
                color: Config.alpha(Config.md3.surface_container_high, 0.36)
                radius: 14

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
                                text: modelData.sunEvent ? modelData.temperature : WeatherService.formatTemperature(modelData.temperature, 0, false)
                                width: modelData.sunEvent ? 76 : 64
                            }
                        }
                    }
                }
            }

            // Six-day forecast.
            Flickable {
                id: dailyForecastViewport

                Layout.fillWidth: true
                Layout.preferredHeight: 142
                boundsBehavior: Flickable.StopAtBounds
                clip: contentWidth > width
                contentHeight: height
                contentWidth: Math.max(width, dailyForecastRow.implicitWidth)
                flickableDirection: Flickable.HorizontalFlick
                interactive: contentWidth > width

                Row {
                    id: dailyForecastRow

                    height: parent.height
                    spacing: 4
                    x: implicitWidth <= dailyForecastViewport.width ? (dailyForecastViewport.width - implicitWidth) / 2 : 0

                    Repeater {
                        id: dailyForecastRepeater

                        model: WeatherService.dailyForecast

                        delegate: Item {
                            id: dayItem

                            readonly property real equalWidth: (dailyForecastViewport.width - Math.max(0, dailyForecastRepeater.count - 1) * dailyForecastRow.spacing) / Math.max(1, dailyForecastRepeater.count)
                            required property var modelData

                            height: dailyForecastViewport.height
                            width: Math.max(78, equalWidth)

                            Column {
                                anchors.centerIn: parent
                                spacing: 5
                                width: dayItem.width

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Config.alpha(Config.md3.on_surface_variant, 0.75)
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                    text: modelData.day
                                    width: dayItem.width - 8
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
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                    text: WeatherService.formatTemperature(modelData.tempMax, 0, false) + " / " + WeatherService.formatTemperature(modelData.tempMin, 0, false)
                                    width: dayItem.width - 8
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
            }

            // Extra current conditions exposed by One Call 3.0.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 170
                border.color: Config.alpha(Config.md3.on_surface, 0.07)
                border.width: 1
                color: Config.alpha(Config.md3.surface_container_high, 0.32)
                radius: 14

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
                                value: WeatherService.formatTemperature(WeatherService.dewPoint, 1)
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

    // A missing key is configuration, not a failed request, so give it a
    // purposeful empty state instead of the generic error and retry controls.
    Column {
        anchors.centerIn: parent
        spacing: 20
        visible: !WeatherService.hasData && root.missingApiKey
        width: Math.min(root.width - 48, 360)

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 210
            width: 260

            Rectangle {
                anchors.centerIn: parent
                border.color: Config.alpha(Config.md3.primary, 0.12)
                border.width: 1
                color: Config.alpha(Config.md3.primary, 0.035)
                height: 190
                radius: 95
                width: 190

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.animationActive && root.missingApiKey

                    NumberAnimation {
                        duration: 2100
                        easing.type: Easing.InOutSine
                        to: 1.07
                    }
                    NumberAnimation {
                        duration: 2100
                        easing.type: Easing.InOutSine
                        to: 1
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                color: Config.alpha(Config.md3.surface_container_high, 0.68)
                height: 142
                radius: 71
                width: 142
            }
            Item {
                id: sun

                height: 62
                width: 62
                x: 145
                y: 24

                Rectangle {
                    anchors.centerIn: parent
                    color: Config.alpha(Config.md3.tertiary, 0.16)
                    height: 62
                    radius: 31
                    width: 62

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.animationActive && root.missingApiKey

                        NumberAnimation {
                            duration: 1300
                            easing.type: Easing.InOutSine
                            to: 0.48
                        }
                        NumberAnimation {
                            duration: 1300
                            easing.type: Easing.InOutSine
                            to: 1
                        }
                    }
                }
                IconImage {
                    anchors.centerIn: parent
                    height: 38
                    layer.enabled: true
                    source: Quickshell.iconPath("weather-clear-symbolic")
                    width: 38

                    layer.effect: ColorOverlay {
                        color: Config.md3.tertiary
                    }
                    RotationAnimation on rotation {
                        duration: 12000
                        from: 0
                        loops: Animation.Infinite
                        running: root.animationActive && root.missingApiKey
                        to: 360
                    }
                }
            }
            Item {
                id: floatingCloud

                height: 108
                width: 138
                x: 55
                y: 66

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: root.animationActive && root.missingApiKey

                    NumberAnimation {
                        duration: 2500
                        easing.type: Easing.InOutSine
                        to: 67
                    }
                    NumberAnimation {
                        duration: 2500
                        easing.type: Easing.InOutSine
                        to: 55
                    }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: root.animationActive && root.missingApiKey

                    NumberAnimation {
                        duration: 1800
                        easing.type: Easing.InOutSine
                        to: 60
                    }
                    NumberAnimation {
                        duration: 1800
                        easing.type: Easing.InOutSine
                        to: 66
                    }
                }

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 82
                    layer.enabled: true
                    source: Quickshell.iconPath("weather-few-clouds-symbolic")
                    width: 104

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface
                    }
                }
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index

                            color: Config.md3.primary
                            height: 15
                            opacity: 0
                            radius: 2
                            rotation: 16
                            width: 4

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.animationActive && root.missingApiKey

                                PauseAnimation {
                                    duration: index * 240
                                }
                                NumberAnimation {
                                    duration: 180
                                    to: 0.8
                                }
                                PauseAnimation {
                                    duration: 430
                                }
                                NumberAnimation {
                                    duration: 240
                                    to: 0
                                }
                                PauseAnimation {
                                    duration: 380 + (2 - index) * 240
                                }
                            }
                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                running: root.animationActive && root.missingApiKey

                                PauseAnimation {
                                    duration: index * 240
                                }
                                NumberAnimation {
                                    duration: 1
                                    to: -10
                                }
                                NumberAnimation {
                                    duration: 850
                                    easing.type: Easing.InQuad
                                    to: 9
                                }
                                PauseAnimation {
                                    duration: 380 + (2 - index) * 240
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: keyBadge

                border.color: Config.alpha(Config.md3.primary, 0.28)
                border.width: 1
                color: Config.md3.surface_container_lowest
                height: 48
                radius: 24
                width: 48
                x: 174
                y: 140

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.animationActive && root.missingApiKey

                    NumberAnimation {
                        duration: 900
                        easing.type: Easing.OutCubic
                        to: 1.1
                    }
                    NumberAnimation {
                        duration: 1100
                        easing.type: Easing.InOutSine
                        to: 1
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 23
                    layer.enabled: true
                    source: Quickshell.iconPath("dialog-password-symbolic")
                    width: 23

                    layer.effect: ColorOverlay {
                        color: Config.md3.primary
                    }
                }
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            width: parent.width

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 22
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
                text: "Your forecast is waiting"
                width: parent.width
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.25
                renderType: Text.NativeRendering
                text: "Add an OpenWeather API key in Settings\nto bring the weather to life"
                width: parent.width
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            border.color: Config.alpha(Config.md3.primary, 0.2)
            border.width: 1
            color: Config.alpha(Config.md3.primary, 0.08)
            height: 34
            radius: 17
            width: missingKeyRow.implicitWidth + 28

            Row {
                id: missingKeyRow

                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Config.md3.primary
                    height: 8
                    radius: 4
                    width: 8

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.animationActive && root.missingApiKey

                        NumberAnimation {
                            duration: 850
                            easing.type: Easing.InOutSine
                            to: 0.3
                        }
                        NumberAnimation {
                            duration: 850
                            easing.type: Easing.InOutSine
                            to: 1
                        }
                    }
                }
                Text {
                    color: Config.md3.primary
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    text: "API key not configured"
                }
            }
        }
    }
    LoadingIndicator {
        anchors.centerIn: parent
        animated: visible
        color: Config.md3.primary
        height: 100
        visible: !WeatherService.hasData && !root.missingApiKey && WeatherService.errorMessage === ""
        width: 100
    }

    // Request failures remain actionable with a retry button.
    Column {
        anchors.centerIn: parent
        spacing: 14
        visible: !WeatherService.hasData && !root.missingApiKey && WeatherService.errorMessage !== ""

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 54
            width: 54

            IconImage {
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
            width: Math.min(root.width - 40, 360)
            wrapMode: Text.WordWrap
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            color: retryArea.pressed ? Qt.darker(Config.md3.primary, 1.15) : Config.md3.primary
            height: 34
            radius: 17
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
