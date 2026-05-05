import { bind, Variable, GLib, execAsync } from "astal";
import { Gtk } from "astal/gtk3";
import Global from "../../../../Global";

export interface DailyForecast {
    day: string;
    icon: string;
    tempMax: number;
    tempMin: number;
}

export interface HourlyForecast {
    time: string;
    icon: string;
    temp: number | string; // number for temp, string for "Sunrise"/"Sunset"
    isSunrise?: boolean;
    isSunset?: boolean;
}

export interface WeatherData {
    temperature: number;
    feelsLike: number;
    tempMax: number;
    tempMin: number;
    condition: string;
    icon: string;
    humidity: number;
    city: string;
    country: string;
    hourly: HourlyForecast[];
    daily: DailyForecast[];
}

const WEATHER_CONFIG = {
    apiKey: Global.APIWeather,
    lat: Global.LatLon.split(",")[0],
    lon: Global.LatLon.split(",")[1],
    units: "metric",
    updateInterval: 300000, // 5 minutes in ms
};

const WEATHER_ICON_MAP: { [key: string]: string } = {
    "01d": "weather-clear-symbolic",
    "01n": "weather-clear-night-symbolic",
    "02d": "weather-few-clouds-symbolic",
    "02n": "weather-few-clouds-night-symbolic",
    "03d": "weather-clouds-symbolic",
    "03n": "weather-clouds-night-symbolic",
    "04d": "weather-overcast-symbolic",
    "04n": "weather-overcast-symbolic",
    "09d": "weather-showers-symbolic",
    "09n": "weather-showers-symbolic",
    "10d": "weather-showers-scattered-symbolic",
    "10n": "weather-showers-scattered-symbolic",
    "11d": "weather-storm-symbolic",
    "11n": "weather-storm-symbolic",
    "13d": "weather-snow-symbolic",
    "13n": "weather-snow-symbolic",
    "50d": "weather-fog-symbolic",
    "50n": "weather-fog-symbolic",
};

export const weatherData = Variable<WeatherData>({
    temperature: 0,
    feelsLike: 0,
    tempMax: 0,
    tempMin: 0,
    condition: "Loading...",
    icon: "weather-few-clouds-symbolic",
    humidity: 0,
    city: "Hanoi",
    country: "VN",
    hourly: [],
    daily: [],
});

export const isWeatherLoading = Variable(false);

let weatherTimerId: number | null = null;
let weatherInitialized = false;

const WEATHER_FORECAST_URL = `https://api.openweathermap.org/data/3.0/onecall?lat=${WEATHER_CONFIG.lat}&lon=${WEATHER_CONFIG.lon}&appid=${WEATHER_CONFIG.apiKey}&units=${WEATHER_CONFIG.units}&exclude=minutely,alerts`;
const WEATHER_LOCATION_URL = `https://api.openweathermap.org/geo/1.0/reverse?lat=${WEATHER_CONFIG.lat}&lon=${WEATHER_CONFIG.lon}&limit=1&appid=${WEATHER_CONFIG.apiKey}`;

const getDayName = (timestamp: number): string => {
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const date = new Date(timestamp * 1000);
    return days[date.getDay()];
};

const getHourString = (timestamp: number, isFirst: boolean): string => {
    if (isFirst) return "Now";
    const date = new Date(timestamp * 1000);
    const hour = date.getHours();
    if (hour === 0) return "12AM";
    if (hour === 12) return "12PM";
    return hour < 12 ? `${hour}AM` : `${hour - 12}PM`;
};

const getTimeStringWithMinutes = (timestamp: number): string => {
    const date = new Date(timestamp * 1000);
    const hour = date.getHours();
    const minutes = date.getMinutes();
    const hour12 = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
    const ampm = hour < 12 ? "AM" : "PM";
    return `${hour12}:${minutes.toString().padStart(2, "0")} ${ampm}`;
};

