local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local rubato = require("modules.rubato")
local helpers = require("helpers")

-- osd --
local info = wibox.widget {
	layout = wibox.layout.fixed.horizontal,
	{
		widget = wibox.container.margin,
		margins = 20,
		{
			layout = wibox.layout.fixed.horizontal,
			fill_space = true,
			spacing = 5,
			{
				widget = wibox.widget.textbox,
				id = "icon",
				font = beautiful.icon_font .. " 13",
			},
			{
				widget = wibox.container.background,
				forced_width = 36,
				{
					widget = wibox.widget.textbox,
					id = "text",
					font = beautiful.font1 .. " 9",
					halign = "center"
				},
			},
			{
				widget = wibox.widget.progressbar,
				id = "progressbar",
				max_value = 100,
				forced_width = 300,
				forced_height = 10,
				background_color = beautiful.background_urgent,
				color = beautiful.accent,
			},
		}
	}
}

local osd = awful.popup {
	visible = false,
	ontop = true,
	border_width = beautiful.border_width,
	border_color = beautiful.border_color_normal,
	minimum_height = 50,
	maximum_height = 55,
	minimum_width = 300,
	maximum_width = 300,
	shape = helpers.rrect(5),
	placement = function(d)
		awful.placement.bottom(d, { honor_workarea = true, margins = 10 + beautiful.border_width * 2 })
	end,
	widget = info,
}

local anim = rubato.timed {
	duration = 0.3,
	easing = rubato.easing.linear,
	subscribed = function(value)
		info:get_children_by_id("progressbar")[1].value = value
	end
}

-- volume --

awesome.connect_signal("volume::value", function(value, icon)
	anim.target = value
	info:get_children_by_id("text")[1].text = value
	info:get_children_by_id("icon")[1].text = icon
end)

-- bright --

awesome.connect_signal("signal::brightness", function(value)
	anim.target = value
	info:get_children_by_id("text")[1].text = value
	info:get_children_by_id("icon")[1].text = "󰃝 "
end)

-- function --

local function osd_hide()
	osd.visible = false
	osd_timer:stop()
end

local osd_timer = gears.timer {
	timeout = 4,
	callback = osd_hide
}

local function osd_toggle()
	if not osd.visible then
		osd.visible = true
		osd_timer:start()
	else
		osd_timer:again()
	end
end

awesome.connect_signal("sowntee::osd", function()
	osd_toggle()
end)
