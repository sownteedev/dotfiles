local awful                = require("awful")
local json                 = require("modules.json")
local beautiful            = require("beautiful")
local icon_dir             = beautiful.icon_path .. "weather/icons/"
local thumb_dir            = beautiful.icon_path .. "weather/images/"

local GET_FORECAST_CMD     = [[bash -c "curl -s --show-error -X GET '%s'"]]

local icon_map             = {
	["01d"] = "weather-clear-sky",
	["02d"] = "weather-few-clouds",
	["04d"] = "weather-few-clouds",
	["03d"] = "weather-clouds",
	["09d"] = "weather-showers-scattered",
	["09n"] = "weather-showers-scattered",
	["10d"] = "weather-showers",
	["11d"] = "weather-strom",
	["13d"] = "weather-snow",
	["50d"] = "weather-fog",
	["01n"] = "weather-clear-night",
	["02n"] = "weather-few-clouds-night",
	["03n"] = "weather-clouds-night",
	["04n"] = "weather-clouds-night",
	["10n"] = "weather-showers",
	["11n"] = "weather-strom",
	["13n"] = "weather-snow",
	["50n"] = "weather-fog",
}

local image_map            = {
	["01d"] = "weather-clear-sky",
	["02d"] = "weather-clouds",
	["04d"] = "weather-clouds",
	["03d"] = "weather-clouds",
	["09d"] = "weather-showers-scattered",
	["09n"] = "weather-showers-scattered",
	["10d"] = "weather-showers",
	["11d"] = "weather-strom",
	["13d"] = "weather-snow",
	["50d"] = "weather-fog",
	["01n"] = "weather-clear-night",
	["02n"] = "weather-clouds-night",
	["03n"] = "weather-clouds-night",
	["04n"] = "weather-clouds-night",
	["10n"] = "weather-showers",
	["11n"] = "weather-strom",
	["13n"] = "weather-snow",
	["50n"] = "weather-fog",
}

local api_key              = _User.API_KEY_WEATHER
local coordinates          = _User.Coordinates
local show_hourly_forecast = true
local show_daily_forecast  = true
local units                = "metric"

local url                  = (
	"https://api.openweathermap.org/data/2.5/onecall"
	.. "?lat="
	.. coordinates[1]
	.. "&lon="
	.. coordinates[2]
	.. "&appid="
	.. api_key
	.. "&units="
	.. units
	.. "&exclude=minutely"
	.. (show_hourly_forecast == false and ",hourly" or "")
	.. (show_daily_forecast == false and ",daily" or "")
)

local url1                 = (
	"https://api.openweathermap.org/geo/1.0/reverse"
	.. "?lat="
	.. coordinates[1]
	.. "&lon="
	.. coordinates[2]
	.. "&limit=1"
	.. "&appid="
	.. api_key
)

awful.widget.watch(string.format(GET_FORECAST_CMD, url), 3600, function(_, stdout, stderr)
	if stdout ~= nil then
		local result = json.decode(stdout)
		local out = {
			desc = result.current.weather[1].description:gsub("^%l", string.upper),
			humidity = result.current.humidity,
			temp = math.floor(result.current.temp),
			feelsLike = math.floor(result.current.feels_like),
			image = icon_dir .. icon_map[result.current.weather[1].icon] .. ".svg",
			thumb = thumb_dir .. image_map[result.current.weather[1].icon] .. ".jpg",
			hourly = {
				result.hourly[1],
				result.hourly[2],
				result.hourly[3],
				result.hourly[4],
				result.hourly[5],
				result.hourly[6],
			},
			daily = {
				result.daily[1],
				result.daily[2],
				result.daily[3],
				result.daily[4],
				result.daily[5],
				result.daily[6],
			},
		}
		awesome.emit_signal("signal::weather", out)
	end
end)

awful.widget.watch(string.format(GET_FORECAST_CMD, url1), 3600, function(_, stdout, stderr)
	if stdout ~= nil then
		local result = json.decode(stdout)
		local out = { namecountry = result[1].name .. ", " .. result[1].country }
		awesome.emit_signal("signal::weather1", out)
	end
end)
