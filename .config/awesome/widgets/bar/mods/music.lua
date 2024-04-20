local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()

local art = wibox.widget({
	image = helpers.cropSurface(6.7, gears.surface.load_uncached(beautiful.songdefpicture)),
	opacity = 0.7,
	forced_width = 330,
	widget = wibox.widget.imagebox,
})

local player = wibox.widget({
	image = gears.filesystem.get_configuration_dir() .. "/themes/assets/music/default.png",
	resize = true,
	forced_height = 30,
	forced_width = 30,
	valign = "center",
	widget = wibox.widget.imagebox,
})

playerctl:connect_signal("metadata", function(_, title, artist, album_path, album, new, player_name)
	art.image = helpers.cropSurface(6.7, gears.surface.load_uncached(album_path))
	if player_name == "spotify" then
		player.image = gears.filesystem.get_configuration_dir() .. "/themes/assets/music/spotify.png"
		player.forced_width = 25
		player.forced_height = 25
	else
		player.image = gears.filesystem.get_configuration_dir() .. "/themes/assets/music/playing.png"
	end
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

playerctl:connect_signal("playback_status", function(_, playing, player_name)
	play.markup = playing and "󰏤" or "󰐊"
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
					player,
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
		shape = helpers.rrect(5),
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
		widget = wibox.container.background,
	},
	widget = wibox.container.margin,
	top = 10,
	bottom = 10,
})

return finalwidget
