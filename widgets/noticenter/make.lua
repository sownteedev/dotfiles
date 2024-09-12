local helpers = require("helpers")
local beautiful = require("beautiful")
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")

return function(icon, n)
	local action_widget = {
		{
			id = "text_role",
			align = "center",
			font = beautiful.sans .. " 12",
			widget = wibox.widget.textbox,
		},
		bg = helpers.change_hex_lightness(beautiful.background, 8),
		forced_height = 30,
		shape = helpers.rrect(5),
		widget = wibox.container.background,
	}
	local actions       = wibox.widget({
		notification = n,
		base_layout = wibox.widget({
			spacing = 30,
			layout = wibox.layout.flex.horizontal,
		}),
		align = "center",
		widget_template = action_widget,
		style = { underline_normal = false, underline_selected = true },
		widget = naughty.list.actions,
	})

	local icon_widget   = wibox.widget({
		widget = wibox.widget.imagebox,
		image = helpers.cropSurface(1, gears.surface.load_uncached(icon)),
		resize = true,
		clip_shape = gears.shape.circle,
	})

	local title_widget  = wibox.widget({
		{
			markup = n.title,
			font = beautiful.sans .. " Medium 15",
			align = "right",
			widget = wibox.widget.textbox,
		},
		forced_width = 250,
		widget = wibox.container.scroll.horizontal,
		step_function = wibox.container.scroll.step_functions.nonlinear_back_and_forth,
		speed = 40,
	})

	local time_widget   = wibox.widget({
		markup = helpers.colorizeText(os.date("%H:%M"), beautiful.foreground .. "BF"),
		font = beautiful.sans .. " Medium 11",
		halign = "right",
		widget = wibox.widget.textbox,
	})

	local text_notif    = wibox.widget({
		{
			markup = helpers.colorizeText("<span weight='normal'>" .. n.message .. "</span>", beautiful.foreground),
			font = beautiful.sans .. " 12",
			align = "left",
			wrap = "char",
			widget = wibox.widget.textbox,
		},
		forced_width = 300,
		layout = wibox.layout.fixed.horizontal,
	})

	local box           = wibox.widget({
		widget = wibox.container.background,
		forced_height = 180,
		shape = beautiful.radius,
		bg = helpers.change_hex_lightness(beautiful.background, 4),
		{
			{
				icon_widget,
				{
					{
						title_widget,
						nil,
						time_widget,
						layout = wibox.layout.align.horizontal,
					},
					text_notif,
					actions,
					layout = wibox.layout.align.vertical,
				},
				spacing = 30,
				layout = wibox.layout.fixed.horizontal,
				expand = "none",
			},
			widget = wibox.container.margin,
			margins = 20,
		},
	})

	box:buttons(gears.table.join(awful.button({}, 1, function()
		_G.notif_center_remove_notif(box)
	end)))

	helpers.hoverCursor(box)

	return box
end
