local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")
local animation = require("modules.animation")

-- osd --
local info = wibox.widget({
	{
		{
			widget = wibox.widget.textbox,
			id = "icon",
			font = beautiful.icon .. " 20",
		},
		{
			widget = wibox.container.background,
			forced_width = 40,
			{
				widget = wibox.widget.textbox,
				id = "text",
				font = beautiful.sans .. " 15",
			},
		},
		{
			{
				widget = wibox.widget.progressbar,
				id = "progressbar",
				max_value = 100,
				forced_width = 350,
				shape = helpers.rrect(5),
				background_color = beautiful.lighter,
				color = beautiful.foreground,
				bar_shape = helpers.rrect(5),
			},
			widget = wibox.container.margin,
			top = 10,
			bottom = 10,
		},
		layout = wibox.layout.fixed.horizontal,
		spacing = 10,
	},
	widget = wibox.container.margin,
	margins = 25,
})

local osd = awful.popup({
	visible = false,
	ontop = true,
	bg = beautiful.darker,
	border_width = beautiful.border_width,
	border_color = beautiful.border_color_normal,
	minimum_height = 80,
	maximum_height = 80,
	forced_width = 0,
	shape = helpers.rrect(5),
	placement = function(d)
		awful.placement.bottom(d, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	end,
	widget = info,
})

local anim = animation:new({
	duration = 0.3,
	easing = animation.easing.linear,
	subscribed = function(value)
		info:get_children_by_id("progressbar")[1].value = value
	end,
})

-- volume --
awesome.connect_signal("signal::volume", function(value)
	anim:set(value)
	info:get_children_by_id("text")[1].text = value
	if value > 66 then
		info:get_children_by_id("icon")[1].text = " "
	elseif value > 33 then
		info:get_children_by_id("icon")[1].text = "󰕾 "
	elseif value > 0 then
		info:get_children_by_id("icon")[1].text = " "
	else
		info:get_children_by_id("icon")[1].text = "󰖁 "
	end
end)
awesome.connect_signal("signal::volumemute", function(value)
	if value then
		info:get_children_by_id("icon")[1].text = "󰖁 "
	end
end)

-- bright --
awesome.connect_signal("signal::brightness", function(value)
	anim:set(value)
	info:get_children_by_id("text")[1].text = value
	if value > 90 then
		info:get_children_by_id("icon")[1].text = "󰃠 "
	elseif value > 60 then
		info:get_children_by_id("icon")[1].text = "󰃟 "
	elseif value > 30 then
		info:get_children_by_id("icon")[1].text = "󰃝 "
	elseif value > 10 then
		info:get_children_by_id("icon")[1].text = "󰃞 "
	end
end)

-- function --

local function osd_hide()
	osd.visible = false
	osd_timer:stop()
end

local osd_timer = gears.timer({
	timeout = 4,
	callback = osd_hide,
})

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
