local awful = require("awful")
local gears = require("gears")
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

local api_key = require("config.key").openweatherapi
local coordinates = { "53.9", "27.566667" }

local show_hourly_forecast = true
local show_daily_forecast = true
local units = "metric"

local url = (
-- "https://api.openweathermap.org/data/2.5/weather?q=hanoi"
-- .. "?lat="
-- .. coordinates[1]
-- .. "&lon="
-- .. coordinates[2]
-- .. "&appid="
-- .. api_key
-- .. "&units="
-- .. units
-- .. "&exclude=minutely"
-- .. (show_hourly_forecast == false and ",hourly" or "")
-- .. (show_daily_forecast == false and ",daily" or "")
	"https://api.openweathermap.org/data/2.5/weather?q=hanoi&appid=0875523089f8f8d639f8e995c63d9252&units=metric&exclude=minutely,hourly,daily"
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
