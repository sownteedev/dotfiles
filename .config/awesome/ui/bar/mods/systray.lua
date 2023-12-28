local awful       = require("awful")
local beautiful   = require("beautiful")
local helpers     = require("helpers")
local wibox       = require("wibox")

local togglertext = wibox.widget {
	font = beautiful.icon .. " 15",
	text = "󰅁",
	valign = "center",
	align = "center",
	buttons = {
		awful.button({}, 1, function()
			awesome.emit_signal('systray::toggle')
		end)
	},
	widget = wibox.widget.textbox,
}

local systray     = wibox.widget {
	{
		{
			base_size = 18,
			widget = wibox.widget.systray,
		},
		widget = wibox.container.place,
		valign = "center",
	},
	visible = false,
	left = 10,
	right = 8,
	widget = wibox.container.margin
}

awesome.connect_signal('systray::toggle', function()
	if systray.visible then
		systray.visible = false
		togglertext.text = '󰅁'
	else
		systray.visible = true
		togglertext.text = '󰅂'
	end
end)

local widget = wibox.widget {
	{
		{
			systray,
			togglertext,
			layout = wibox.layout.fixed.horizontal,
		},
		shape = helpers.rrect(2),
		bg = beautiful.background_alt,
		widget = wibox.container.background,
	},
	margins = 0,
	widget  = wibox.container.margin,
}
return widget
