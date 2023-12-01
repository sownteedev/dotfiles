local beautiful = require('beautiful')
local wibox = require('wibox')
local dpi = beautiful.xresources.apply_dpi

local helpers = require('helpers.mplayer')

local close = helpers.textbox(beautiful.red, beautiful.icon_font .. " bold 10", " ")
local pin_top = helpers.textbox(beautiful.green, beautiful.icon_font .. " bold 10", " ")
local pin_bottom = helpers.textbox(beautiful.yellow, beautiful.icon_font .. " bold 10", " ")

local add_signal = function(button, signal)
	button:connect_signal("button::release", function()
		awesome.emit_signal(signal)
	end)
end

add_signal(close, "mplayer::close")
add_signal(pin_top, "mplayer::pin_top")
add_signal(pin_bottom, "mplayer::pin_bottom")

local titlebar = wibox.widget {
	{
		{
			helpers.textbox(beautiful.blue, beautiful.font1 .. " bold 10", "Music Player"),
			nil,
			{ pin_top, pin_bottom, close, layout = wibox.layout.fixed.horizontal },
			layout = wibox.layout.align.horizontal
		},
		widget = wibox.container.margin,
		margins = dpi(10)
	},
	widget = wibox.container.background,
	bg = beautiful.background_alt
}

return titlebar