export const fetchWeather = async () => {
    if (isWeatherLoading.get()) return; // Prevent concurrent fetches

    isWeatherLoading.set(true);
    try {
        const weatherResponse = await execAsync([
            "curl",
            "-s",
            "--show-error",
            "-X",
            "GET",
            WEATHER_FORECAST_URL,
        ]);

        if (weatherResponse.includes("Could not resolve host")) {
            console.error("Weather: Network error");
            isWeatherLoading.set(false);
            return;
        }

        const result = JSON.parse(weatherResponse);
        if (result.current) {
            const current = result.current;
            const weather = current.weather[0];
            const iconCode = weather.icon || "02d";

            // Fetch location data
            let city = "Hanoi";
            let country = "VN";
            try {
                const locationResponse = await execAsync([
                    "curl",
                    "-s",
                    "-X",
                    "GET",
                    WEATHER_LOCATION_URL,
                ]);
                const locationResult = JSON.parse(locationResponse);
                if (locationResult[0]) {
                    city = locationResult[0].name || city;
                    country = locationResult[0].country || country;
                }
            } catch (e) {
                console.error("Weather: Location fetch failed");
            }

            // Get today's max/min from daily[0]
            let todayMax = 0;
            let todayMin = 0;
            if (result.daily && result.daily[0]) {
                todayMax = Math.round(result.daily[0].temp.max);
                todayMin = Math.round(result.daily[0].temp.min);
            }

            // Parse hourly forecast (next 24 hours) with sunrise/sunset
            const hourlyForecast: HourlyForecast[] = [];
            const now = Math.floor(Date.now() / 1000);
            const next24Hours = now + 24 * 3600;

            // Helper function to determine which sunrise/sunset to use
            const getSunTime = (
                todayTime: number,
                tomorrowTime: number
            ): number => {
                if (todayTime > now && todayTime <= next24Hours) {
                    return todayTime;
                }
                if (
                    todayTime <= now &&
                    tomorrowTime > now &&
                    tomorrowTime <= next24Hours
                ) {
                    return tomorrowTime;
                }
                return 0;
            };

            // Get sunrise/sunset for today and tomorrow
            const todaySunrise = result.current?.sunrise || 0;
            const todaySunset = result.current?.sunset || 0;
            const tomorrowSunrise = result.daily?.[1]?.sunrise || 0;
            const tomorrowSunset = result.daily?.[1]?.sunset || 0;

            // Determine which sunrise/sunset to use
            const sunrise = getSunTime(todaySunrise, tomorrowSunrise);
            const sunset = getSunTime(todaySunset, tomorrowSunset);

            if (result.hourly && Array.isArray(result.hourly)) {
                // Collect all items (hours + sunrise/sunset)
                const allItems: Array<{
                    dt: number;
                    type: "hour" | "sunrise" | "sunset";
                    data: any;
                }> = [];

                // Add all hourly forecasts
                for (let i = 0; i < Math.min(24, result.hourly.length); i++) {
                    const hour = result.hourly[i];
                    allItems.push({ dt: hour.dt, type: "hour", data: hour });
                }

                // Add sunrise/sunset if valid
                if (sunrise > 0) {
                    allItems.push({
                        dt: sunrise,
                        type: "sunrise",
                        data: null,
                    });
                }
                if (sunset > 0) {
                    allItems.push({
                        dt: sunset,
                        type: "sunset",
                        data: null,
                    });
                }

                // Sort by timestamp
                allItems.sort((a, b) => a.dt - b.dt);

                // Convert to HourlyForecast format
                let isFirstHour = true;
                allItems.forEach((item) => {
                    if (item.type === "sunrise") {
                        hourlyForecast.push({
                            time: getTimeStringWithMinutes(item.dt),
                            icon: "weather-clear-symbolic",
                            temp: "Sunrise",
                            isSunrise: true,
                        });
                    } else if (item.type === "sunset") {
                        hourlyForecast.push({
                            time: getTimeStringWithMinutes(item.dt),
                            icon: "weather-clear-night-symbolic",
                            temp: "Sunset",
                            isSunset: true,
                        });
                    } else {
                        const hour = item.data;
                        const hourIcon = hour.weather?.[0]?.icon || "02d";
                        hourlyForecast.push({
                            time: getHourString(hour.dt, isFirstHour),
                            icon:
                                WEATHER_ICON_MAP[hourIcon] ||
                                "weather-few-clouds-symbolic",
                            temp: Math.round(hour.temp),
                        });
                        isFirstHour = false;
                    }
                });
            }

            // Parse daily forecast (skip today, get next 6 days)
            const dailyForecast: DailyForecast[] = [];
            if (result.daily && Array.isArray(result.daily)) {
                for (let i = 1; i < Math.min(7, result.daily.length); i++) {
                    const day = result.daily[i];
                    const dayIcon = day.weather?.[0]?.icon || "02d";
                    dailyForecast.push({
                        day: getDayName(day.dt),
                        icon:
                            WEATHER_ICON_MAP[dayIcon] ||
                            "weather-few-clouds-symbolic",
                        tempMax: Math.round(day.temp.max),
                        tempMin: Math.round(day.temp.min),
                    });
                }
            }

            weatherData.set({
                temperature: Math.round(current.temp),
                feelsLike: Math.round(current.feels_like),
                tempMax: todayMax,
                tempMin: todayMin,
                condition: weather.description
                    .split(" ")
                    .map((w: string) => w.charAt(0).toUpperCase() + w.slice(1))
                    .join(" "),
                icon:
                    WEATHER_ICON_MAP[iconCode] || "weather-few-clouds-symbolic",
                humidity: current.humidity,
                city,
                country: country.toUpperCase(),
                hourly: hourlyForecast,
                daily: dailyForecast,
            });
        }
    } catch (e) {
        console.error("Weather: Fetch failed", e);
    }
    isWeatherLoading.set(false);
};

