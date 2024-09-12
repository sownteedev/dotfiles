local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
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
		blur.image = helpers.cropSurface(6.6, gears.surface.load_uncached(blurwall))
	end)
end
convertBlur(beautiful.icon_path .. "music/blurdefault.jpg")

local art = wibox.widget({
	image = helpers.cropSurface(1, gears.surface.load_uncached(beautiful.songdefpicture)),
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
		markup = helpers.colorizeText("Song Name", beautiful.fg),
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
		markup = helpers.colorizeText("Artist Name", beautiful.fg),
		widget = wibox.widget.textbox,
	},
})

local player = wibox.widget({
	{
		{
			id = "player",
			image = helpers.cropSurface(1, gears.surface.load_uncached(beautiful.icon_path .. "music/default.png")),
			forced_width = 20,
			forced_height = 20,
			resize = true,
			widget = wibox.widget.imagebox,
		},
		shape = helpers.rrect(50),
		bg = beautiful.background,
		widget = wibox.container.background,
	},
	halign = "right",
	valign = "bottom",
	widget = wibox.container.place,
})

playerctl:connect_signal("metadata", function(_, title, artist, album_path, _, _, player_name)
	local album = not album_path or album_path == "" and beautiful.songdefpicture or album_path
	awful.spawn.easy_async_with_shell(
		"convert " .. album .. " -filter Gaussian -blur 0x5 ~/.cache/awesome/songdefpictures.jpg &", function()
			local blurwall = gears.filesystem.get_cache_dir() .. "songdefpictures.jpg"
			blur.image = helpers.cropSurface(6.6, gears.surface.load_uncached(blurwall))
		end)
	art.image = helpers.cropSurface(1, gears.surface.load_uncached(album))
	helpers.gc(songname, "text"):set_markup_silently(helpers.colorizeText(title, beautiful.fg))
	helpers.gc(artistname, "text"):set_markup_silently(helpers.colorizeText(artist, beautiful.fg))
	if player_name == "spotify" then
		player_name = "spotify"
	else
		player_name = "playing"
	end
	helpers.gc(player, "player"):set_image(helpers.cropSurface(1,
		gears.surface.load_uncached(beautiful.icon_path .. "music/" .. player_name .. ".png")))
	collectgarbage('collect')
end)

local next = wibox.widget({
	font = beautiful.icon .. " 20",
	markup = helpers.colorizeText("󰒭", beautiful.fg),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:next()
		end),
	},
})

local prev = wibox.widget({
	font = beautiful.icon .. " 20",
	markup = helpers.colorizeText("󰒮", beautiful.fg),
	widget = wibox.widget.textbox,
	buttons = {
		awful.button({}, 1, function()
			playerctl:previous()
		end),
	},
})

local play = wibox.widget({
	font = beautiful.icon .. " 20",
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
helpers.hoverCursor(next)
helpers.hoverCursor(prev)
helpers.hoverCursor(play)

local finalwidget = wibox.widget({
	{
		blur,
		{
			bg = {
				type = "linear",
				from = { 0, 0 },
				to = { 250, 0 },
				stops = { { 0, beautiful.fg1 .. "AA" }, { 1, beautiful.fg1 .. "AA" } },
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
