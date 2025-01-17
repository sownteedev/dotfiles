local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local playerctl = pctl.lib()

local blur = wibox.widget({
	image = nil,
	horizontal_fit_policy = "fit",
	vertical_fit_policy = "fit",
	widget = wibox.widget.imagebox,
})
local function convertBlur(image)
	local cmd = "convert " .. image .. " -filter Gaussian -blur 0x5 ~/.cache/awesome/blurdefault.jpg"
	awful.spawn.easy_async_with_shell(cmd, function()
		local blurwall = gears.filesystem.get_cache_dir() .. "blurdefault.jpg"
		blur.image = _Utils.image.cropSurface(6.6, gears.surface.load_uncached(blurwall))
	end)
end
convertBlur(beautiful.icon_path .. "music/blurdefault.jpg")

local art = wibox.widget({
	image = _Utils.image.cropSurface(1, gears.surface.load_uncached(_User.SongDefPicture)),
	resize = true,
	forced_height = 100,
	forced_width = 100,
	clip_shape = beautiful.radius,
	widget = wibox.widget.imagebox,
})

local songname = wibox.widget({
	widget = wibox.container.scroll.horizontal,
	step_function = wibox.container.scroll.step_functions.nonlinear_back_and_forth,
	speed = 40,
	forced_width = 220,
	{
		id = "text",
		font = beautiful.sans .. " Medium 14",
		markup = _Utils.widget.colorizeText("Song Name", beautiful.foreground),
		widget = wibox.widget.textbox,
	},
})

local artistname = wibox.widget({
	widget = wibox.container.scroll.horizontal,
	step_function = wibox.container.scroll.step_functions.nonlinear_back_and_forth,
	speed = 40,
	forced_width = 220,
	{
		id = "text",
		font = beautiful.sans .. " 11",
		markup = _Utils.widget.colorizeText("Artist Name", beautiful.foreground),
		widget = wibox.widget.textbox,
	},
})

local player = wibox.widget({
	{
		{
			id = "player",
			image = _Utils.image.cropSurface(1, gears.surface.load_uncached(beautiful.icon_path .. "music/default.png")),
			forced_width = 20,
			forced_height = 20,
			resize = true,
			widget = wibox.widget.imagebox,
		},
		shape = gears.shape.circle,
		bg = beautiful.background,
		widget = wibox.container.background,
	},
	halign = "right",
	valign = "bottom",
	widget = wibox.container.place,
})

playerctl:connect_signal("metadata", function(_, title, artist, album_path, _, _, player_name)
	local album = not album_path or album_path == "" and _User.SongDefPicture or album_path
	awful.spawn.easy_async_with_shell(
		"convert " .. album .. " -filter Gaussian -blur 0x5 ~/.cache/awesome/songdefpictures.jpg", function()
			local blurwall = gears.filesystem.get_cache_dir() .. "songdefpictures.jpg"
			blur.image = _Utils.image.cropSurface(6.6, gears.surface.load_uncached(blurwall))
		end)
	art.image = _Utils.image.cropSurface(1, gears.surface.load_uncached(album))
	_Utils.widget.gc(songname, "text"):set_markup_silently(_Utils.widget.colorizeText(title, beautiful.foreground))
	_Utils.widget.gc(artistname, "text"):set_markup_silently(_Utils.widget.colorizeText(artist, beautiful.foreground))
	if player_name == "spotify" then
		player_name = "spotify"
	else
		player_name = "playing"
	end
	_Utils.widget.gc(player, "player"):set_image(_Utils.image.cropSurface(1,
		gears.surface.load_uncached(beautiful.icon_path .. "music/" .. player_name .. ".png")))
	collectgarbage('collect')
end)

local next = wibox.widget({
	font = beautiful.icon .. " 20",
	markup = _Utils.widget.colorizeText("󰒭", beautiful.foreground),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:next()
		end),
	},
})

local prev = wibox.widget({
	font = beautiful.icon .. " 20",
	markup = _Utils.widget.colorizeText("󰒮", beautiful.foreground),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:previous()
		end),
	},
})

local play = wibox.widget({
	font = beautiful.icon .. " 20",
	markup = _Utils.widget.colorizeText("󰐊", beautiful.foreground),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:play_pause()
		end),
	},
})
playerctl:connect_signal("playback_status", function(_, playing, _)
	play.markup = playing and _Utils.widget.colorizeText("󰏤", beautiful.foreground) or
		_Utils.widget.colorizeText("󰐊", beautiful.foreground)
end)
_Utils.widget.hoverCursor(next)
_Utils.widget.hoverCursor(prev)
_Utils.widget.hoverCursor(play)

local finalwidget = wibox.widget({
	{
		blur,
		{
			bg = {
				type = "linear",
				from = { 0, 0 },
				to = { 250, 0 },
				stops = { { 0, beautiful.background .. "AA" }, { 1, beautiful.background .. "AA" } },
			},
			widget = wibox.container.background,
		},
		{
			{
				{
					{
						art,
						player,
						layout = wibox.layout.stack,
					},
					{
						{
							songname,
							artistname,
							spacing = 10,
							layout = wibox.layout.fixed.vertical,
						},
						valign = "center",
						hlign = "left",
						widget = wibox.container.place,
					},
					spacing = 20,
					layout = wibox.layout.fixed.horizontal,
				},
				nil,
				{
					prev,
					play,
					next,
					spacing = 10,
					layout = wibox.layout.fixed.horizontal
				},
				layout = wibox.layout.align.horizontal,
			},
			margins = 20,
			widget = wibox.container.margin,
		},
		layout = wibox.layout.stack,
	},
	shape = beautiful.radius,
	widget = wibox.container.background,
})

return finalwidget
