local awful = require("awful")
local json = require("modules.json")

local GET_FORECAST_CMD = [[bash -c "curl -s --show-error -X GET '%s'"]]

local icon_map = {
	["01d"] = "",
	["02d"] = "",
	["03d"] = "",
	["04d"] = "",
	["09d"] = "",
	["10d"] = "",
	["11d"] = "",
	["13d"] = "",
	["50d"] = "",
	["01n"] = "",
	["02n"] = "",
	["03n"] = "",
	["04n"] = "",
	["09n"] = "",
	["10n"] = "",
	["11n"] = "",
	["13n"] = "",
	["50n"] = ""
}

local api_key = "8b05d62206f459e1d298cbe5844d7d87"
local coordinates = { "53.9", "27.566667" }

local show_hourly_forecast = false
local show_daily_forecast = false
local units = "metric"

local url = (
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

awful.widget.watch(string.format(GET_FORECAST_CMD, url), 900, function(_, stdout, stderr)
	local result = json.decode(stdout)
	-- Current weather setup
	local out = {
		desc = result.current.weather[1].description:gsub("^%l", string.upper),
		humidity = result.current.humidity,
		temp = math.floor(result.current.temp),
		feelsLike = math.floor(result.current.feels_like),
		image = icon_map[result.current.weather[1].icon],
		hourly = {
			result.hourly[1],
			result.hourly[2],
			result.hourly[3],
			result.hourly[4],
			result.hourly[5],
			result.hourly[6],
			result.hourly[7],
			result.hourly[8],
			result.hourly[9],
		},
		daily = {
			result.daily[1],
			result.daily[2],
			result.daily[3],
			result.daily[4],
			result.daily[5],
			result.daily[6],
		}
	}
	awesome.emit_signal("connect::weather", out)
end)
