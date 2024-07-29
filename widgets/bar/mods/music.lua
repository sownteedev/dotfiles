local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()

local art = wibox.widget({
	image = helpers.cropSurface(6.6, gears.surface.load_uncached(beautiful.songdefpicture)),
	opacity = 0.8,
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
	local album = not album_path or album_path == "" and beautiful.songdefpicture or album_path
	awful.spawn.easy_async_with_shell(
		"convert " .. album .. " -filter Gaussian -blur 0x5 ~/.cache/awesome/songdefpictures.jpg &", function()
			local blurwall = gears.filesystem.get_cache_dir() .. "songdefpictures.jpg"
			art.image = helpers.cropSurface(6.6, gears.surface.load_uncached(blurwall))
		end)
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
	markup = helpers.colorizeText("󰒭", beautiful.fg),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:next()
		end),
	},
})

local prev = wibox.widget({
	font = beautiful.icon .. " 18",
	markup = helpers.colorizeText("󰒮", beautiful.fg),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:previous()
		end),
	},
})
local play = wibox.widget({
	font = beautiful.icon .. " 18",
	markup = helpers.colorizeText("󰐊", beautiful.fg),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:play_pause()
		end),
	},
})

playerctl:connect_signal("playback_status", function(_, playing, player_name)
	play.markup = playing and helpers.colorizeText("󰏤", beautiful.fg) or helpers.colorizeText("󰐊", beautiful.fg)
end)

local finalwidget = wibox.widget({
	{
		art,
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
})

return finalwidget
