local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")

local icon_dir = beautiful.icon_path .. "weather/icons/"

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
			halign = "center",
			markup = "",
			widget = wibox.widget.textbox,
			font = beautiful.sans .. " 13",
		},
		{
			id = "icon",
			resize = true,
			halign = "center",
			forced_height = 40,
			forced_width = 40,
			widget = wibox.widget.imagebox,
		},
		{
			{
				{
					id = "max",
					markup = "",
					widget = wibox.widget.textbox,
					font = beautiful.sans .. " 11",
				},
				{
					id = "/",
					markup = nil,
					widget = wibox.widget.textbox,
					font = beautiful.sans .. " 11",
				},
				{
					id = "min",
					markup = "",
					widget = wibox.widget.textbox,
					font = beautiful.sans .. " 11",
				},
				spacing = 5,
				layout = wibox.layout.fixed.horizontal,
			},
			widget = wibox.container.place,
		},
		spacing = 5,
		forced_width = 80,
		layout = wibox.layout.fixed.vertical,
	})

	widget.update = function(out, i)
		local day = out.daily[i]
		_Utils.widget.gc(widget, "icon").image = icon_dir .. icon_map[day.weather[1].icon] .. ".svg"
		_Utils.widget.gc(widget, "day").markup = _Utils.widget.colorizeText(os.date("%a", tonumber(day.dt)), "#ffffff")
		_Utils.widget.gc(widget, "min").markup = _Utils.widget.colorizeText(math.floor(day.temp.min), "#ffffff")
		_Utils.widget.gc(widget, "/").markup = _Utils.widget.colorizeText("/", beautiful.blue)
		_Utils.widget.gc(widget, "max").markup = _Utils.widget.colorizeText(math.floor(day.temp.max), "#ffffff")
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

return function(s)
	local weather = wibox({
		screen = s,
		width = 600,
		height = 300,
		shape = beautiful.radius,
		bg = beautiful.background,
		ontop = false,
		visible = true,
	})

	weather:setup({
		{
			id = "image",
			forced_height = 450,
			forced_width = 600,
			image = _Utils.image.cropSurface(1,
				gears.surface.load_uncached(beautiful.icon_path .. "weather/images/weather-clear-sky.jpg")
			),
			widget = wibox.widget.imagebox,
			clip_shape = beautiful.radius,
			resize = true,
			horizontal_fit_policy = "fit",
		},
		{
			id = "overlay",
			bg = "#00000066",
			widget = wibox.container.background,
		},
		{
			{
				{
					{
						{
							{
								{
									{
										image = beautiful.icon_path .. "weather/location.svg",
										forced_height = 25,
										forced_width = 25,
										valign = "top",
										widget = wibox.widget.imagebox,
									},
									{
										{
											id = "country",
											image = nil,
											forced_height = 5,
											forced_width = 5,
											valign = "bottom",
											widget = wibox.widget.imagebox,
										},
										margins = 6,
										widget = wibox.container.margin
									},
									layout = wibox.layout.stack,
								},
								forced_height = 43,
								widget = wibox.container.background,
							},
							{
								id = "city",
								font = beautiful.sans .. " Medium 18",
								markup = "",
								widget = wibox.widget.textbox,
							},
							spacing = 8,
							layout = wibox.layout.fixed.horizontal,
						},
						{
							id = "icon",
							image = beautiful.icon_path .. "weather/icons/weather-fog.svg",
							forced_height = 65,
							forced_width = 65,
							widget = wibox.widget.imagebox,
						},
						{
							id = "desc",
							font = beautiful.sans .. " 13",
							markup = "",
							widget = wibox.widget.textbox,
						},
						spacing = 10,
						layout = wibox.layout.fixed.vertical,
						halign = "left",
					},
					nil,
					{
						{
							{
								id = "temp",
								font = beautiful.sans .. " Medium 30",
								markup = "",
								widget = wibox.widget.textbox,
							},
							left = 5,
							widget = wibox.container.margin,
						},
						{
							{
								image = gears.color.recolor_image(beautiful.icon_path .. "weather/windspeed.svg",
									beautiful.yellow),
								forced_height = 20,
								forced_width = 20,
								valign = "center",
								widget = wibox.widget.imagebox,
							},
							{
								id = "fl",
								font = beautiful.sans .. " 13",
								markup = "",
								widget = wibox.widget.textbox,
							},
							spacing = 8,
							layout = wibox.layout.fixed.horizontal,
						},
						{
							{
								image = gears.color.recolor_image(beautiful.icon_path .. "weather/humidity.svg",
									beautiful.blue),
								forced_height = 20,
								forced_width = 20,
								valign = "center",
								widget = wibox.widget.imagebox,
							},
							{
								id = "humid",
								font = beautiful.sans .. " 13",
								markup = "",
								widget = wibox.widget.textbox,
							},
							spacing = 8,
							layout = wibox.layout.fixed.horizontal,
						},
						spacing = 15,
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
			left = 25,
			right = 25,
			top = 20,
			bottom = 20,
		},
		layout = wibox.layout.stack,
	})

	awesome.connect_signal("signal::weather", function(out)
		_Utils.widget.gc(weather, "image").image = _Utils.image.cropSurface(1, gears.surface.load_uncached(out.thumb))
		_Utils.widget.gc(weather, "icon").image = out.image
		_Utils.widget.gc(weather, "temp").markup = _Utils.widget.colorizeText(out.temp .. "°C", "#ffffff")
		_Utils.widget.gc(weather, "desc").markup = _Utils.widget.colorizeText(out.desc, "#ffffff")
		_Utils.widget.gc(weather, "humid").markup = _Utils.widget.colorizeText(out.humidity .. "%", "#ffffff")
		_Utils.widget.gc(weather, "fl").markup = _Utils.widget.colorizeText(out.wind_speed .. " km/h", "#ffffff")
		for i, j in ipairs(daylist) do
			j.update(out, i)
		end
	end)

	awesome.connect_signal("signal::weather1", function(out)
		_Utils.widget.gc(weather, "city").markup = _Utils.widget.colorizeText(out.city, "#ffffff")
		_Utils.widget.gc(weather, "country").image = beautiful.icon_path .. "weather/flag/" .. out.country .. ".svg"
	end)

	_Utils.widget.placeWidget(weather, "top_left", 13, 0, 2, 0)
	_Utils.widget.popupOpacity(weather, 0.3)

	return weather
end
