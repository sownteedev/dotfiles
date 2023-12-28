local wibox     = require("wibox")
local beautiful = require("beautiful")
local gears     = require("gears")
local pctl      = require("modules.playerctl")
local helpers   = require("helpers")
local playerctl = pctl.lib()

local art       = wibox.widget {
	image = helpers.cropSurface(1.71, gears.surface.load_uncached(beautiful.songdefpicture)),
	opacity = 0.3,
	resize = true,
	height = 300,
	clip_shape = helpers.rrect(5),
	widget = wibox.widget.imagebox
}

local widget    = wibox.widget {
	{
		art,
		{
			{
				widget = wibox.widget.textbox,
			},
			bg = {
				type = "linear",
				from = { 0, 0 },
				to = { 200, 0 },
				stops = { { 0, beautiful.background_alt .. "88" }, { 1, beautiful.background .. '33' } }
			},
			shape = helpers.rrect(5),
			widget = wibox.container.background,
		},
		{
			{
				{
					{
						font = beautiful.sans .. " 10",
						markup = helpers.colorizeText('Now Playing', beautiful.foreground),
						widget = wibox.widget.textbox,
					},
					{
						id = "songname",
						font = beautiful.sans .. " SemiBold 12",
						markup = helpers.colorizeText('Song Name', beautiful.foreground),
						widget = wibox.widget.textbox,
					},
					{
						id = "artist",
						font = beautiful.sans .. " 10",
						markup = helpers.colorizeText('Artist Name', beautiful.foreground),
						widget = wibox.widget.textbox,
					},
					spacing = 8,
					layout = wibox.layout.fixed.vertical,
				},
				widget = wibox.container.place,
				halign = "left",
				valign = "top"
			},
			widget = wibox.container.margin,
			margins = 20,
		},
		layout = wibox.layout.stack,
	},
	widget = wibox.container.margin,
	top = 15,
}

playerctl:connect_signal("metadata", function(_, title, artist, album_path, album, new, player_name)
	if album_path == "" then
		album_path = beautiful.songdefpicture
	end
	if string.len(title) > 30 then
		title = string.sub(title, 0, 30) .. "..."
	end
	if string.len(artist) > 22 then
		artist = string.sub(artist, 0, 22) .. "..."
	end
	art.image = helpers.cropSurface(1.71, gears.surface.load_uncached(album_path))
	helpers.gc(widget, "songname"):set_markup_silently(helpers.colorizeText(title or "NO", beautiful.foreground))
	helpers.gc(widget, "artist"):set_markup_silently(helpers.colorizeText(artist or "HM", beautiful.foreground))
end)
return widget
