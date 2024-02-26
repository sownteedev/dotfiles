local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()

local art = wibox.widget({
	image = helpers.cropSurface(1, gears.surface.load_uncached(beautiful.songdefpicture)),
	forced_height = 80,
	forced_width = 80,
	clip_shape = helpers.rrect(100),
	widget = wibox.widget.imagebox,
})

local songname = wibox.widget({
	markup = helpers.colorizeText("Nothing Playing", beautiful.foreground),
	align = "left",
	valign = "center",
	font = beautiful.sans .. " 25",
	widget = wibox.widget.textbox,
})

local widget = wibox.widget({
	art,
	songname,
	layout = wibox.layout.fixed.horizontal,
	spacing = 20,
})

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
	songname:set_markup_silently(helpers.colorizeText(title or "NO", beautiful.foreground))
	art:set_image(helpers.cropSurface(1, gears.surface.load_uncached(album_path)))
end)

return widget
