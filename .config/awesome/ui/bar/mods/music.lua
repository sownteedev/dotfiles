local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()

local art = wibox.widget({
	image = helpers.cropSurface(5.8, gears.surface.load_uncached(beautiful.songdefpicture)),
	opacity = 0.5,
	forced_height = dpi(36),
	shape = helpers.rrect(5),
	forced_width = dpi(240),
	widget = wibox.widget.imagebox,
})

playerctl:connect_signal("metadata", function(_, title, artist, album_path, album, new, player_name)
	art.image = helpers.cropSurface(5.8, gears.surface.load_uncached(album_path))
end)

local next = wibox.widget({
	align = "center",
	font = beautiful.icon .. " 16",
	text = "󰒭",
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:next()
		end),
	},
})

local prev = wibox.widget({
	align = "center",
	font = beautiful.icon .. " 16",
	text = "󰒮",
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:previous()
		end),
	},
})
local play = wibox.widget({
	align = "center",
	font = beautiful.icon .. " 16",
	markup = helpers.colorizeText("󰐊", beautiful.foreground),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:play_pause()
		end),
	},
})

local headphones = wibox.widget({
	align = "center",
	font = beautiful.icon .. " 16",
	markup = helpers.colorizeText("󰟎 ", beautiful.yellow),
	widget = wibox.widget.textbox,
})

playerctl:connect_signal("playback_status", function(_, playing, player_name)
	play.markup = playing and helpers.colorizeText("󰏤", beautiful.foreground)
		or helpers.colorizeText("󰐊", beautiful.foreground)

	headphones.markup = playing and helpers.colorizeText("󰋎 ", beautiful.green)
		or helpers.colorizeText("󰟎 ", beautiful.yellow)
end)

local finalwidget = wibox.widget({
	{
		art,
		{
			{
				widget = wibox.widget.textbox,
			},
			bg = {
				type = "linear",
				from = { 0, 0 },
				to = { 250, 0 },
				stops = { { 0, beautiful.background .. "00" }, { 1, beautiful.background_alt } },
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
			left = 10,
			right = 10,
		},
		layout = wibox.layout.stack,
	},
	widget = wibox.container.background,
	shape = helpers.rrect(5),
})

return finalwidget
