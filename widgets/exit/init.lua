local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local helpers = require("helpers")
local animation = require("modules.animation")

local exit, slide, slide_end, prompt_grabber

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
		bg = beautiful.lighter,
		shape_border_width = beautiful.border_width,
		shape_border_color = beautiful.lighter1,
		shape = beautiful.radius,
		widget = wibox.container.background,
		buttons = {
			awful.button({}, 1, function()
				prompt_grabber:stop()
				slide_end:start()
				slide:set(-exit.width)
				awful.spawn.with_shell(cmd)
			end),
		},
	})
	button.cmd = cmd
	helpers.hoverCursor(button)
	return button
end

local entries_container = wibox.widget({
	spacing = 15,
	layout = wibox.layout.fixed.vertical,
})

local buttons = {
	createButton("power/poweroff.svg", "Shutdown", "poweroff"),
	createButton("power/restart.svg", "Reboot", "reboot"),
	createButton("power/lock.svg", "Lock", "awesome-client \"awesome.emit_signal('toggle::lock')\""),
	createButton("power/suspend.svg", "Suspend", "systemctl suspend"),
	createButton("power/logout.svg", "Logout", "loginctl kill-user $USER"),
}

local index_entry = 1
local function filter_entries()
	entries_container:reset()
	for i, button in ipairs(buttons) do
		if i == index_entry then
			helpers.gc(button, "bg").bg = beautiful.lighter1
		else
			helpers.gc(button, "bg").bg = beautiful.lighter
		end
		entries_container:add(button)
	end
end

local function next()
	if index_entry < #buttons then
		index_entry = index_entry + 1
	else
		index_entry = 1
	end
	filter_entries()
end
local function prev()
	if index_entry > 1 then
		index_entry = index_entry - 1
	else
		index_entry = #buttons
	end
	filter_entries()
end

return function(s)
	exit = wibox({
		screen = s,
		width = 250,
		height = 380,
		ontop = true,
		shape = beautiful.radius,
		bg = beautiful.background,
		border_width = beautiful.border_width,
		border_color = beautiful.lighter,
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
			entries_container,
			layout = wibox.layout.fixed.vertical,
		},
		widget = wibox.container.margin,
		margins = 15,
	})

	awesome.connect_signal("signal::uptime", function(v)
		helpers.gc(exit, "uptime").markup = helpers.colorizeText("Up: " .. v, beautiful.foreground)
	end)

	prompt_grabber = awful.keygrabber({
		auto_start = true,
		stop_event = "release",
		keypressed_callback = function(self, _, key, _)
			if key == "Up" then
				prev()
			elseif key == "Down" or key == "Tab" then
				next()
			elseif key == "Return" then
				self:stop()
				exit.visible = false
				gears.timer.start_new(0.2, function()
					awful.spawn.with_shell(buttons[index_entry].cmd)
				end)
			elseif key == "Escape" then
				self:stop()
				slide_end:start()
				slide:set(-exit.width)
			else
				self:stop()
			end
		end,
	})

	slide = animation:new({
		duration = 0.5,
		pos = -exit.width,
		easing = animation.easing.inOutExpo,
		update = function(_, poss)
			exit.x = poss
		end,
	})
	slide_end = gears.timer({
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
			prompt_grabber:stop()
		else
			index_entry = 1
			filter_entries()
			prompt_grabber:start()
			exit.visible = true
			slide:set(beautiful.useless_gap * 2)
		end
	end)

	return exit
end
