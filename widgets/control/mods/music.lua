local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()
local Cairo = require("lgi").cairo

local position = wibox.widget({
	font = beautiful.sans .. " 11",
	markup = "",
	widget = wibox.widget.textbox,
	align = "right",
})
local slider = wibox.widget({
	bar_color = beautiful.foreground .. "00",
	bar_active_color = beautiful.foreground .. "00",
	handle_color = beautiful.foreground .. "00",
	handle_shape = function(cr)
		gears.shape.rounded_rect(cr, 10, 10, 15)
	end,
	bar_height = 3,
	forced_height = 10,
	widget = wibox.widget.slider,
})

playerctl:connect_signal("position", function(_, a, b)
	if b ~= 0 then
		local pos = string.format("%02d:%02d", math.floor(a / 60), math.floor(a % 60))
		local len = string.format("%02d:%02d", math.floor(b / 60), math.floor(b % 60))
		position:set_markup_silently(helpers.colorizeText(pos .. " / " .. len, beautiful.fg))
		slider.value = a
		slider.maximum = b
		slider.bar_color = beautiful.fg .. "66"
		slider.bar_active_color = beautiful.fg
		slider.handle_color = beautiful.fg
	else
		slider.bar_color = beautiful.foreground .. "00"
		slider.bar_active_color = beautiful.foreground .. "00"
		slider.handle_color = beautiful.foreground .. "00"
	end
end)

