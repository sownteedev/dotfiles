local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()

local art = wibox.widget({
	image = helpers.cropSurface(7, gears.surface.load_uncached(beautiful.songdefpicture)),
	opacity = 0.5,
	forced_width = 350,
	widget = wibox.widget.imagebox,
})

playerctl:connect_signal("metadata", function(_, title, artist, album_path, album, new, player_name)
	art.image = helpers.cropSurface(7, gears.surface.load_uncached(album_path))
end)

local next = wibox.widget({
	font = beautiful.icon .. " 18",
	markup = "󰒭",
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:next()
		end),
	},
})

local prev = wibox.widget({
	font = beautiful.icon .. " 18",
	markup = "󰒮",
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:previous()
		end),
	},
})
local play = wibox.widget({
	font = beautiful.icon .. " 18",
	markup = "󰐊",
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:play_pause()
		end),
	},
})

local headphones = wibox.widget({
	font = beautiful.icon .. " 18",
	markup = "󰟎 ",
	widget = wibox.widget.textbox,
})

playerctl:connect_signal("playback_status", function(_, playing, player_name)
	play.markup = playing and "󰏤" or "󰐊"
	headphones.markup = playing and "󰋎 " or "󰟎 "
end)

local finalwidget = wibox.widget({
	{
		{
			art,
			{
				bg = {
					type = "linear",
					from = { 0, 0 },
					to = { 250, 0 },
					stops = { { 0, beautiful.background .. "30" }, { 1, beautiful.background .. "30" } },
				},
				widget = wibox.container.background,
			},
			{
				{
					headphones,
					nil,
					{ prev, play, next, spacing = 10, layout = wibox.layout.fixed.horizontal },
					layout = wibox.layout.align.horizontal,
				},
				widget = wibox.container.margin,
				left = 20,
				right = 20,
			},
			layout = wibox.layout.stack,
		},
		widget = wibox.container.background,
		shape = helpers.rrect(5),
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
})

return finalwidget
