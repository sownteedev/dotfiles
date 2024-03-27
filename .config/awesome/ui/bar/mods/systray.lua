local awful = require("awful")
local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")

local togglertext = wibox.widget({
	font = beautiful.icon .. " 20",
	text = "󰅁",
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal("systray::toggle")
		end),
	},
	widget = wibox.widget.textbox,
})

local systray = wibox.widget({
	{
		{
			base_size = 30,
			widget = wibox.widget.systray,
		},
		widget = wibox.container.place,
		valign = "center",
	},
	visible = false,
	left = 5,
	right = 5,
	widget = wibox.container.margin,
})

awesome.connect_signal("systray::toggle", function()
	if systray.visible then
		systray.visible = false
		togglertext.text = "󰅁"
	else
		systray.visible = true
		togglertext.text = "󰅂"
	end
end)

local widget = wibox.widget({
	{
		{
			systray,
			togglertext,
			layout = wibox.layout.fixed.horizontal,
		},
		shape = helpers.rrect(2),
		bg = beautiful.lighter,
		widget = wibox.container.background,
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
})
return widget
