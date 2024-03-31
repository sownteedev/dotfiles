local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")
local animation = require("modules.animation")

local info = wibox.widget({
	{
		{
			widget = wibox.widget.textbox,
			id = "icon",
			font = beautiful.icon .. " 20",
			markup = "",
		},
		{
			widget = wibox.container.background,
			forced_width = 35,
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
				background_color = beautiful.foreground .. "11",
				color = beautiful.foreground,
				bar_shape = helpers.rrect(5),
			},
			widget = wibox.container.margin,
			top = 35,
			bottom = 35,
		},
		layout = wibox.layout.fixed.horizontal,
		spacing = 15,
	},
	widget = wibox.container.margin,
	left = 30,
	right = 30,
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
		helpers.placeWidget(d, "bottom")
	end,
	widget = info,
})

local anim = animation:new({
	duration = 0.3,
	easing = animation.easing.linear,
	subscribed = function(value)
		helpers.gc(info, "progressbar"):set_value(value)
	end,
})

-- volume --
awesome.connect_signal("signal::volume", function(value)
	anim:set(value)
	helpers.gc(info, "text").text = value
	if value > 66 then
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText(" ", beautiful.foreground))
	elseif value > 33 then
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰕾 ", beautiful.foreground))
	elseif value > 0 then
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText(" ", beautiful.foreground))
	else
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰖁 ", beautiful.foreground))
	end
end)
awesome.connect_signal("signal::volumemute", function(value)
	if value then
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰖁 ", beautiful.foreground))
	end
end)

-- bright --
awesome.connect_signal("signal::brightness", function(value)
	anim:set(value)
	helpers.gc(info, "text").text = value
	if value > 90 then
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰃠 ", beautiful.foreground))
	elseif value > 60 then
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰃝 ", beautiful.foreground))
	elseif value > 30 then
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰃟 ", beautiful.foreground))
	elseif value > 10 then
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰃞 ", beautiful.foreground))
	end
end)

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