export const initWeatherTimer = () => {
    if (weatherInitialized) return;
    weatherInitialized = true;

    // Initial fetch
    fetchWeather();

    // Set up periodic updates
    weatherTimerId = GLib.timeout_add(
        GLib.PRIORITY_DEFAULT,
        WEATHER_CONFIG.updateInterval,
        () => {
            fetchWeather();
            return true;
        }
    );
};

export const getWeatherTimerId = (): number | null => weatherTimerId;

export const cleanupWeather = () => {
    if (weatherTimerId) {
        GLib.source_remove(weatherTimerId);
        weatherTimerId = null;
    }
    weatherInitialized = false;
};

export const Weather = () => {
    // Initialize weather on mount (singleton pattern)
    const initWeather = () => {
        initWeatherTimer();
    };

    return (
        <box vertical className="weather-container" spacing={30} setup={initWeather}>
            {bind(weatherData).as((data) => (
                <>
                    <box className="weather-main" spacing={15}>
                        {/* Left side: City, Icon, Description */}
                        <box vertical className="weather-left" spacing={10}>
                            <box spacing={10}>
                                <icon
                                    icon="location-svg"
                                    className="weather-location-icon"
                                />
                                <label
                                    label={`${data.city}, ${data.country}`}
                                    className="weather-location"
                                />
                            </box>
                            <icon
                                icon={data.icon}
                                className="weather-icon-large"
                            />
                            <label
                                label={data.condition}
                                className="weather-condition"
                                xalign={0}
                            />
                        </box>

                        {/* Right side: Temperature, Max/Min, Feels Like, Humidity */}
                        <box
                            vertical
                            className="weather-right"
                            valign={Gtk.Align.START}
                            halign={Gtk.Align.END}
                            hexpand
                            spacing={10}
                        >
                            <label
                                label={`${data.temperature}°C`}
                                className="weather-temp-large"
                                xalign={1}
                            />
                            <label
                                label={`${data.tempMax}° / ${data.tempMin}°`}
                                className="weather-temp-range"
                                xalign={1}
                            />
                            <label
                                label={`Feels Like ${data.feelsLike}°C`}
                                className="weather-feels-like"
                                xalign={1}
                            />
                            <label
                                label={`Humidity: ${data.humidity}%`}
                                className="weather-humidity"
                                xalign={1}
                            />
                        </box>
                    </box>

                    {/* Hourly forecast (iPhone style) */}
                    <scrollable
                        valign={Gtk.Align.CENTER}
                        hscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                        vscrollbarPolicy={Gtk.PolicyType.NEVER}
                        className="weather-hourly-scroll"
                    >
                        <box className="weather-hourly">
                            {data.hourly.map((hour) => (
                                <box
                                    vertical
                                    className="weather-hourly-item"
                                    halign={Gtk.Align.CENTER}
                                    spacing={5}
                                >
                                    <label
                                        label={hour.time}
                                        className="hourly-time"
                                    />
                                    <icon
                                        icon={hour.icon}
                                        className="hourly-icon"
                                    />
                                    <label
                                        label={
                                            typeof hour.temp === "string"
                                                ? hour.temp
                                                : `${hour.temp}°`
                                        }
                                        className="hourly-temp"
                                    />
                                </box>
                            ))}
                        </box>
                    </scrollable>

                    {/* 6-day forecast row */}
                    <box className="weather-forecast" homogeneous>
                        {data.daily.map((day) => (
                            <box
                                vertical
                                className="weather-forecast-day"
                                halign={Gtk.Align.CENTER}
                                spacing={8}
                            >
                                <label
                                    label={day.day}
                                    className="forecast-day-name"
                                />
                                <icon
                                    icon={day.icon}
                                    className="forecast-icon"
                                />
                                <label
                                    label={`${day.tempMax}° / ${day.tempMin}°`}
                                    className="forecast-temp"
                                />
                            </box>
                        ))}
                    </box>
                </>
            ))}
        </box>
    );
};