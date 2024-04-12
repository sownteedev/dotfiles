local M = {}
local wibox = require("wibox")
local helpers = require("helpers")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pam = require("liblua_pam")
local music = require("ui.exit.mods.music")
local bat = require("ui.exit.mods.battery")
local weather = require("ui.exit.mods.weather")
local pctl = require("modules.playerctl")
local playerctl = pctl.lib()

local next = wibox.widget({
	font = beautiful.icon .. " 30",
	text = "󰒭",
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:next()
		end),
	},
})

local prev = wibox.widget({
	font = beautiful.icon .. " 30",
	text = "󰒮",
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:previous()
		end),
	},
})

local play = wibox.widget({
	font = beautiful.icon .. " 30",
	markup = "󰐍 ",
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:play_pause()
		end),
	},
})

playerctl:connect_signal("playback_status", function(_, playing, player_name)
	play.markup = playing and "󰏦 " or "󰐍 "
end)

local auth = function(password)
	return pam.auth_current_user(password)
end

local profilepic = wibox.widget({
	{
		{
			image = beautiful.profile,
			clip_shape = helpers.rrect(100),
			forced_height = 300,
			forced_width = 300,
			opacity = 1,
			widget = wibox.widget.imagebox,
		},
		id = "arc",
		widget = wibox.container.arcchart,
		max_value = 100,
		min_value = 0,
		value = 0,
		rounded_edge = false,
		thickness = 8,
		start_angle = 4.71238898,
		bg = beautiful.foreground,
		colors = { beautiful.foreground },
		forced_width = 300,
		forced_height = 300,
	},
	widget = wibox.container.place,
	valign = "top",
})

local checkcaps = wibox.widget({
	id = "name",
	font = beautiful.sans .. " 15",
	halign = "center",
	widget = wibox.widget.textbox,
})

local check_caps = function()
	awful.spawn.easy_async_with_shell("xset q | grep Caps | cut -d: -f3 | cut -d0 -f1 | tr -d ' ' &", function(stdout)
		if stdout:match("off") then
			checkcaps.markup = " "
		else
			checkcaps.markup = helpers.colorizeText("WARNING: CAPS LOCK IS ON", helpers.makeColor("orange"))
		end
	end)
end

local lock = wibox({
	width = beautiful.width,
	height = beautiful.height,
	ontop = true,
	visible = false,
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

local visible = function(v)
	lock.visible = v
end

local input = ""
local function grab()
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
					visible(false)
					input = ""
				else
					helpers.gc(profilepic, "arc"):set_colors({ beautiful.red })
					reset(false)
					grab()
					input = ""
				end
			elseif key == "Caps_Lock" then
				check_caps()
			end
		end,
	})
	grabber:start()
end

local background = wibox.widget({
	id = "bg",
	image = beautiful.wallpaper,
	widget = wibox.widget.imagebox,
	forced_width = beautiful.width,
	forced_height = beautiful.height,
	horizontal_fit_policy = "fit",
	vertical_fit_policy = "fit",
})

local makeImage = function()
	local cmd = "convert " .. beautiful.wallpaper .. " -filter Gaussian -blur 0x6 ~/.cache/awesome/lock.jpg &"
	awful.spawn.easy_async_with_shell(cmd, function()
		local blurwall = gears.filesystem.get_cache_dir() .. "lock.jpg"
		background.image = blurwall
	end)
end

makeImage()

local overlay = wibox.widget({
	widget = wibox.container.background,
	forced_width = beautiful.width,
	forced_height = beautiful.height,
	bg = beautiful.background .. "c1",
})

lock:setup({
	background,
	overlay,
	{
		{
			{
				{
					{
						{
							{
								font = beautiful.sans .. " Bold 150",
								format = "%I:%M",
								widget = wibox.widget.textclock,
							},
							{
								{
									font = beautiful.sans .. " Bold 20",
									format = "%p",
									valign = "bottom",
									widget = wibox.widget.textclock,
								},
								widget = wibox.container.margin,
								bottom = 50,
							},
							spacing = 10,
							layout = wibox.layout.fixed.horizontal,
						},
						widget = wibox.container.margin,
						left = 30,
					},
					{
						font = beautiful.sans .. " Light 50",
						format = "%A, %d %B %Y",
						widget = wibox.widget.textclock,
					},
					{
						checkcaps,
						widget = wibox.container.margin,
						top = 200,
						bottom = 100,
					},
					layout = wibox.layout.fixed.vertical,
				},
				widget = wibox.container.place,
				valign = "top",
			},
			profilepic,
			{
				{
					{
						music,
						{
							{
								{
									prev,
									{
										play,
										widget = wibox.container.margin,
										left = 15,
									},
									next,
									layout = wibox.layout.fixed.horizontal,
								},
								widget = wibox.container.margin,
								left = 10,
								right = 10,
							},
							widget = wibox.container.background,
							bg = beautiful.lighter,
							shape = helpers.rrect(10),
						},
						layout = wibox.layout.fixed.horizontal,
						spacing = 40,
					},
					bat,
					weather,
					layout = wibox.layout.fixed.horizontal,
					spacing = 100,
				},
				widget = wibox.container.place,
				valign = "bottom",
			},
			layout = wibox.layout.align.vertical,
		},
		margins = 50,
		widget = wibox.container.margin,
	},
	layout = wibox.layout.stack,
})

check_caps()

function M.open()
	visible(true)
	grab()
end

return M
