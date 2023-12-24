local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local animation = require("modules.animation")
local helpers = require("helpers")

function update_value_of_volume()
	awful.spawn.easy_async_with_shell("pamixer --get-volume && pamixer --get-mute",
		function(stdout)
			local value, muted = string.match(stdout, '(%d+)\n(%a+)')
			value = tonumber(value)
			local icon = ""
			if value == 0 or muted == "true" then
				icon = "󰖁 "
				value = 0
			elseif value <= 33 then
				icon = " "
			elseif value <= 66 then
				icon = "󰕾 "
			else
				icon = " "
			end
			awesome.emit_signal("volume::value", value, icon)
		end)
end

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
					font = beautiful.sans .. " 9",
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
	bg = beautiful.background_dark,
	border_width = beautiful.border_width,
	border_color = beautiful.border_color_normal,
	minimum_height = 50,
	maximum_height = 55,
	minimum_width = 300,
	maximum_width = 300,
	shape = helpers.rrect(5),
	placement = function(d)
		awful.placement.bottom(d, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	end,
	widget = info,
}

local anim = animation:new {
	duration = 0.3,
	easing = animation.easing.linear,
	subscribed = function(value)
		info:get_children_by_id("progressbar")[1].value = value
	end
}

-- volume --

awesome.connect_signal("volume::value", function(value, icon)
	anim:set(value)
	info:get_children_by_id("text")[1].text = value
	info:get_children_by_id("icon")[1].text = icon
end)

-- bright --

awesome.connect_signal("signal::brightness", function(value)
	anim:set(value)
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
