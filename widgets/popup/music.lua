local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local playerctl = pctl.lib()

local function convertBlur(image)
	awful.spawn.with_shell("convert " .. image .. " -filter Gaussian -blur 0x8 ~/.cache/awesome/blurdefault.jpg &")
end
convertBlur(beautiful.icon_path .. "music/blurdefault.jpg")

local position_start = wibox.widget({
	font = beautiful.sans .. " 10",
	markup = "00:00",
	widget = wibox.widget.textbox,
	align = "left",
})
local position_end = wibox.widget({
	font = beautiful.sans .. " 10",
	markup = "00:00",
	widget = wibox.widget.textbox,
	align = "right",
})

local slider = wibox.widget({
	bar_color = beautiful.fg,
	bar_active_color = beautiful.fg,
	handle_color = beautiful.fg,
	handle_shape = function(cr)
		gears.shape.rounded_rect(cr, 10, 10, 15)
	end,
	bar_height = 3,
	forced_height = 10,
	widget = wibox.widget.slider,
})

playerctl:connect_signal("position", function(_, a, b)
	local pos = string.format("%02d:%02d", math.floor(a / 60), math.floor(a % 60))
	local len = string.format("%02d:%02d", math.floor(b / 60), math.floor(b % 60))
	position_start:set_markup_silently(helpers.colorizeText(pos, beautiful.fg))
	position_end:set_markup_silently(helpers.colorizeText(len, beautiful.fg))
	slider.value = a
	slider.maximum = b
	if len ~= "00:00" then
		slider.bar_color = beautiful.fg .. "66"
	end
end)

