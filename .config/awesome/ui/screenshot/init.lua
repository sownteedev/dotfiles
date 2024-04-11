local wibox = require("wibox")
local helpers = require("helpers")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local animation = require("modules.animation")
local screenshot = require("ui.screenshot.mods")

local createButton = function(path, name, fn, col)
	local button = wibox.widget({
		{
			{
				{
					{
						image = path,
						forced_width = 50,
						forced_height = 50,
						resize = true,
						widget = wibox.widget.imagebox,
						halign = "center",
					},
					{
						font = beautiful.sans .. " 15",
						markup = name,
						align = "center",
						widget = wibox.widget.textbox,
					},
					layout = wibox.layout.fixed.vertical,
					spacing = 20,
				},
				widget = wibox.container.margin,
				margins = 15,
			},
			forced_width = 130,
			bg = beautiful.background,
			id = "bg",
			widget = wibox.container.background,
		},
		{
			forced_height = 5,
			forced_width = 130,
			bg = col,
			widget = wibox.container.background,
		},
		layout = wibox.layout.fixed.vertical,
		buttons = awful.button({}, 1, function()
			fn()
		end),
	})
	helpers.addHover(button, beautiful.background, helpers.blend(col, beautiful.background, 0.1))
	return button
end

awful.screen.connect_for_each_screen(function(s)
	local scrotter = wibox({
		width = 450,
		height = 230,
		shape = helpers.rrect(8),
		bg = beautiful.darker,
		ontop = true,
		visible = false,
	})
	local slide = animation:new({
		duration = 1,
		pos = 0 - scrotter.height,
		easing = animation.easing.inOutExpo,
		update = function(_, pos)
			scrotter.y = s.geometry.y + pos
		end,
	})

	local slide_end = gears.timer({
		single_shot = true,
		timeout = 1,
		callback = function()
			scrotter.visible = false
		end,
	})

	local close = function()
		slide_end:again()
		slide:set(0 - scrotter.height)
	end

	local fullscreen = createButton(
		gears.filesystem.get_configuration_dir() .. "/themes/assets/screenshot/fullscreen.png",
		"Fullscreen",
		function()
			close()
			screenshot.full({ notify = true })
		end,
		beautiful.green
	)

	local selection = createButton(
		gears.filesystem.get_configuration_dir() .. "/themes/assets/screenshot/selection.png",
		"Selection",
		function()
			close()
			screenshot.area({ notify = true })
		end,
		beautiful.blue
	)

	local window = createButton(
		gears.filesystem.get_configuration_dir() .. "/themes/assets/screenshot/window.png",
		"Window",
		function()
			close()
			screenshot.window({ notify = true })
		end,
		beautiful.red
	)

	scrotter:setup({
		{
			{
				{
					{
						font = beautiful.sans .. " Bold 15",
						markup = "Screenshotter",
						align = "start",
						widget = wibox.widget.textbox,
					},
					widget = wibox.container.margin,
					margins = 15,
				},
				widget = wibox.container.background,
				bg = beautiful.lighter,
			},
			{
				fullscreen,
				selection,
				window,
				spacing = 15,
				layout = wibox.layout.fixed.horizontal,
			},
			spacing = 15,
			layout = wibox.layout.fixed.vertical,
		},
		widget = wibox.container.margin,
		margins = 15,
	})

	awesome.connect_signal("toggle::screenshot", function()
		if scrotter.visible then
			slide_end:again()
			slide:set(0 - scrotter.height)
		elseif not scrotter.visible then
			slide:set(beautiful.height / 2 - scrotter.height / 2)
			scrotter.visible = true
		end
		awful.placement.centered(scrotter)
	end)
	awesome.connect_signal("close::screenshot", function()
		close()
	end)
end)
