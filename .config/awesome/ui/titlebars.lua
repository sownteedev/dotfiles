local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local rubato = require("modules.rubato")

-- titlebars --

local create_button = function(color, func)
	local widget = wibox.widget {
		widget = wibox.container.background,
		forced_width = 22,
		forced_height = 24,
		bg = color,
		buttons = {
			awful.button({}, 1, function()
				func()
			end)
		}
	}

	local widget_anim = rubato.timed {
		duration = 0.3,
		easing = rubato.easing.linear,
		subscribed = function(h)
			widget.forced_height = h
	end}
	widget_anim.target = 24

	widget:connect_signal("mouse::enter", function()
		widget_anim.target = 38
	end)
	widget:connect_signal("mouse::leave", function()
		widget_anim.target = 24
	end)

	return widget
end

client.connect_signal("request::titlebars", function(c)

local minimize = create_button(beautiful.yellow,
	function ()
	gears.timer.delayed_call(function()
		c.minimized = not c.minimized
	end)
	end
)

local maximize = create_button(beautiful.green,
	function ()
		c.maximized = not c.maximized
	end
)

local close = create_button(beautiful.red,
	function ()
		c:kill()
	end
)

local buttons = gears.table.join(
	awful.button({ }, 1, function()
		client.focus = c
		c:raise()
		awful.mouse.client.move(c)
	end),
	awful.button({ }, 3, function()
		client.focus = c
		c:raise()
		awful.mouse.client.resize(c)
	end)
)

awful.titlebar(c, {
size = 36,
position = "left"
}):setup {
	layout = wibox.layout.align.vertical,
	{
		widget = wibox.container.place,
		valign = "top",
		{
			widget = wibox.container.margin,
			margins = {right = 12, left = 12, top = 12},
			{
				layout = wibox.layout.fixed.vertical,
				spacing = 8,
				maximize,
				minimize,
				close,
			}
		}
	},
	{
		widget = wibox.container.background,
		buttons = buttons,
	},
	{
		widget = wibox.container.background,
		buttons = buttons,
	},
}

end)
