local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local filesystem = gears.filesystem
local icon_dir = filesystem.get_configuration_dir() .. "themes/assets/weather/icons/"

local icon_map = {
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
	["50n"] = "weather-fog",
}

local dayWeather = function()
	local widget = wibox.widget({
		{
			id = "day",
			markup = "",
			widget = wibox.widget.textbox,
			font = beautiful.sans .. " 15",
		},
		{
			id = "icon",
			resize = true,
			opacity = 1,
			forced_height = 50,
			forced_width = 50,
			widget = wibox.widget.imagebox,
		},
		{
			{
				{
					id = "max",
					markup = "",
					widget = wibox.widget.textbox,
					font = beautiful.sans .. " 10",
				},
				{
					markup = helpers.colorizeText("/", beautiful.blue),
					widget = wibox.widget.textbox,
					font = beautiful.sans .. " 10",
				},
				{
					id = "min",
					markup = "",
					widget = wibox.widget.textbox,
					font = beautiful.sans .. " 10",
				},
				spacing = 8,
				layout = wibox.layout.fixed.horizontal,
			},
			widget = wibox.container.place,
		},
		spacing = 10,
		forced_width = 80,
		layout = wibox.layout.fixed.vertical,
	})

	widget.update = function(out, i)
		local day = out.daily[i]
		helpers.gc(widget, "icon").image = icon_dir .. icon_map[day.weather[1].icon] .. ".svg"
		helpers.gc(widget, "day").markup = helpers.colorizeText(os.date("%a", tonumber(day.dt)), "#ffffff")
		local getTemp = function(temp)
			local sp = helpers.split(temp, ".")[1]
			return sp
		end
		helpers.gc(widget, "min").markup = helpers.colorizeText(getTemp(day.temp.night), "#ffffff")
		helpers.gc(widget, "max").markup = helpers.colorizeText(getTemp(day.temp.day), "#ffffff")
	end
	return widget
end

local day1 = dayWeather()
local day2 = dayWeather()
local day3 = dayWeather()
local day4 = dayWeather()
local day5 = dayWeather()
local day6 = dayWeather()

local daylist = { day1, day2, day3, day4, day5, day6 }

local widget = wibox.widget({
	{
		id = "image",
		forced_height = 450,
		forced_width = 600,
		image = helpers.cropSurface(
			1,
			gears.surface.load_uncached(
				filesystem.get_configuration_dir() .. "themes/assets/weather/images/weather-clear-night.jpg"
			)
		),
		widget = wibox.widget.imagebox,
		clip_shape = helpers.rrect(5),
		opacity = 1,
		resize = true,
		horizontal_fit_policy = "fit",
	},
	{
		{
			{
				{
					{
						id = "city",
						font = beautiful.sans .. " 20",
						markup = "",
						widget = wibox.widget.textbox,
					},
					{
						id = "icon",
						image = filesystem.get_configuration_dir() .. "themes/assets/weather/icons/weather-fog.svg",
						opacity = 1,
						clip_shape = helpers.rrect(4),
						forced_height = 80,
						forced_width = 80,
						widget = wibox.widget.imagebox,
					},
					{
						id = "desc",
						font = beautiful.sans .. " 15",
						markup = "",
						widget = wibox.widget.textbox,
					},
					spacing = 20,
					layout = wibox.layout.fixed.vertical,
					halign = "left",
				},
				nil,
				{
					{
						id = "temp",
						font = beautiful.sans .. " 30",
						markup = "",
						widget = wibox.widget.textbox,
					},
					{
						id = "fl",
						font = beautiful.sans .. " 15",
						markup = "",
						widget = wibox.widget.textbox,
					},
					{
						id = "humid",
						font = beautiful.sans .. " 15",
						markup = "",
						widget = wibox.widget.textbox,
					},
					spacing = 20,
					layout = wibox.layout.fixed.vertical,
				},
				layout = wibox.layout.align.horizontal,
			},
			nil,
			{
				day1,
				day2,
				day3,
				day4,
				day5,
				day6,
				layout = require("modules.overflow").horizontal,
				scrollbar_width = 0,
				spacing = 15,
			},
			layout = wibox.layout.align.vertical,
		},
		widget = wibox.container.margin,
		left = 30,
		right = 30,
		top = 20,
		bottom = 20,
	},
	layout = wibox.layout.stack,
})

awesome.connect_signal("signal::weather", function(out)
	helpers.gc(widget, "image").image = helpers.cropSurface(1, gears.surface.load_uncached(out.thumb))
	helpers.gc(widget, "icon").image = out.image
	helpers.gc(widget, "temp").markup = helpers.colorizeText(out.temp .. "°C", "#ffffff")
	helpers.gc(widget, "desc").markup = helpers.colorizeText(out.desc, "#ffffff")
	helpers.gc(widget, "humid").markup = helpers.colorizeText("Humidity: " .. out.humidity .. "%", "#ffffff")
	helpers.gc(widget, "fl").markup = helpers.colorizeText("Feels Like " .. out.temp .. "°C", "#ffffff")
	for i, j in ipairs(daylist) do
		j.update(out, i)
	end
end)

awesome.connect_signal("signal::weather1", function(out)
	helpers.gc(widget, "city").markup = helpers.colorizeText(out.namecountry, "#ffffff")
end)

return widget
