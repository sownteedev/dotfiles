local wibox = require("wibox")
local helpers = require("helpers")
local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")
local pam = require("liblua_pam")
local animation = require("modules.animation")

local auth = function(password)
	return pam.auth_current_user(password)
end

return function(s)
	local lock = wibox({
		screen = s,
		width = beautiful.width,
		height = beautiful.height,
		ontop = true,
		visible = false,
	})

	local profilepic = wibox.widget({
		{
			{
				{
					{
						image = beautiful.profile,
						clip_shape = gears.shape.rounded_rect,
						halign = "center",
						widget = wibox.widget.imagebox,
					},
					id = "arc",
					widget = wibox.container.arcchart,
					max_value = 100,
					min_value = 0,
					value = 0,
					rounded_edge = false,
					thickness = 3,
					start_angle = 4.71238898,
					bg = beautiful.foreground,
					colors = { beautiful.foreground },
					forced_width = 100,
					forced_height = 100,
				},
				{
					markup = beautiful.user .. "@" .. io.popen("uname -n"):read("*l"),
					font = beautiful.sans .. " Medium 13",
					widget = wibox.widget.textbox,
				},
				spacing = 20,
				widget = wibox.layout.fixed.vertical,
			},
			halign = "center",
			valign = "bottom",
			layout = wibox.container.place,
		},
		bottom = 100,
		widget = wibox.container.margin,
	})

	local slide = animation:new({
		duration = 1,
		pos = -lock.height,
		easing = animation.easing.inOutExpo,
		update = function(_, pos)
			lock.y = pos
		end,
	})
	local slide_end = gears.timer({
		timeout = 1,
		single_shot = true,
		callback = function()
			lock.visible = false
		end,
	})

	local reset = function(f)
		helpers.gc(profilepic, "arc"):set_value(not f and 100 or 0)
		helpers.gc(profilepic, "arc"):set_colors({ not f and beautiful.red or beautiful.foreground })
	end
	local getRandom = function()
		local r = math.random(0, 628)
		r = r / 100
		return r
	end

	local input = ""
	local grabber = awful.keygrabber({
		auto_start = true,
		stop_event = "release",
		mask_event_callback = true,
		keybindings = {
			awful.key({
				modifiers = { "Mod1", "Mod4", "Shift", "Control" },
				key = "Return",
				on_press = function(_)
					input = input
				end,
			}),
		},
		keypressed_callback = function(_, _, key, _)
			if key == "Escape" then
				input = ""
				return
			end
			if #key == 1 then
				helpers.gc(profilepic, "arc"):set_colors({ beautiful.blue })
				helpers.gc(profilepic, "arc"):set_value(20)
				helpers.gc(profilepic, "arc"):set_start_angle(getRandom())
				if input == nil then
					input = key
					return
				end
				input = input .. key
			elseif key == "BackSpace" then
				helpers.gc(profilepic, "arc"):set_colors({ beautiful.blue })
				helpers.gc(profilepic, "arc"):set_value(20)
				helpers.gc(profilepic, "arc"):set_start_angle(getRandom())
				input = input:sub(1, -2)
				if #input == 0 then
					helpers.gc(profilepic, "arc"):set_colors({ beautiful.red })
					helpers.gc(profilepic, "arc"):set_value(100)
				end
			end
		end,
		keyreleased_callback = function(self, _, key, _)
			if key == "Return" then
				if auth(input) then
					self:stop()
					reset(true)
					slide_end:start()
					slide:set(-lock.height)
					input = ""
				else
					helpers.gc(profilepic, "arc"):set_colors({ beautiful.red })
					reset(false)
					input = ""
				end
			end
		end,
	})

	local background = wibox.widget({
		image = nil,
		forced_width = beautiful.width,
		forced_height = beautiful.height,
		horizontal_fit_policy = "fit",
		vertical_fit_policy = "fit",
		widget = wibox.widget.imagebox,
	})
	local makeImage = function()
		local cmd = "convert " .. beautiful.lock .. " -filter Gaussian -blur 0x0 ~/.cache/awesome/lock.jpg &"
		awful.spawn.easy_async_with_shell(cmd, function()
			local blurwall = gears.filesystem.get_cache_dir() .. "lock.jpg"
			background.image = blurwall
		end)
	end

	makeImage()
	local time = wibox.widget({
		{
			{
				font = beautiful.sans .. " 35",
				format = "%A, %B %d",
				halign = "center",
				widget = wibox.widget.textclock,
			},
			{
				font = beautiful.sans .. " Bold 140",
				format = "%H:%M",
				halign = "center",
				widget = wibox.widget.textclock,
			},
			layout = wibox.layout.fixed.vertical,
		},
		top = 100,
		widget = wibox.container.margin,
	})

	lock:setup({
		background,
		{
			time,
			nil,
			profilepic,
			layout = wibox.layout.align.vertical,
		},
		layout = wibox.layout.stack,
	})

	awesome.connect_signal("toggle::lock", function()
		if not lock.visible then
			lock.visible = true
			slide:set(0)
			grabber:start()
		end
	end)

	return lock
end
