local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local animation = require("modules.animation")

local exit, slide, prompt_grabber

local function createButton(icon, cmd)
	local button = wibox.widget({
		{
			{
				image = gears.color.recolor_image(beautiful.icon_path .. icon, beautiful.foreground),
				forced_height = 30,
				forced_width = 30,
				resize = true,
				widget = wibox.widget.imagebox,
			},
			margins = 15,
			widget = wibox.container.margin,
		},
		id = "bg",
		bg = beautiful.lighter,
		shape_border_width = beautiful.border_width,
		shape_border_color = _Utils.color.change_hex_lightness(beautiful.background, 16),
		shape = beautiful.radius,
		widget = wibox.container.background,
		buttons = {
			awful.button({}, 1, function()
				prompt_grabber:stop()
				exit.visible = false
				awful.spawn.with_shell(cmd)
			end),
		},
	})
	button.cmd = cmd
	_Utils.widget.hoverCursor(button)
	return button
end

local entries_container = wibox.widget({
	spacing = 15,
	layout = wibox.layout.fixed.horizontal,
})

local buttons = {
	createButton("power/poweroff.svg", "poweroff"),
	createButton("power/restart.svg", "reboot"),
	createButton("power/lock.svg", "awesome-client \"awesome.emit_signal('toggle::lock')\""),
	createButton("power/suspend.svg", "systemctl suspend"),
	createButton("power/logout.svg", "loginctl kill-user $USER"),
}

local index_entry = 1
local function filter_entries()
	entries_container:reset()
	for i, button in ipairs(buttons) do
		if i == index_entry then
			_Utils.widget.gc(button, "bg").bg = beautiful.lighter1
		else
			_Utils.widget.gc(button, "bg").bg = beautiful.lighter
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
		width = 390,
		height = 130,
		ontop = true,
		shape = beautiful.radius,
		bg = beautiful.background,
		border_width = beautiful.border_width,
		border_color = beautiful.lighter,
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
		_Utils.widget.gc(exit, "uptime").markup = _Utils.widget.colorizeText("Up: " .. v, beautiful.foreground)
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
				exit.visible = false
				self:stop()
			end
		end,
	})

	slide = animation:new({
		duration = 1,
		pos = 0,
		easing = animation.easing.inOutExpo,
		update = function(_, poss)
			exit.opactity = poss
		end,
	})

	awesome.connect_signal("toggle::exit", function()
		if exit.visible then
			exit.visible = false
			prompt_grabber:stop()
		else
			index_entry = 1
			filter_entries()
			prompt_grabber:start()
			exit.visible = true
			slide:set(1)
		end
	end)

	awesome.connect_signal("close::exit", function()
		if exit.visible then
			exit.visible = false
			prompt_grabber:stop()
		end
	end)

	awesome.connect_signal("signal::blur", function(status)
		exit.bg = not status and beautiful.background or beautiful.background .. "DD"
	end)
	_Utils.widget.placeWidget(exit, "center")

	return exit
end
