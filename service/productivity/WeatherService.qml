pragma Singleton
import QtPositioning
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    readonly property bool active: activeConsumers > 0
    property int activeConsumers: 0
    property string city: ""
    property int cloudiness: 0
    property string condition: "Loading..."
    property Timer coordinateRefreshTimer: Timer {
        interval: 180
        repeat: false

        onTriggered: {
            if (root.active)
                root.fetchWeather();
        }
    }
    readonly property var coordinates: Config.latLon.split(",")
    property string country: ""
    readonly property string countryFlag: flagForCountry(country)
    property var dailyForecast: []
    property bool detectingLocation: false
    property real dewPoint: 0
    property string errorMessage: ""
    property real feelsLike: 0
    property Process forecastProcess: Process {
        id: forecastProcess

        property bool cancelled: false

        stderr: StdioCollector {
            id: forecastError
        }
        stdout: StdioCollector {
            id: forecastOutput
        }

        Component.onDestruction: running = false
        onExited: {
            if (cancelled) {
                var shouldRetry = root.refreshPending && root.active;
                cancelled = false;
                root.loading = false;
                root.refreshPending = false;
                if (shouldRetry)
                    Qt.callLater(root.fetchWeather);
                return;
            }
            try {
                var output = forecastOutput.text.trim();
                if (output === "")
                    throw new Error(forecastError.text.trim() || "No weather data received");
                root.applyForecast(JSON.parse(output));
                root.fetchLocation();
            } catch (error) {
                root.errorMessage = String(error);
                console.log("[WeatherService] Fetch failed:", error);
            }
            root.loading = false;
            if (root.refreshPending && root.active) {
                root.refreshPending = false;
                Qt.callLater(root.fetchWeather);
            }
        }
    }
    readonly property string forecastUrl: "https://api.openweathermap.org/data/3.0/onecall" + "?lat=" + latitude + "&lon=" + longitude + "&appid=" + Config.apiWeather + "&units=metric&exclude=minutely,alerts"
    property bool hasData: false
    property var hourlyForecast: []
    property int humidity: 0
    property string icon: "weather-few-clouds-symbolic"
    property date lastUpdated
    readonly property string latitude: coordinates.length > 0 ? coordinates[0] : ""
    property bool loading: false
    property Timer locationDetectionDelay: Timer {
        interval: 700
        repeat: false

        onTriggered: {
            if (!root.detectingLocation)
                return;
            if (!root.locationDetector.valid) {
                root.failLocationDetection(qsTr("Location provider is unavailable"));
                return;
            }
            root.locationDetectionStatus = qsTr("Finding your location…");
            root.locationDetectionTimeout.restart();
            root.locationDetector.update(15000);
        }
    }
    property bool locationDetectionError: false
    property string locationDetectionStatus: ""
    property Timer locationDetectionTimeout: Timer {
        interval: 17000
        repeat: false

        onTriggered: root.failLocationDetection(qsTr("Location request timed out"))
    }
    property PositionSource locationDetector: PositionSource {
        id: locationDetector

        name: "geoclue2"
        preferredPositioningMethods: PositionSource.NonSatellitePositioningMethods

        onPositionChanged: root.acceptDetectedPosition(position)
        onSourceErrorChanged: {
            if (root.detectingLocation && sourceError !== PositionSource.NoError)
                root.failLocationDetection(root.locationErrorText(sourceError));
        }

        PluginParameter {
            name: "desktopId"
            value: "org.quickshell"
        }
    }
    property Process locationProcess: Process {
        id: locationProcess

        stdout: StdioCollector {
            id: locationOutput
        }

        Component.onDestruction: running = false
        onExited: {
            try {
                var locations = JSON.parse(locationOutput.text.trim());
                if (Array.isArray(locations) && locations.length > 0) {
                    var location = locations[0];
                    var countryCode = String(location.country || root.country).toUpperCase();
                    var locationName = location.local_names && location.local_names.vi ? location.local_names.vi : location.name;
                    if (locationName)
                        root.city = String(locationName || "").trim();
                    root.country = countryCode;
                }
            } catch (error) {
                console.log("[WeatherService] Location lookup failed:", error);
            }
        }
    }
    readonly property string locationUrl: "https://api.openweathermap.org/geo/1.0/reverse" + "?lat=" + latitude + "&lon=" + longitude + "&limit=1&appid=" + Config.apiWeather
    readonly property string longitude: coordinates.length > 1 ? coordinates[1] : ""
    property real precipitationLastHour: 0
    property int pressure: 0
    property bool refreshPending: false
    property Timer refreshTimer: Timer {
        interval: 1200000
        repeat: true
        running: root.active

        onTriggered: root.fetchWeather()
    }
    property real tempMax: 0
    property real tempMin: 0
    property real temperature: 0
    readonly property string temperatureUnitName: useFahrenheit ? qsTr("Fahrenheit") : qsTr("Celsius")
    readonly property string temperatureUnitSymbol: useFahrenheit ? "°F" : "°C"
    readonly property bool useFahrenheit: Config.temperatureUnit === "fahrenheit"
    property real uvIndex: 0
    property int visibility: 0
    property int windDegree: 0
    property real windSpeed: 0

    signal locationDetected(string coordinates)

    function acceptDetectedPosition(position) {
        if (!detectingLocation || !position)
            return;

        var detectedLatitude = Number(position.coordinate.latitude);
        var detectedLongitude = Number(position.coordinate.longitude);
        if (!isFinite(detectedLatitude) || !isFinite(detectedLongitude) || detectedLatitude < -90 || detectedLatitude > 90 || detectedLongitude < -180 || detectedLongitude > 180)
            return;

        detectingLocation = false;
        locationDetector.stop();
        locationDetectionDelay.stop();
        locationDetectionTimeout.stop();
        locationDetectionError = false;
        var formattedCoordinates = detectedLatitude.toFixed(5) + "," + detectedLongitude.toFixed(5);
        locationDetectionStatus = qsTr("Location detected · Apply & save to use it");
        locationDetected(formattedCoordinates);
    }
    function acquire() {
        activeConsumers++;
    }
    function applyForecast(result) {
        if (!result || !result.current)
            throw new Error(result && result.message ? result.message : "Invalid weather response");

        var current = result.current;
        var currentWeather = current.weather && current.weather.length > 0 ? current.weather[0] : {};
        var today = result.daily && result.daily.length > 0 ? result.daily[0] : null;

        temperature = Number(current.temp || 0);
        feelsLike = Number(current.feels_like || 0);
        humidity = Math.round(current.humidity || 0);
        windSpeed = Number(current.wind_speed || 0);
        windDegree = Math.round(current.wind_deg || 0);
        uvIndex = Number(current.uvi || 0);
        visibility = Math.round(current.visibility || 0);
        pressure = Math.round(current.pressure || 0);
        cloudiness = Math.round(current.clouds || 0);
        dewPoint = Number(current.dew_point || 0);
        precipitationLastHour = current.rain && current.rain["1h"] !== undefined ? Number(current.rain["1h"]) : (current.snow && current.snow["1h"] !== undefined ? Number(current.snow["1h"]) : 0);
        tempMax = today && today.temp ? Number(today.temp.max) : temperature;
        tempMin = today && today.temp ? Number(today.temp.min) : temperature;
        condition = titleCase(currentWeather.description || "Unknown");
        icon = weatherIcon(currentWeather.icon || "02d");

        var hourly = [];
        var now = Math.floor(Date.now() / 1000);
        var next24Hours = now + 24 * 3600;
        var tomorrow = result.daily && result.daily.length > 1 ? result.daily[1] : {};
        var sunrise = validSunTime(current.sunrise || 0, tomorrow.sunrise || 0, now, next24Hours);
        var sunset = validSunTime(current.sunset || 0, tomorrow.sunset || 0, now, next24Hours);
        var allItems = [];

        if (result.hourly && Array.isArray(result.hourly)) {
            for (var i = 0; i < Math.min(24, result.hourly.length); i++)
                allItems.push({
                    dt: result.hourly[i].dt,
                    type: "hour",
                    data: result.hourly[i]
                });
        }
        if (sunrise > 0)
            allItems.push({
                dt: sunrise,
                type: "sunrise",
                data: null
            });
        if (sunset > 0)
            allItems.push({
                dt: sunset,
                type: "sunset",
                data: null
            });
        allItems.sort(function (a, b) {
            return a.dt - b.dt;
        });

        var firstHour = true;
        for (var j = 0; j < allItems.length; j++) {
            var item = allItems[j];
            if (item.type === "sunrise") {
                hourly.push({
                    time: timeText(item.dt),
                    icon: "weather-clear-symbolic",
                    temperature: "Sunrise",
                    sunEvent: true
                });
            } else if (item.type === "sunset") {
                hourly.push({
                    time: timeText(item.dt),
                    icon: "weather-clear-night-symbolic",
                    temperature: "Sunset",
                    sunEvent: true
                });
            } else {
                var hour = item.data;
                var hourWeather = hour.weather && hour.weather.length > 0 ? hour.weather[0] : {};
                hourly.push({
                    time: hourText(hour.dt, firstHour),
                    icon: weatherIcon(hourWeather.icon || "02d"),
                    temperature: Number(hour.temp || 0),
                    precipitationProbability: Math.round(Number(hour.pop || 0) * 100),
                    precipitationAmount: hour.rain && hour.rain["1h"] !== undefined ? Number(hour.rain["1h"]) : (hour.snow && hour.snow["1h"] !== undefined ? Number(hour.snow["1h"]) : 0),
                    humidity: Math.round(hour.humidity || 0),
                    windSpeed: Number(hour.wind_speed || 0),
                    sunEvent: false
                });
                firstHour = false;
            }
        }
        hourlyForecast = hourly;

        var daily = [];
        if (result.daily && Array.isArray(result.daily)) {
            for (var k = 1; k < Math.min(7, result.daily.length); k++) {
                var forecast = result.daily[k];
                var forecastWeather = forecast.weather && forecast.weather.length > 0 ? forecast.weather[0] : {};
                daily.push({
                    day: dayName(forecast.dt),
                    icon: weatherIcon(forecastWeather.icon || "02d"),
                    tempMax: Number(forecast.temp.max || 0),
                    tempMin: Number(forecast.temp.min || 0),
                    precipitationProbability: Math.round(Number(forecast.pop || 0) * 100),
                    precipitationAmount: forecast.rain !== undefined ? Number(forecast.rain) : (forecast.snow !== undefined ? Number(forecast.snow) : 0),
                    summary: forecast.summary || "",
                    humidity: Math.round(forecast.humidity || 0),
                    cloudiness: Math.round(forecast.clouds || 0),
                    uvIndex: Number(forecast.uvi || 0),
                    windSpeed: Number(forecast.wind_speed || 0)
                });
            }
        }
        dailyForecast = daily;

        hasData = true;
        errorMessage = "";
        lastUpdated = new Date();
    }
    function cancelLocationDetection() {
        detectingLocation = false;
        locationDetector.stop();
        locationDetectionDelay.stop();
        locationDetectionTimeout.stop();
        locationDetectionError = false;
        locationDetectionStatus = qsTr("Location detection cancelled");
    }
    function dayName(timestamp) {
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return days[new Date(timestamp * 1000).getDay()];
    }
    function detectLocation() {
        if (detectingLocation)
            return;

        detectingLocation = true;
        locationDetectionError = false;
        locationDetectionStatus = qsTr("Waiting for location permission…");
        Quickshell.execDetached(["/usr/lib/geoclue-2.0/demos/agent"]);
        locationDetectionDelay.restart();
    }
    function failLocationDetection(message) {
        detectingLocation = false;
        locationDetector.stop();
        locationDetectionDelay.stop();
        locationDetectionTimeout.stop();
        locationDetectionError = true;
        locationDetectionStatus = message;
    }
    function fetchLocation() {
        if (!active || locationProcess.running)
            return;
        locationProcess.command = ["curl", "-fsS", "--connect-timeout", "10", "--max-time", "15", locationUrl];
        locationProcess.running = true;
    }
    function fetchWeather() {
        if (!active)
            return;
        if (latitude === "" || longitude === "") {
            errorMessage = "Weather location is not configured";
            return;
        }
        if (String(Config.apiWeather || "").trim() === "") {
            errorMessage = "OpenWeather API key is not configured";
            return;
        }
        if (loading || forecastProcess.running) {
            refreshPending = true;
            return;
        }
        loading = true;
        errorMessage = "";
        forecastProcess.cancelled = false;
        forecastProcess.command = ["curl", "-fsS", "--connect-timeout", "10", "--max-time", "25", forecastUrl];
        forecastProcess.running = true;
    }
    function flagForCountry(countryCode) {
        var code = String(countryCode || "").trim().toUpperCase();
        if (code.length !== 2)
            return "";
        var first = code.charCodeAt(0) - 65;
        var second = code.charCodeAt(1) - 65;
        if (first < 0 || first > 25 || second < 0 || second > 25)
            return "";
        return String.fromCharCode(0xD83C, 0xDDE6 + first, 0xD83C, 0xDDE6 + second);
    }
    function formatTemperature(celsius, decimals, includeUnit) {
        var precision = decimals === undefined ? 0 : Math.max(0, Math.round(decimals));
        var suffix = includeUnit === false ? "°" : temperatureUnitSymbol;
        return toDisplayTemperature(celsius).toFixed(precision) + suffix;
    }
    function hourText(timestamp, firstHour) {
        if (firstHour)
            return "Now";
        var hour = new Date(timestamp * 1000).getHours();
        if (hour === 0)
            return "12AM";
        if (hour === 12)
            return "12PM";
        return hour < 12 ? hour + "AM" : (hour - 12) + "PM";
    }
    function locationErrorText(sourceError) {
        if (sourceError === PositionSource.AccessError)
            return qsTr("Location permission was denied");
        if (sourceError === PositionSource.ClosedError)
            return qsTr("Location service is unavailable or disabled");
        if (sourceError === PositionSource.UpdateTimeoutError)
            return qsTr("Location request timed out");
        return qsTr("Could not determine your location");
    }
    function needsRefresh() {
        return !hasData || !lastUpdated || Date.now() - lastUpdated.getTime() >= refreshTimer.interval;
    }
    function release() {
        activeConsumers = Math.max(0, activeConsumers - 1);
    }
    function stopRequests() {
        refreshPending = false;
        if (forecastProcess.running) {
            forecastProcess.cancelled = true;
            forecastProcess.running = false;
        } else {
            loading = false;
        }
        if (locationProcess.running)
            locationProcess.running = false;
    }
    function timeText(timestamp) {
        var date = new Date(timestamp * 1000);
        var hour = date.getHours();
        var hour12 = hour === 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        var minute = String(date.getMinutes()).padStart(2, "0");
        return hour12 + ":" + minute + (hour < 12 ? " AM" : " PM");
    }
    function titleCase(value) {
        if (!value)
            return "";
        return value.split(" ").map(function (word) {
            return word.length > 0 ? word.charAt(0).toUpperCase() + word.slice(1) : word;
        }).join(" ");
    }
    function toDisplayTemperature(celsius) {
        var value = Number(celsius);
        if (!isFinite(value))
            value = 0;
        return useFahrenheit ? value * 9 / 5 + 32 : value;
    }
    function validSunTime(todayTime, tomorrowTime, now, limit) {
        if (todayTime > now && todayTime <= limit)
            return todayTime;
        if (todayTime <= now && tomorrowTime > now && tomorrowTime <= limit)
            return tomorrowTime;
        return 0;
    }
    function weatherIcon(code) {
        var icons = {
            "01d": "weather-clear-symbolic",
            "01n": "weather-clear-night-symbolic",
            "02d": "weather-few-clouds-symbolic",
            "02n": "weather-few-clouds-night-symbolic",
            "03d": "weather-clouds-symbolic",
            "03n": "weather-clouds-night-symbolic",
            "04d": "weather-overcast-symbolic",
            "04n": "weather-overcast-night-symbolic",
            "09d": "weather-showers-symbolic",
            "09n": "weather-showers-symbolic",
            "10d": "weather-showers-scattered-symbolic",
            "10n": "weather-showers-scattered-symbolic",
            "11d": "weather-storm-symbolic",
            "11n": "weather-storm-symbolic",
            "13d": "weather-snow-symbolic",
            "13n": "weather-snow-night-symbolic",
            "50d": "weather-fog-symbolic",
            "50n": "weather-fog-symbolic"
        };
        return icons[code] || "weather-few-clouds-symbolic";
    }
    function windDirection(degrees) {
        var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return directions[Math.round(((degrees % 360) + 360) % 360 / 45) % 8];
    }

    onActiveChanged: {
        if (!active) {
            stopRequests();
        } else if (needsRefresh()) {
            fetchWeather();
        }
    }
    onLatitudeChanged: coordinateRefreshTimer.restart()
    onLongitudeChanged: coordinateRefreshTimer.restart()
}
