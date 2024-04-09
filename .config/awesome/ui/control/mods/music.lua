local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()

local next = wibox.widget({
	align = "center",
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
	align = "center",
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
	align = "center",
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

awful.screen.connect_for_each_screen(function(s)
	local music = wibox({
		screen = s,
		width = beautiful.width / 4,
		height = (beautiful.height / 3) * 0.56,
		bg = beautiful.background,
		ontop = true,
		visible = false,
	})
	helpers.placeWidget(music, "bottom_right", 0, 74, 0, 2)

	music:setup({
		{
			{
				nil,
				{
					{
						id = "art",
						image = helpers.cropSurface(1.9, gears.surface.load_uncached(beautiful.songdefpicture)),
						opacity = 0.7,
						resize = true,
						clip_shape = helpers.rrect(5),
						widget = wibox.widget.imagebox,
					},
					{
						bg = {
							type = "linear",
							from = { 0, 0 },
							to = { 250, 0 },
							stops = { { 0, beautiful.background .. "ff" }, { 1, beautiful.background .. "00" } },
						},
						shape = helpers.rrect(5),
						widget = wibox.container.background,
					},
					{
						{
							{
								{
									id = "songname",
									font = beautiful.sans .. " 20",
									markup = helpers.colorizeText("Song Name", beautiful.foreground),
									widget = wibox.widget.textbox,
								},
								{
									id = "artist",
									font = beautiful.sans .. " 12",
									markup = helpers.colorizeText("Artist Name", beautiful.foreground),
									widget = wibox.widget.textbox,
								},
								spacing = 20,
								layout = wibox.layout.fixed.vertical,
							},
							nil,
							{
								{
									id = "pos",
									font = beautiful.sans .. " 12",
									markup = "",
									widget = wibox.widget.textbox,
								},
								{
									id = "player",
									font = beautiful.sans .. " 11",
									markup = " ",
									widget = wibox.widget.textbox,
								},
								{
									id = "prg",
									forced_height = 3,
									color = beautiful.foreground,
									background_color = beautiful.foreground .. "00",
									widget = wibox.widget.progressbar,
								},
								layout = wibox.layout.fixed.vertical,
							},
							layout = wibox.layout.align.vertical,
						},
						widget = wibox.container.margin,
						margins = 20,
					},
					layout = wibox.layout.stack,
				},
				{
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
								layout = wibox.layout.align.vertical,
							},
							widget = wibox.container.margin,
							top = 30,
							bottom = 30,
							left = 10,
							right = 5,
						},
						shape = helpers.rrect(5),
						widget = wibox.container.background,
						bg = beautiful.background,
					},
					widget = wibox.container.margin,
					left = 15,
				},
				layout = wibox.layout.align.horizontal,
			},
			widget = wibox.container.margin,
			margins = 15,
		},
		forced_height = 300,
		widget = wibox.container.background,
		bg = beautiful.darker,
		shape = helpers.rrect(5),
	})

	awesome.connect_signal("toggle::music", function()
		music.visible = not music.visible
	end)
	awesome.connect_signal("close::music", function()
		music.visible = false
	end)

	playerctl:connect_signal("metadata", function(_, title, artist, album_path, album, new, player_name)
		if album_path == "" then
			album_path = beautiful.songdefpicture
		end
		if string.len(title) > 40 then
			title = string.sub(title, 0, 35) .. "..."
		end
		if string.len(artist) > 25 then
			artist = string.sub(artist, 0, 25) .. "..."
		end
		helpers.gc(music, "songname"):set_markup_silently(helpers.colorizeText(title or "NO", beautiful.foreground))
		helpers.gc(music, "artist"):set_markup_silently(helpers.colorizeText(artist or "HM", beautiful.foreground))
		helpers.gc(music, "art"):set_image(helpers.cropSurface(1.9, gears.surface.load_uncached(album_path)))
		if player_name ~= "spotify" then
			helpers
				.gc(music, "player")
				:set_markup_silently(helpers.colorizeText("Playing On: " .. player_name, beautiful.foreground))
		else
			helpers.gc(music, "player"):set_markup_silently(helpers.colorizeText(" ", beautiful.foreground))
		end
	end)
	playerctl:connect_signal("position", function(_, a, b, _)
		if b ~= 0 then
			local pos = string.format("%02d:%02d", math.floor(a / 60), math.floor(a % 60))
			local len = string.format("%02d:%02d", math.floor(b / 60), math.floor(b % 60))
			helpers
				.gc(music, "pos")
				:set_markup_silently(helpers.colorizeText(pos .. " / " .. len, beautiful.foreground))
			helpers.gc(music, "prg"):set_value(a)
			helpers.gc(music, "prg"):set_max_value(b)
			helpers.gc(music, "prg"):set_background_color(beautiful.foreground .. "33")
		else
			helpers.gc(music, "pos"):set_markup_silently(helpers.colorizeText("", beautiful.foreground))
			helpers.gc(music, "prg"):set_background_color(beautiful.foreground .. "00")
		end
	end)
end)
