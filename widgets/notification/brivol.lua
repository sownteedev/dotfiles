local M = {}
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
			font = beautiful.icon .. " 23",
			markup = "",
		},
		{
			widget = wibox.container.background,
			forced_width = 35,
			{
				widget = wibox.widget.textbox,
				id = "text",
				font = beautiful.sans .. " 14",
			},
		},
		{
			{
				widget = wibox.widget.progressbar,
				id = "progressbar",
				max_value = 100,
				forced_width = 350,
				shape = helpers.rrect(10),
				background_color = beautiful.foreground .. "11",
				color = beautiful.foreground,
				bar_shape = helpers.rrect(10),
			},
			widget = wibox.container.margin,
			top = 28,
			bottom = 28,
		},
		layout = wibox.layout.fixed.horizontal,
		spacing = 10,
	},
	widget = wibox.container.margin,
	left = 30,
	right = 30,
})

local osd = awful.popup({
	visible = false,
	ontop = true,
	bg = beautiful.background,
	minimum_height = 75,
	maximum_height = 75,
	forced_width = 0,
	shape = helpers.rrect(10),
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
		helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰖁 ", beautiful.red))
	end
end)

local function hide()
	osd.visible = false
	osd_timer:stop()
end

local osd_timer = gears.timer({
	timeout = 4,
	single_shot = true,
	callback = hide,
})

function M.toggle()
	if not osd.visible then
		osd.visible = true
		osd_timer:start()
	else
		osd_timer:again()
	end
end

return M
