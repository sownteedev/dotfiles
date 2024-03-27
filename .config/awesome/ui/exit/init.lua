local wibox = require("wibox")
local helpers = require("helpers")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

local bat = require("ui.exit.mods.battery")
local weather = require("ui.exit.mods.weather")
local top = require("ui.exit.mods.topbar")
local music = require("ui.exit.mods.music")

awful.screen.connect_for_each_screen(function(s)
	local exit = wibox({
		screen = s,
		width = beautiful.width,
		height = beautiful.height,
		bg = beautiful.background .. "00",
		ontop = true,
		visible = false,
	})

	local back = wibox.widget({
		id = "bg",
		image = beautiful.wallpaper,
		widget = wibox.widget.imagebox,
		forced_width = beautiful.width,
		forced_height = beautiful.height,
		horizontal_fit_policy = "fit",
		vertical_fit_policy = "fit",
	})

	local overlay = wibox.widget({
		widget = wibox.container.background,
		forced_width = beautiful.width,
		forced_height = beautiful.height,
		bg = beautiful.background .. "d1",
	})
	local makeImage = function()
		local cmd = "convert " .. beautiful.wallpaper .. " -filter Gaussian -blur 0x6 ~/.cache/awesome/exit.jpg"
		awful.spawn.easy_async_with_shell(cmd, function()
			local blurwall = gears.filesystem.get_cache_dir() .. "exit.jpg"
			back.image = blurwall
		end)
	end

	makeImage()

	local createButton = function(icon, name, cmd, color)
		local widget = wibox.widget({
			{
				{
					{
						id = "icon",
						markup = helpers.colorizeText(icon, color),
						font = beautiful.icon .. " 60",
						widget = wibox.widget.textbox,
					},
					widget = wibox.container.margin,
					margins = {
						left = 100,
						right = 60,
						top = 60,
						bottom = 60,
					},
				},
				shape = helpers.rrect(15),
				widget = wibox.container.background,
				bg = beautiful.background,
				id = "bg",
				shape_border_color = color,
				shape_border_width = 2,
			},
			buttons = {
				awful.button({}, 1, function()
					awesome.emit_signal("toggle::exit")
					awful.spawn.with_shell(cmd)
				end),
			},
			layout = wibox.layout.fixed.vertical,
		})
		widget:connect_signal("mouse::enter", function()
			helpers.gc(widget, "bg").bg = helpers.blend(color, beautiful.background, 0.1)
		end)
		widget:connect_signal("mouse::leave", function()
			helpers.gc(widget, "bg").bg = beautiful.background
		end)
		return widget
	end

	local time = wibox.widget({
		{
			markup = helpers.colorizeText("󰀠 ", beautiful.blue),
			font = beautiful.icon .. " 50",
			widget = wibox.widget.textbox,
		},
		{
			font = beautiful.sans .. " 25",
			format = "%I:%M %p",
			widget = wibox.widget.textclock,
		},
		layout = wibox.layout.fixed.horizontal,
	})

	local down = wibox.widget({
		{
			{
				music,
				time,
				bat,
				weather,
				layout = wibox.layout.fixed.horizontal,
				spacing = 100,
			},
			widget = wibox.container.place,
			valign = "bottom",
		},
		widget = wibox.container.margin,
		bottom = 60,
	})

	local buttons = wibox.widget({
		{
			createButton("󰐥 ", "Power", "poweroff", beautiful.red),
			createButton(" ", "Reboot", "reboot", beautiful.yellow),
			createButton("󰍁 ", "Lock", "awesome-client \"awesome.emit_signal('toggle::lock')\"", beautiful.blue),
			createButton("󰖔 ", "Sleep", "systemctl suspend", beautiful.green),
			createButton(
				"󰈆 ",
				"Log Out",
				"loginctl kill-user $USER",
				helpers.mix(beautiful.red, beautiful.yellow, 0.5)
			),
			layout = wibox.layout.fixed.horizontal,
			spacing = 40,
		},
		widget = wibox.container.place,
	})

	exit:setup({
		back,
		overlay,
		top,
		buttons,
		down,
		widget = wibox.layout.stack,
	})
	awful.placement.centered(exit)
	awesome.connect_signal("toggle::exit", function()
		exit.visible = not exit.visible
	end)
end)
