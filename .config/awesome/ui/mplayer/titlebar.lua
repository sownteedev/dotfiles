local beautiful = require('beautiful')
local wibox = require('wibox')
local dpi = beautiful.xresources.apply_dpi

<<<<<<< HEAD
local helpers = require('helpers')

local close = helpers.textbox(beautiful.red, "Ubuntu nerd font bold 16", "  ")
local pin_top = helpers.textbox(beautiful.green, "Ubuntu nerd font bold 16", "  ")
local pin_bottom = helpers.textbox(beautiful.yellow, "Ubuntu nerd font bold 16", "  ")
=======
local helpers = require('helpers.mplayer')

local close = helpers.textbox(beautiful.red, "Liga SFMono Nerd Font bold 10", " ")
local pin_top = helpers.textbox(beautiful.green, "Liga SFMono Nerd Font bold 10", " ")
local pin_bottom = helpers.textbox(beautiful.yellow, "Liga SFMono Nerd Font bold 10", " ")
>>>>>>> temp-branch

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
<<<<<<< HEAD
			helpers.textbox(beautiful.blue, "Ubuntu nerd font bold 13", "Music Player"),
=======
			helpers.textbox(beautiful.blue, "Liga SFMono Nerd Font bold 10", "Music Player"),
>>>>>>> temp-branch
			nil,
			{ pin_top, pin_bottom, close, layout = wibox.layout.fixed.horizontal },
			layout = wibox.layout.align.horizontal
		},
		widget = wibox.container.margin,
		margins = dpi(15)
	},
	widget = wibox.container.background,
	bg = beautiful.background
}

return titlebar
