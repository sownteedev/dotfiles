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
			image = beautiful.profile,
			clip_shape = gears.shape.rounded_rect,
			halign = "center",
			forced_width = 100,
			forced_height = 100,
			widget = wibox.widget.imagebox,
		},
		{
			markup = beautiful.user .. "@" .. io.popen("uname -n"):read("*l"),
			font = "azuki_font Bold 18",
			halign = "center",
			widget = wibox.widget.textbox,
		},
		spacing = 10,
		widget = wibox.layout.fixed.vertical,
	})

	local slide = animation:new({
		duration = 0.5,
		pos = -lock.height,
		easing = animation.easing.inOutExpo,
		update = function(_, poss)
			lock.y = poss
		end,
	})
	local slide_end = gears.timer({
		timeout = 1,
		single_shot = true,
		callback = function()
			lock.visible = false
		end,
	})

	local input = ""
	local star = ""
	local prompt = wibox.widget({
		{
			{
				{
					id = "txt",
					markup = "Enter Password",
					font = beautiful.sans .. " 12",
					widget = wibox.widget.textbox,
				},
				align = "center",
				halign = "center",
				widget = wibox.container.place,
			},
			forced_width = 200,
			forced_height = 50,
			shape = helpers.rrect(50),
			widget = wibox.container.background,
			bg = beautiful.background .. "50",
		},
		widget = wibox.container.place,
	})

	local grabber = awful.keygrabber({
		auto_start = true,
		stop_event = "release",
		keypressed_callback = function(_, _, key, _)
			if key == "Escape" then
				input = ""
				star = ""
				helpers.gc(prompt, "txt"):set_markup("Enter Password")
				helpers.gc(prompt, "txt"):set_font(beautiful.sans .. " 12")
			end
			if #key == 1 then
				if input == nil then
					input = key
					return
				end
				input = input .. key
				star = star .. "󰧞"
				helpers.gc(prompt, "txt"):set_markup(star)
				helpers.gc(prompt, "txt"):set_font(beautiful.sans .. " 15")
			elseif key == "BackSpace" then
				input = input:sub(1, -2)
				star = star:sub(1, -2)
				if #input == 0 then
					helpers.gc(prompt, "txt"):set_markup("Enter Password")
					helpers.gc(prompt, "txt"):set_font(beautiful.sans .. " 12")
				else
					helpers.gc(prompt, "txt"):set_markup(star)
					helpers.gc(prompt, "txt"):set_font(beautiful.sans .. " 15")
				end
			end
		end,
		keyreleased_callback = function(self, _, key, _)
			if key == "Return" then
				if auth(input) then
					self:stop()
					slide_end:start()
					slide:set(-lock.height)
					input = ""
					star = ""
				else
					input = ""
					star = ""
					helpers.gc(prompt, "txt"):set_markup("Incorrect Password")
					helpers.gc(prompt, "txt"):set_font(beautiful.sans .. " 12")
				end
			end
		end,
	})

	local background = wibox.widget({
		image = nil,
		horizontal_fit_policy = "fit",
		vertical_fit_policy = "fit",
		widget = wibox.widget.imagebox,
	})
	local makeImage = function()
		local cmd = "convert " .. beautiful.lock .. " ~/.cache/awesome/lock.jpg"
		awful.spawn.easy_async_with_shell(cmd, function()
			local blurwall = gears.filesystem.get_cache_dir() .. "lock.jpg"
			background.image = blurwall
		end)
	end
	makeImage()

	local time = wibox.widget({
		{
			font = beautiful.sans .. " Medium 35",
			format = "%A, %B %d",
			halign = "center",
			widget = wibox.widget.textclock,
		},
		{
			font = beautiful.sans .. " Heavy 140",
			format = "%H:%M",
			halign = "center",
			widget = wibox.widget.textclock,
		},
		layout = wibox.layout.fixed.vertical,
	})

	lock:setup({
		background,
		{
			{
				time,
				nil,
				{
					profilepic,
					prompt,
					spacing = 20,
					layout = wibox.layout.fixed.vertical,
				},
				layout = wibox.layout.align.vertical,
			},
			top = 100,
			bottom = 100,
			widget = wibox.container.margin,
		},
		layout = wibox.layout.stack,
	})

	awesome.connect_signal("toggle::lock", function()
		if not lock.visible then
			lock.visible = true
			slide:set(0)
			grabber:start()
			helpers.gc(prompt, "txt"):set_markup("Enter Password")
			helpers.gc(prompt, "txt"):set_font(beautiful.sans .. " 12")
		end
	end)

	return lock
end
