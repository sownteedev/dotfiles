local awful = require("awful")
local beautiful = require("beautiful")

local PATHS = {
	icons = beautiful.icon_path .. "weather/icons/",
	thumbs = beautiful.icon_path .. "weather/images/"
}

local SETTINGS = {
	api_key = _User.API_KEY_WEATHER,
	coordinates = _User.Coordinates,
	units = "metric",
	update_interval = 300,
	forecasts = {
		hourly = true,
		daily = true
	}
}

local WEATHER_MAPS = {
	icons = {
		["01d"] = "weather-clear-sky",
		["02d"] = "weather-few-clouds",
		["03d"] = "weather-clouds",
		["04d"] = "weather-few-clouds",
		["09d"] = "weather-showers-scattered",
		["10d"] = "weather-showers",
		["11d"] = "weather-strom",
		["13d"] = "weather-snow",
		["50d"] = "weather-fog",
		["01n"] = "weather-clear-night",
		["02n"] = "weather-few-clouds-night",
		["03n"] = "weather-clouds-night",
		["04n"] = "weather-clouds-night",
		["09n"] = "weather-showers-scattered",
		["10n"] = "weather-showers",
		["11n"] = "weather-strom",
		["13n"] = "weather-snow",
		["50n"] = "weather-fog"
	}
}
WEATHER_MAPS.images = WEATHER_MAPS.icons

local function create_urls()
	local base_url = "https://api.openweathermap.org"
	local exclude = "minutely" ..
		(not SETTINGS.forecasts.hourly and ",hourly" or "") ..
		(not SETTINGS.forecasts.daily and ",daily" or "")

	return {
		forecast = string.format(
			"%s/data/3.0/onecall?lat=%s&lon=%s&appid=%s&units=%s&exclude=%s",
			base_url,
			SETTINGS.coordinates[1],
			SETTINGS.coordinates[2],
			SETTINGS.api_key,
			SETTINGS.units,
			exclude
		),
		location = string.format(
			"%s/geo/1.0/reverse?lat=%s&lon=%s&limit=1&appid=%s",
			base_url,
			SETTINGS.coordinates[1],
			SETTINGS.coordinates[2],
			SETTINGS.api_key
		)
	}
end

local urls = create_urls()

awful.widget.watch(
	string.format('curl -s --show-error -X GET "%s"', urls.forecast),
	SETTINGS.update_interval,
	function(_, stdout)
		if stdout:find("Could not resolve host") then
			return
		end
		local result = _Utils.json.decode(stdout)
		local weather = result.current.weather[1]
		local daily_data = {}
		for i = 2, math.min(#result.daily, 7) do
			table.insert(daily_data, result.daily[i])
		end
		awesome.emit_signal("signal::weather", {
			desc = weather.description:gsub("^%l", string.upper),
			humidity = result.current.humidity,
			temp = math.floor(result.current.temp),
			wind_speed = math.floor(result.current.wind_speed * 3.6),
			image = PATHS.icons .. WEATHER_MAPS.icons[weather.icon] .. ".svg",
			thumb = PATHS.thumbs .. WEATHER_MAPS.images[weather.icon] .. ".jpg",
			daily = daily_data
		})
	end
)

awful.widget.watch(
	string.format('curl -s --show-error -X GET "%s"', urls.location),
	SETTINGS.update_interval,
	function(_, stdout)
		if stdout:find("Could not resolve host") then
			return
		end
		local result = _Utils.json.decode(stdout)
		awesome.emit_signal("signal::weather1", {
			city = result[1].name,
			country = string.lower(result[1].country)
		})
	end
)
