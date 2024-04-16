local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()

local position = wibox.widget({
	font = beautiful.sans .. " 12",
	markup = "",
	widget = wibox.widget.textbox,
	align = "right",
})
local slider = wibox.widget({
	bar_color = beautiful.foreground .. "00",
	bar_active_color = beautiful.foreground .. "00",
	bar_height = 3,
	forced_height = 3,
	widget = wibox.widget.slider,
})

playerctl:connect_signal("position", function(_, a, b)
	if b ~= 0 then
		local pos = string.format("%02d:%02d", math.floor(a / 60), math.floor(a % 60))
		local len = string.format("%02d:%02d", math.floor(b / 60), math.floor(b % 60))
		position:set_markup_silently(helpers.colorizeText(pos .. " / " .. len, beautiful.foreground))
		slider.value = a
		slider.maximum = b
		slider.bar_color = beautiful.foreground .. "66"
		slider.bar_active_color = beautiful.foreground
	else
		position:set_markup_silently(helpers.colorizeText("", beautiful.foreground))
		slider.bar_color = beautiful.foreground .. "00"
		slider.bar_active_color = beautiful.foreground .. "00"
	end
end)

local next = wibox.widget({
	forced_height = 40,
	forced_width = 40,
	image = gears.filesystem.get_configuration_dir() .. "/themes/assets/music/next.png",
	widget = wibox.widget.imagebox,
	valign = "center",
	buttons = {
		awful.button({}, 1, function()
			slider.value = 0
			playerctl:next()
		end),
	},
})

local prev = wibox.widget({
	forced_height = 40,
	forced_width = 40,
	image = gears.filesystem.get_configuration_dir() .. "/themes/assets/music/previous.png",
	widget = wibox.widget.imagebox,
	valign = "center",
	buttons = {
		awful.button({}, 1, function()
			slider.value = 0
			playerctl:previous()
		end),
	},
})

local play = wibox.widget({
	forced_height = 40,
	forced_width = 40,
	image = gears.filesystem.get_configuration_dir() .. "/themes/assets/music/play.png",
	widget = wibox.widget.imagebox,
	valign = "center",
	buttons = {
		awful.button({}, 1, function()
			playerctl:play_pause()
		end),
	},
})
playerctl:connect_signal("playback_status", function(_, playing, _)
	play.image = playing and gears.filesystem.get_configuration_dir() .. "/themes/assets/music/pause.png"
		or gears.filesystem.get_configuration_dir() .. "/themes/assets/music/play.png"
end)

awful.screen.connect_for_each_screen(function(s)
	local music = wibox({
		screen = s,
		width = beautiful.width / 4,
		height = (beautiful.height / 3) * 0.6,
		bg = beautiful.background,
		ontop = true,
		visible = false,
	})
	helpers.placeWidget(music, "bottom_right", 0, 79, 0, 2)

	music:setup({
		{
			{
				nil,
				{
					{
						id = "art",
						image = helpers.cropSurface(1.75, gears.surface.load_uncached(beautiful.songdefpicture)),
						opacity = 1,
						resize = true,
						clip_shape = helpers.rrect(10),
						widget = wibox.widget.imagebox,
					},
					{
						id = "overlay",
						bg = {
							type = "linear",
							from = { 0, 0 },
							to = { 250, 0 },
							stops = { { 0, beautiful.background .. "00" }, { 1, beautiful.background .. "00" } },
						},
						shape = helpers.rrect(10),
						widget = wibox.container.background,
					},
					{
						{
							{
								{
									id = "artt",
									image = nil,
									opacity = 1,
									forced_height = 200,
									forced_width = 200,
									resize = true,
									clip_shape = helpers.rrect(10),
									widget = wibox.widget.imagebox,
								},
								{
									{
										{
											{
												id = "songname",
												font = beautiful.sans .. " Medium 20",
												markup = "",
												widget = wibox.widget.textbox,
												align = "left",
											},
											{
												id = "artist",
												font = beautiful.sans .. " 15",
												markup = "",
												widget = wibox.widget.textbox,
											},
											layout = wibox.layout.fixed.vertical,
											spacing = 20,
										},
										nil,
										{
											id = "player",
											font = beautiful.sans .. " 11",
											markup = "",
											widget = wibox.widget.textbox,
										},
										layout = wibox.layout.align.vertical,
									},
									widget = wibox.container.margin,
									left = 20,
								},
								layout = wibox.layout.align.horizontal,
							},
							nil,
							{
								position,
								slider,
								layout = wibox.layout.fixed.vertical,
								spacing = 10,
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
								play,
								next,
								layout = wibox.layout.align.vertical,
							},
							widget = wibox.container.margin,
							top = 30,
							bottom = 30,
							left = 25,
							right = 25,
						},
						shape = helpers.rrect(10),
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
		shape = helpers.rrect(10),
	})

	playerctl:connect_signal("metadata", function(_, title, artist, album_path, _, _, player_name)
		helpers.gc(music, "art"):set_image(helpers.cropSurface(1.75, gears.surface.load_uncached(album_path)))
		helpers.gc(music, "art"):set_opacity(0.5)
		helpers.gc(music, "overlay"):set_bg({
			type = "linear",
			from = { 0, 0 },
			to = { 250, 0 },
			stops = { { 0, beautiful.background .. "88" }, { 1, beautiful.background .. "88" } },
		})
		helpers.gc(music, "artt"):set_image(helpers.cropSurface(1, gears.surface.load_uncached(album_path)))
		helpers.gc(music, "songname"):set_markup_silently(helpers.colorizeText(title or "NO", beautiful.foreground))
		helpers.gc(music, "artist"):set_markup_silently(helpers.colorizeText(artist or "HM", beautiful.foreground))
		helpers.gc(music, "player"):set_markup_silently(
			helpers.colorizeText(
				"Playing On: " .. player_name:sub(1, 1):upper() .. player_name:sub(2),
				beautiful.foreground
			)
		)
	end)

	awesome.connect_signal("toggle::music", function()
		music.visible = not music.visible
	end)
	awesome.connect_signal("close::music", function()
		music.visible = false
	end)
end)
