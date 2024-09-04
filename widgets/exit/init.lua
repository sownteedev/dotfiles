local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local animation = require("modules.animation")
local helpers = require("helpers")

local createButton = function(icon, name, cmd)
	local button = wibox.widget({
		{
			{
				{
					{
						image = gears.color.recolor_image(beautiful.icon_path .. icon, beautiful.foreground),
						forced_height = 20,
						forced_width = 20,
						resize = true,
						widget = wibox.widget.imagebox,
					},
					{
						text = name,
						font = beautiful.sans .. " 12",
						widget = wibox.widget.textbox,
					},
					spacing = 15,
					layout = wibox.layout.fixed.horizontal,
				},
				halign = "left",
				valign = "center",
				widget = wibox.container.place,
			},
			top = 15,
			bottom = 15,
			left = 40,
			widget = wibox.container.margin,
		},
		id = "bg",
		bg = helpers.change_hex_lightness(beautiful.background, 4),
		shape = beautiful.radius,
		widget = wibox.container.background,
		buttons = awful.button({}, 1, function()
			awful.spawn(cmd)
		end),
	})
	helpers.addHoverBg(button, "bg", helpers.change_hex_lightness(beautiful.background, 4),
		helpers.change_hex_lightness(beautiful.background, 6))
	return button
end

return function(s)
	local exit = wibox({
		screen = s,
		width = 250,
		height = 380,
		ontop = true,
		shape = beautiful.radius,
		bg = beautiful.background,
		y = beautiful.useless_gap * 6,
		visible = false,
	})

	exit:setup({
		{
			{
				id = "uptime",
				align = "center",
				font = beautiful.sans .. " Medium 12",
				widget = wibox.widget.textbox,
			},
			{
				createButton("power/poweroff.svg", "Shutdown", "poweroff"),
				createButton("power/restart.svg", "Reboot", "reboot"),
				createButton("power/lock.svg", "Lock", "awesome-client \"awesome.emit_signal('toggle::lock')\" &"),
				createButton("power/suspend.svg", "Suspend", "systemctl suspend"),
				createButton("power/logout.svg", "Logout", "loginctl kill-user $USER"),
				layout = wibox.layout.fixed.vertical,
				spacing = 15,
			},
			layout = wibox.layout.fixed.vertical,
		},
		widget = wibox.container.margin,
		margins = 15,
	})

	awesome.connect_signal("signal::uptime", function(v)
		helpers.gc(exit, "uptime").markup = helpers.colorizeText("Up: " .. v, beautiful.foreground)
	end)

	local slide = animation:new({
		duration = 1,
		pos = -exit.width,
		easing = animation.easing.inOutExpo,
		update = function(_, pos)
			exit.x = pos
		end,
	})
	local slide_end = gears.timer({
		timeout = 1,
		single_shot = true,
		callback = function()
			exit.visible = false
		end,
	})
	awesome.connect_signal("toggle::exit", function()
		if exit.visible then
			slide_end:start()
			slide:set(-exit.width)
		else
			exit.visible = true
			slide:set(beautiful.useless_gap * 2)
		end
	end)

	return exit
end
