local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local rubato = require("modules.rubato")

-- osd --

local info = wibox.widget {
	layout = wibox.layout.fixed.horizontal,
	{
		widget = wibox.container.margin,
		margins = 20,
		{
			layout = wibox.layout.fixed.horizontal,
			fill_space = true,
			spacing = 8,
			{
				widget = wibox.widget.textbox,
				id = "icon",
				font = beautiful.font .. " 14",
			},
			{
				widget = wibox.container.background,
				forced_width = 36,
				{
					widget = wibox.widget.textbox,
					id = "text",
					halign = "center"
				},
			},
			{
				widget = wibox.widget.progressbar,
				id = "progressbar",
				max_value = 100,
				forced_width = 380,
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
	minimum_height = 60,
	maximum_height = 60,
	minimum_width = 290,
	maximum_width = 290,
	placement = function(d)
		awful.placement.bottom(d, { margins = 20 + beautiful.border_width * 2 })
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

awesome.connect_signal("bright::value", function(value)
	anim.target = value
	info:get_children_by_id("text")[1].text = value
	info:get_children_by_id("icon")[1].text = ""
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

awesome.connect_signal("summon::osd", function()
	osd_toggle()
end)
