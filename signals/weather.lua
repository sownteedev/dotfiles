local awful = require("awful")
local json = require("modules.json")
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

local function process_weather_data(stdout)
	if not stdout then return end

	local result = json.decode(stdout)
	if not result or not result.current then return end

	local weather = result.current.weather[1]
	local icon_code = weather.icon

	return {
		desc = weather.description:gsub("^%l", string.upper),
		humidity = result.current.humidity,
		temp = math.floor(result.current.temp),
		feelsLike = math.floor(result.current.feels_like),
		image = PATHS.icons .. WEATHER_MAPS.icons[icon_code] .. ".svg",
		thumb = PATHS.thumbs .. WEATHER_MAPS.images[icon_code] .. ".jpg",
		hourly = { table.unpack(result.hourly, 1, 6) },
		daily = { table.unpack(result.daily, 1, 6) }
	}
end

local urls = create_urls()

awful.widget.watch(
	string.format('curl -s --show-error -X GET "%s"', urls.forecast),
	SETTINGS.update_interval,
	function(_, stdout)
		local data = process_weather_data(stdout)
		if data then
			awesome.emit_signal("signal::weather", data)
		end
	end
)

awful.widget.watch(
	string.format('curl -s --show-error -X GET "%s"', urls.location),
	SETTINGS.update_interval,
	function(_, stdout)
		if stdout then
			local result = json.decode(stdout)
			if result and result[1] then
				awesome.emit_signal("signal::weather1", {
					namecountry = string.format("%s, %s", result[1].name, result[1].country)
				})
			end
		end
	end
)