awful.screen.connect_for_each_screen(function(s)
	local music = wibox({
		screen = s,
		width = beautiful.width / 4.5,
		height = (beautiful.height / 3) * 0.6,
		ontop = true,
		visible = false,
	})
	helpers.placeWidget(music, "bottom_right", 0, 70, 0, 2)

	music:setup({
		{
			{
				{
					id = "blur",
					image = beautiful.songdefpicture,
					clip_shape = helpers.rrect(10),
					horizontal_fit_policy = "fit",
					vertical_fit_policy = "fit",
					widget = wibox.widget.imagebox,
				},
				{
					id = "overlay",
					bg = {
						type = "linear",
						from = { 0, 0 },
						to = { 250, 0 },
						stops = { { 0, beautiful.fg1 .. "00" }, { 1, beautiful.fg1 .. "00" } },
					},
					widget = wibox.container.background,
				},
				{
					{
						{
							{
								{
									id = "art",
									image = nil,
									forced_width = 200,
									forced_height = 200,
									resize = true,
									clip_shape = helpers.rrect(10),
									widget = wibox.widget.imagebox,
								},
								id = "border",
								shape_border_width = 5,
								shape_border_color = beautiful.border_color .. "00",
								shape = helpers.rrect(10),
								widget = wibox.container.background,
							},
							{
								{
									{
										{
											id = "songname",
											font = beautiful.sans .. " Medium 18",
											markup = "",
											widget = wibox.widget.textbox,
										},
										{
											id = "artist",
											font = beautiful.sans .. " 13",
											markup = "",
											widget = wibox.widget.textbox,
										},
										{
											id = "album",
											font = beautiful.sans .. " 13",
											markup = "",
											widget = wibox.widget.textbox,
										},
										layout = wibox.layout.fixed.vertical,
										spacing = 10,
									},
									nil,
									{
										{
											id = "player",
											font = beautiful.sans .. " 11",
											markup = "",
											widget = wibox.widget.textbox,
										},
										nil,
										{
											{
												{
													id = "loop",
													font = beautiful.sans .. " 13",
													markup = "",
													widget = wibox.widget.textbox,
													buttons = {
														awful.button({}, 1, function()
															playerctl:cycle_loop_status()
														end),
													},
												},
												right = -5,
												widget = wibox.container.margin,
											},
											{
												id = "previous",
												font = beautiful.sans .. " 17",
												markup = "",
												widget = wibox.widget.textbox,
												buttons = {
													awful.button({}, 1, function()
														slider.value = 0
														playerctl:previous()
													end),
												},
											},
											{
												id = "play",
												font = beautiful.sans .. " 17",
												markup = "",
												widget = wibox.widget.textbox,
												buttons = {
													awful.button({}, 1, function()
														playerctl:play_pause()
													end),
												},
											},
											{
												id = "next",
												font = beautiful.sans .. " 17",
												markup = "",
												widget = wibox.widget.textbox,
												buttons = {
													awful.button({}, 1, function()
														slider.value = 0
														playerctl:next()
													end),
												},
											},
											{
												id = "shuffle",
												font = beautiful.sans .. " 13",
												markup = "",
												widget = wibox.widget.textbox,
												buttons = {
													awful.button({}, 1, function()
														playerctl:cycle_shuffle()
													end),
												},
											},
											spacing = 10,
											layout = wibox.layout.fixed.horizontal,
										},
										layout = wibox.layout.align.horizontal,
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
			widget = wibox.container.margin,
			margins = 15,
		},
		widget = wibox.container.background,
		bg = beautiful.background,
		shape = helpers.rrect(10),
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
	})
	playerctl:connect_signal("metadata", function(_, title, artist, album_path, albumname, _, player_name)
		local album = not album_path or album_path == "" and beautiful.songdefpicture or album_path
		awful.spawn.easy_async_with_shell(
			"convert " .. album .. " -filter Gaussian -blur 0x8 ~/.cache/awesome/songdefpicture.jpg &", function()
				local blurwall = gears.filesystem.get_cache_dir() .. "songdefpicture.jpg"
				helpers.gc(music, "blur"):set_image(helpers.cropSurface(1,
					gears.surface.load_uncached(blurwall)))
			end)
		helpers.gc(music, "art"):set_image(helpers.cropSurface(1, gears.surface.load_uncached(album)))
		helpers.gc(music, "border"):set_shape_border_color(beautiful.border_color)
		if string.len(title) >= 65 then
			title = string.sub(title, 0, 65) .. "..."
		end
		helpers.gc(music, "songname"):set_markup_silently(helpers.colorizeText(title, beautiful.fg))
		helpers.gc(music, "artist"):set_markup_silently(helpers.colorizeText("by ", beautiful.fg .. "AA") ..
			helpers.colorizeText(artist, beautiful.fg))
		if string.len(albumname) == 0 then
			helpers.gc(music, "album"):set_markup_silently(helpers.colorizeText(""))
		else
			helpers.gc(music, "album"):set_markup_silently(helpers.colorizeText("on ", beautiful.fg .. "AA") ..
				helpers.colorizeText(albumname, beautiful.fg))
		end
		helpers.gc(music, "player"):set_markup_silently(helpers.colorizeText("via ", beautiful.fg .. "AA") ..
			helpers.colorizeText(player_name:sub(1, 1):upper() .. player_name:sub(2),
				beautiful.fg
			)
		)
		helpers.gc(music, "overlay"):set_bg({
			type = "linear",
			from = { 0, 0 },
			to = { 250, 0 },
			stops = { { 0, beautiful.fg1 .. "88" }, { 1, beautiful.fg1 .. "88" } },
		})
		helpers.gc(music, "next"):set_markup_silently(helpers.colorizeText("󰒭", beautiful.fg))
		helpers.gc(music, "previous"):set_markup_silently(helpers.colorizeText("󰒮", beautiful.fg))

		collectgarbage('collect')
	end)


	playerctl:connect_signal("playback_status", function(_, playing, _)
		helpers.gc(music, "play"):set_markup_silently(helpers.colorizeText(playing and "󰏤" or "󰐊", beautiful.fg))
	end)

	playerctl:connect_signal('loop_status', function(_, loop_status, _)
		loop_status = loop_status:gsub('^%l', string.upper)
		if loop_status == "None" then
			helpers.gc(music, "loop"):set_markup_silently(helpers.colorizeText("󰦛 ", beautiful.fg))
		elseif loop_status == "Track" then
			helpers.gc(music, "loop"):set_markup_silently(helpers.colorizeText("󰝳 ", beautiful.fg))
		elseif loop_status == "Playlist" then
			helpers.gc(music, "loop"):set_markup_silently(helpers.colorizeText(" ", beautiful.fg))
		end
	end)

	playerctl:connect_signal('shuffle', function(_, shuff, _)
		helpers.gc(music, "shuffle"):set_markup_silently(helpers.colorizeText(
			shuff and "󰒟" or "󰒞", beautiful.fg))
	end)

	awesome.connect_signal("toggle::music", function()
		music.visible = not music.visible
	end)
	awesome.connect_signal("close::music", function()
		music.visible = false
	end)
end)