return function(s)
	local music = wibox({
		screen = s,
		width = 600,
		height = 250,
		ontop = false,
		shape = beautiful.radius,
		bg = beautiful.background .. "EE",
		visible = true,
	})
	helpers.placeWidget(music, "top_left", 76, 0, 2, 0)

	music:setup({
		{
			id = "blur",
			image = helpers.cropSurface(1, gears.surface.load_uncached(gears.filesystem.get_cache_dir() ..
				"blurdefault.jpg")),
			clip_shape = beautiful.radius,
			horizontal_fit_policy = "fit",
			vertical_fit_policy = "fit",
			widget = wibox.widget.imagebox,
		},
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
						id = "art",
						image = helpers.cropSurface(1, gears.surface.load_uncached(beautiful.songdefpicture)),
						forced_width = 230,
						forced_height = 230,
						resize = true,
						clip_shape = beautiful.radius,
						widget = wibox.widget.imagebox,
					},
					{
						{
							{
								id = "player",
								image = helpers.cropSurface(1,
									gears.surface.load_uncached(beautiful.icon_path .. "music/default.png")),
								forced_width = 30,
								forced_height = 30,
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
					},
					layout = wibox.layout.stack,
				},
				{
					{
						{
							{
								id = "songname",
								font = beautiful.sans .. " Medium 16",
								markup = helpers.colorizeText("Nothing Playing", beautiful.fg),
								widget = wibox.widget.textbox,
							},
							{
								id = "artist",
								font = beautiful.sans .. " 13",
								markup = helpers.colorizeText("by ", beautiful.fg .. "AA") ..
									helpers.colorizeText(" Nobody", beautiful.fg),
								widget = wibox.widget.textbox,
							},
							spacing = 15,
							layout = wibox.layout.fixed.vertical,
						},
						nil,
						{
							{
								{
									{
										id = "shuffle",
										image = gears.color.recolor_image(beautiful.icon_path .. "music/shuffle.svg",
											beautiful.fg),
										forced_width = 20,
										forced_height = 20,
										widget = wibox.widget.imagebox,
										buttons = {
											awful.button({}, 1, function()
												playerctl:cycle_shuffle()
											end),
										},
									},
									{
										id = "previous",
										image = gears.color.recolor_image(beautiful.icon_path .. "music/previous.svg",
											beautiful.fg),
										forced_width = 20,
										forced_height = 20,
										widget = wibox.widget.imagebox,
										buttons = {
											awful.button({}, 1, function()
												slider.value = 0
												playerctl:previous()
											end),
										},
									},
									{
										id = "play",
										image = gears.color.recolor_image(beautiful.icon_path .. "music/play.svg",
											beautiful.fg),
										forced_width = 20,
										forced_height = 20,
										widget = wibox.widget.imagebox,
										buttons = {
											awful.button({}, 1, function()
												playerctl:play_pause()
											end),
										},
									},
									{
										id = "next",
										image = gears.color.recolor_image(beautiful.icon_path .. "music/next.svg",
											beautiful.fg),
										forced_width = 20,
										forced_height = 20,
										widget = wibox.widget.imagebox,
										buttons = {
											awful.button({}, 1, function()
												slider.value = 0
												playerctl:next()
											end),
										},
									},
									{
										id = "loop",
										image = gears.color.recolor_image(beautiful.icon_path .. "music/loop.svg",
											beautiful.fg),
										forced_width = 20,
										forced_height = 20,
										widget = wibox.widget.imagebox,
										buttons = {
											awful.button({}, 1, function()
												playerctl:cycle_loop_status()
											end),
										},
									},
									spacing = 20,
									layout = wibox.layout.fixed.horizontal,
								},
								align = "center",
								widget = wibox.container.place,
							},
							{
								position_start,
								position_end,
								layout = wibox.layout.align.horizontal,
							},
							slider,
							spacing = 10,
							layout = wibox.layout.fixed.vertical,
						},
						layout = wibox.layout.align.vertical,
					},
					left = 15,
					widget = wibox.container.margin,
				},
				layout = wibox.layout.fixed.horizontal,
			},
			margins = 15,
			layout = wibox.container.margin,
		},
		layout = wibox.layout.stack,
	})
	playerctl:connect_signal("metadata", function(_, title, artist, album_path, _, _, player_name)
		local album = not album_path or album_path == "" and beautiful.songdefpicture or album_path
		awful.spawn.easy_async_with_shell(
			"convert " .. album .. " -filter Gaussian -blur 0x8 ~/.cache/awesome/songdefpicture.jpg &", function()
				local blurwall = gears.filesystem.get_cache_dir() .. "songdefpicture.jpg"
				helpers.gc(music, "blur"):set_image(helpers.cropSurface(1,
					gears.surface.load_uncached(blurwall)))
			end)

		helpers.gc(music, "art"):set_image(helpers.cropSurface(1, gears.surface.load_uncached(album)))

		if player_name == "spotify" then
			player_name = "spotify"
		else
			player_name = "playing"
		end
		helpers.gc(music, "player"):set_image(helpers.cropSurface(1,
			gears.surface.load_uncached(beautiful.icon_path .. "music/" .. player_name .. ".png")))

		if string.len(title) >= 50 then
			title = string.sub(title, 0, 50) .. "..."
		end
		helpers.gc(music, "songname"):set_markup_silently(helpers.colorizeText(title, beautiful.fg))

		if artist ~= "" then
			helpers.gc(music, "artist"):set_markup_silently(helpers.colorizeText("by ", beautiful.fg .. "AA") ..
				helpers.colorizeText(artist, beautiful.fg))
		end

		collectgarbage('collect')
	end)

	playerctl:connect_signal("playback_status", function(_, playing, _)
		helpers.gc(music, "play"):set_image(gears.color.recolor_image(playing and beautiful.icon_path ..
			"music/pause.svg" or beautiful.icon_path .. "music/play.svg", beautiful.fg))
	end)

	playerctl:connect_signal('loop_status', function(_, loop_status, _)
		loop_status = loop_status:gsub('^%l', string.upper)
		if loop_status == "None" then
			helpers.gc(music, "loop"):set_image(gears.color.recolor_image(beautiful.icon_path ..
				"music/loop.svg", beautiful.fg))
		elseif loop_status == "Track" then
			helpers.gc(music, "loop"):set_image(gears.color.recolor_image(beautiful.icon_path ..
				"music/loopone.svg", beautiful.green))
		elseif loop_status == "Playlist" then
			helpers.gc(music, "loop"):set_image(gears.color.recolor_image(beautiful.icon_path ..
				"music/loop.svg", beautiful.green))
		end
	end)

	playerctl:connect_signal('shuffle', function(_, shuff, _)
		helpers.gc(music, "shuffle"):set_image(gears.color.recolor_image(beautiful.icon_path .. "music/shuffle.svg",
			shuff and beautiful.green or beautiful.fg))
	end)

	return music
end
