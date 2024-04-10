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
		local cmd = "convert " .. beautiful.wallpaper .. " -filter Gaussian -blur 0x6 ~/.cache/awesome/exit.jpg &"
		awful.spawn.easy_async_with_shell(cmd, function()
			local blurwall = gears.filesystem.get_cache_dir() .. "exit.jpg"
			back.image = blurwall
		end)
	end

	makeImage()

	local createButton = function(path, cmd, color)
		local widget = wibox.widget({
			{
				{
					{
						id = "icon",
						image = path,
						resize = true,
						forced_height = 120,
						forced_width = 120,
						valign = "center",
						widget = wibox.widget.imagebox,
					},
					id = "margin",
					widget = wibox.container.margin,
					left = 110,
					right = 110,
					top = 90,
					bottom = 90,
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
					awful.spawn.easy_async_with_shell(cmd)
				end),
			},
			layout = wibox.layout.fixed.vertical,
		})
		helpers.addHover(widget, beautiful.background, helpers.blend(color, beautiful.background, 0.1))
		if
			path == gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/power.png"
			or path == gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/sleep.png"
		then
			helpers.gc(widget, "icon").forced_width = 90
			helpers.gc(widget, "icon").forced_height = 90
			helpers.gc(widget, "margin").left = 125
			helpers.gc(widget, "margin").right = 125
			helpers.gc(widget, "margin").top = 105
			helpers.gc(widget, "margin").bottom = 105
		end
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
			createButton(
				gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/power.png",
				"poweroff &",
				beautiful.red
			),
			createButton(
				gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/restart.png",
				"reboot &",
				beautiful.green
			),
			createButton(
				gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/lock.png",
				"awesome-client \"awesome.emit_signal('toggle::lock')\" &",
				beautiful.blue
			),
			createButton(
				gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/sleep.png",
				"systemctl suspend &",
				helpers.makeColor("purple")
			),
			createButton(
				gears.filesystem.get_configuration_dir() .. "/themes/assets/buttons/logout.png",
				"loginctl kill-user $USER &",
				beautiful.yellow
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
