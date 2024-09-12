local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

local focus = wibox.widget({
	{
		{
			{
				id = "iconfocus",
				image = gears.color.recolor_image(beautiful.icon_path .. "controlcenter/focus.svg",
					beautiful.foreground),
				resize = true,
				forced_height = 20,
				forced_width = 20,
				align = "center",
				widget = wibox.widget.imagebox,
			},
			margins = 15,
			widget = wibox.container.margin,
		},
		id = "backfocus",
		shape = helpers.rrect(100),
		bg = helpers.change_hex_lightness(beautiful.background, 8),
		widget = wibox.container.background,
		buttons = {
			awful.button({}, 1, function()
				awful.spawn.with_shell("awesome-client 'dnd_toggle()' &")
			end),
		}
	},
	{
		{
			{
				markup = "Focus",
				font = beautiful.sans .. " Medium 12",
				widget = wibox.widget.textbox,
			},
			{
				id = "labelfocus",
				markup = "Off",
				font = beautiful.sans .. " 9",
				widget = wibox.widget.textbox,
			},
			spacing = 5,
			layout = wibox.layout.fixed.vertical,
		},
		halign = "left",
		valign = "center",
		widget = wibox.container.place,
	},
	spacing = 20,
	layout = wibox.layout.fixed.horizontal,
})
awesome.connect_signal("signal::dnd", function(status, _, _)
	if status then
		helpers.gc(focus, "backfocus"):set_bg(beautiful.blue)
		helpers.gc(focus, "iconfocus"):set_image(gears.color.recolor_image(beautiful.icon_path .. "focus.svg",
			beautiful.background))
		helpers.gc(focus, "labelfocus"):set_markup("On")
	else
		helpers.gc(focus, "backfocus"):set_bg(helpers.change_hex_lightness(beautiful.background, 8))
		helpers.gc(focus, "iconfocus"):set_image(gears.color.recolor_image(beautiful.icon_path .. "focus.svg",
			beautiful.foreground))
		helpers.gc(focus, "labelfocus"):set_markup("Off")
	end
end)

local redshift = wibox.widget({
	{
		{
			{
				{
					id = "iconredshift",
					image = gears.color.recolor_image(
						beautiful.icon_path .. "controlcenter/nightshift.svg",
						beautiful.foreground),
					resize = true,
					forced_height = 20,
					forced_width = 20,
					align = "center",
					widget = wibox.widget.imagebox,
				},
				margins = 15,
				widget = wibox.container.margin,
			},
			id = "backredshift",
			shape = helpers.rrect(100),
			bg = helpers.change_hex_lightness(beautiful.background, 8),
			widget = wibox.container.background,
			buttons = {
				awful.button({}, 1, function()
					awful.spawn.with_shell("awesome-client 'redshift_toggle()' &")
				end),
			}
		},
		align = "center",
		widget = wibox.container.place,
	},
	{
		markup = "Night",
		font = beautiful.sans .. " Medium 12",
		align = "center",
		widget = wibox.widget.textbox,
	},
	spacing = 15,
	layout = wibox.layout.fixed.vertical,
})
awesome.connect_signal("signal::redshift", function(status, _, _)
	if status then
		helpers.gc(redshift, "backredshift"):set_bg(beautiful.blue)
		helpers.gc(redshift, "iconredshift"):set_image(gears.color.recolor_image(
			beautiful.icon_path .. "nightshift.svg",
			beautiful.background))
	else
		helpers.gc(redshift, "backredshift"):set_bg(helpers.change_hex_lightness(beautiful.background, 8))
		helpers.gc(redshift, "iconredshift"):set_image(
			gears.color.recolor_image(beautiful.icon_path .. "nightshift.svg",
				beautiful.foreground
			))
	end
end)

local blur = wibox.widget({
	{
		{
			{
				{
					id = "iconblur",
					image = gears.color.recolor_image(
						beautiful.icon_path .. "controlcenter/blur.svg",
						beautiful.foreground),
					resize = true,
					forced_height = 20,
					forced_width = 20,
					align = "center",
					widget = wibox.widget.imagebox,
				},
				margins = 15,
				widget = wibox.container.margin,
			},
			id = "backblur",
			shape = helpers.rrect(100),
			bg = helpers.change_hex_lightness(beautiful.background, 8),
			widget = wibox.container.background,
			buttons = {
				awful.button({}, 1, function()
					awful.spawn.with_shell("awesome-client 'blur_toggle()' &")
				end),
			}
		},
		align = "center",
		widget = wibox.container.place,
	},
	{
		markup = "Blur",
		font = beautiful.sans .. " Medium 12",
		align = "center",
		widget = wibox.widget.textbox,
	},
	spacing = 15,
	layout = wibox.layout.fixed.vertical,
})
awesome.connect_signal("signal::blur", function(status, _, _)
	if status then
		helpers.gc(blur, "backblur"):set_bg(beautiful.blue)
		helpers.gc(blur, "iconblur"):set_image(
			gears.color.recolor_image(beautiful.icon_path .. "blur.svg",
				beautiful.background))
	else
		helpers.gc(blur, "backblur"):set_bg(helpers.change_hex_lightness(beautiful.background, 8))
		helpers.gc(blur, "iconblur"):set_image(
			gears.color.recolor_image(beautiful.icon_path .. "blur.svg",
				beautiful.foreground))
	end
end)

helpers.hoverCursor(focus, "backfocus")
helpers.hoverCursor(redshift, "backredshift")
helpers.hoverCursor(blur, "backblur")

local dndblurnight = wibox.widget({
	{
		{
			{
				focus,
				margins = 25,
				widget = wibox.container.margin,
			},
			shape = helpers.rrect(10),
			bg = helpers.change_hex_lightness(beautiful.background, 4),
			widget = wibox.container.background,
		},
		{
			{
				{
					redshift,
					margins = 20,
					widget = wibox.container.margin,
				},
				forced_width = 110,
				shape = helpers.rrect(10),
				bg = helpers.change_hex_lightness(beautiful.background, 4),
				widget = wibox.container.background,
			},
			{
				{
					blur,
					margins = 20,
					widget = wibox.container.margin,
				},
				forced_width = 110,
				shape = helpers.rrect(10),
				bg = helpers.change_hex_lightness(beautiful.background, 4),
				widget = wibox.container.background,
			},
			spacing = 15,
			layout = wibox.layout.fixed.horizontal,
		},
		layout = wibox.layout.fixed.vertical,
		spacing = 15,
	},
	forced_width = 230,
	widget = wibox.container.background,
})

return dndblurnight
