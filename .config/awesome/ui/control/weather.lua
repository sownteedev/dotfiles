local wibox = require("wibox")
local awful = require("awful")
local helpers = require("helpers")
local beautiful = require "beautiful"

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

local helpers_split = function(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end


local createWeatherProg = function()

	local widget = wibox.widget {
		spacing = 6,
		layout = wibox.layout.fixed.vertical,
		{
			id = "time",
			halign = 'center',
			widget = wibox.widget.textbox,
			font = beautiful.font .. " 10",
		},
		{
			id = "icon",
			font = beautiful.font.. " 20",
			halign = 'center',
			widget = wibox.widget.textbox
		},
		{
			id = "temp",
			halign = "center",
			font = beautiful.font.. " 10",
			widget = wibox.widget.textbox
		},
	}

	widget.update = function(out, i)
		local hour = out.hourly[i]
		widget:get_children_by_id('temp')[1].markup = helpers.ui.colorizeText(math.floor(hour.temp) .. "°C", beautiful.foreground)
		widget:get_children_by_id('icon')[1].text = icon_map[hour.weather[1].icon]
		widget:get_children_by_id('time')[1].text = os.date("%Hh", tonumber(hour.dt))
	end

  return widget
end

local hour1 = createWeatherProg()
local hour2 = createWeatherProg()
local hour3 = createWeatherProg()
local hour4 = createWeatherProg()
local hour5 = createWeatherProg()
local hour6 = createWeatherProg()
local hour7 = createWeatherProg()
local hour8 = createWeatherProg()
local hour9 = createWeatherProg()

local hourList = { hour1, hour2, hour3, hour4, hour5, hour6, hour7, hour8, hour9}

local dayWeather        = function()
  local widget = wibox.widget {
    {
      id = "day",
      halign = 'center',
      widget = wibox.widget.textbox,
      font = beautiful.font .. " 10",
    },
    {
			id = "icon",
			font = beautiful.font.. " 20",
			halign = 'center',
			widget = wibox.widget.textbox
		},
    {
        {
          {
            id = "max",
            halign = 'center',
            widget = wibox.widget.textbox,
            font = beautiful.font .. " 10",
          },
          {
            halign = 'center',
            markup = helpers.ui.colorizeText("/", beautiful.background_urgent),
            widget = wibox.widget.textbox,
            font = beautiful.font .. " 10",
          },
          {
            id = "min",
            halign = 'center',
            widget = wibox.widget.textbox,
            font = beautiful.font .. " 10",
          },
          spacing = 6,
          layout = wibox.layout.fixed.horizontal,
        },
        widget = wibox.container.place,
        halign = 'center',
      },
    spacing = 6,
	forced_width = 120,
    layout = wibox.layout.fixed.vertical,
  }

  widget.update = function(out, i)
    local day = out.daily[i]
    widget:get_children_by_id('icon')[1].text = icon_map[day.weather[1].icon]
    widget:get_children_by_id('day')[1].text = os.date("%a", tonumber(day.dt))
    local getTemp = function(temp)
      local sp = helpers_split(temp, '.')[1]
      return sp
    end
    widget:get_children_by_id('min')[1].markup = getTemp(helpers.ui.colorizeText(math.floor(day.temp.night) .. "°C", beautiful.foreground))
    widget:get_children_by_id('max')[1].markup = getTemp(helpers.ui.colorizeText(math.floor(day.temp.day) .. "°C", beautiful.foreground))
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

local widget = wibox.widget {
	widget = wibox.container.background,
	bg = beautiful.background_alt,
	{
		widget = wibox.container.margin,
		margins = 10,
		{
			layout = wibox.layout.fixed.vertical,
			{
				layout = wibox.layout.align.horizontal,
				{
					layout = wibox.layout.fixed.vertical,
					spacing = 10,
					{
						widget = wibox.container.background,
						forced_width = 76,
						id = "days_button",
						forced_height = 30,
						{
							widget = wibox.container.margin,
							margins = 6,
							{
								widget = wibox.widget.textbox,
								halign = "center",
								text = "days",
							}
						}
					},
					{
						widget = wibox.container.background,
						forced_width = 76,
						id = "hours_button",
						forced_height = 30,
						{
							widget = wibox.container.margin,
							margins = 6,
							{
								widget = wibox.widget.textbox,
								halign = "center",
								text = "hours",
							}
						}
					}
				},
				{
					layout = wibox.layout.fixed.horizontal,
					{
						widget = wibox.container.margin,
					 	left = 16,
						{
							id = "weathericon",
							forced_width = 70,
							forced_height = 70,
							halign = 'center',
							font = beautiful.font.. " 34",
							widget = wibox.widget.textbox
						},
					}
				},
				{
					spacing = 4,
					layout = wibox.layout.fixed.vertical,
					{
						id = "temp",
						halign = 'right',
						font = beautiful.font.. " 18",
						widget = wibox.widget.textbox,
						markup = helpers.ui.colorizeText("Hello", beautiful.foreground)
					},
					{
						id = "desc",
						halign = 'right',
						widget = wibox.widget.textbox,
						markup = helpers.ui.colorizeText("Hello", beautiful.foreground)
					},
				},
			},
			{
				widget = wibox.container.margin,
				top = 10,
			{
				widget = wibox.container.place,
				align = "center",
				{
					layout = require("modules.overflow").horizontal,
					forced_width = 450,
					step = 70,
					id = "hours",
					visible = true,
					scrollbar_enabled = false,
					spacing = 24,
					hour1,
					hour2,
					hour3,
					hour4,
					hour5,
					hour6,
					hour7,
					hour8,
					hour9,
				}
			},
			},
			{
				layout = require("modules.overflow").horizontal,
				forced_width = 450,
				step = 50,
				scrollbar_enabled = false,
				id = "days",
				visible = false,
				day1,
				day2,
				day3,
				day4,
				day5,
				day6,
			}
		}
	}
}

awesome.connect_signal("connect::weather", function(out)
	widget:get_children_by_id('weathericon')[1].text = out.image
	widget:get_children_by_id('desc')[1].markup = helpers.ui.colorizeText(string.lower(out.desc), beautiful.foreground)
	widget:get_children_by_id('temp')[1].markup = helpers.ui.colorizeText(out.temp .. "°C", beautiful.foreground)
	-- widget:get_children_by_id('feels')[1].markup = "Feels like " .. out.feelsLike .. "°C"
	--widget:get_children_by_id('humid')[1].markup = "Humidity: " .. out.humidity .. "%"
	for i, j in ipairs(hourList) do
		j.update(out, i)
	end
	for i, j in ipairs(daylist) do
    j.update(out, i)
  end
end)

widget:get_children_by_id('hours_button')[1]:set_bg(beautiful.background_urgent)

widget:get_children_by_id('days_button')[1]:buttons {
	awful.button({}, 1, function()
		widget:get_children_by_id('days_button')[1]:set_bg(beautiful.background_urgent)
		widget:get_children_by_id('days')[1].visible = true
		widget:get_children_by_id('hours_button')[1]:set_bg(beautiful.background_alt)
		widget:get_children_by_id('hours')[1].visible = false
	end)
}

widget:get_children_by_id('hours_button')[1]:buttons {
	awful.button({}, 1, function()
		widget:get_children_by_id('hours_button')[1]:set_bg(beautiful.background_urgent)
		widget:get_children_by_id('hours')[1].visible = true
		widget:get_children_by_id('days_button')[1]:set_bg(beautiful.background_alt)
		widget:get_children_by_id('days')[1].visible = false
	end)
}

return widget
