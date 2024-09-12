local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local helpers = require("helpers")
local lgi = require("lgi")
local cairo = lgi.cairo
local playerctl = pctl.lib()

local image_with_gradient = function(image)
	local surf = gears.surface.load_uncached(image)

	local cr = cairo.Context(surf)
	local w, h = gears.surface.get_size(surf)
	cr:rectangle(0, 0, w, h)

	local pat_h = cairo.Pattern.create_linear(0, 0, w, 0)
	pat_h:add_color_stop_rgba(0, gears.color.parse_color(beautiful.background .. "66"))
	pat_h:add_color_stop_rgba(0.2, gears.color.parse_color(beautiful.background .. "88"))
	pat_h:add_color_stop_rgba(0.4, gears.color.parse_color(beautiful.background .. "AA"))
	pat_h:add_color_stop_rgba(0.6, gears.color.parse_color(beautiful.background .. "CC"))
	pat_h:add_color_stop_rgba(0.8, gears.color.parse_color(beautiful.background .. "DD"))
	pat_h:add_color_stop_rgba(1, gears.color.parse_color(beautiful.background .. "FF"))
	cr:set_source(pat_h)
	cr:fill()

	return surf
end

local art = wibox.widget({
	id = "art",
	image = nil,
	resize = true,
	clip_shape = beautiful.radius,
	widget = wibox.widget.imagebox,
})

local function convertDefault(image)
	local cmd = "convert " .. image .. " -resize 16:9! ~/.cache/awesome/songdefpicture.jpg"
	awful.spawn.easy_async_with_shell(cmd, function()
		local wall = gears.filesystem.get_cache_dir() .. "songdefpicture.jpg"
		art.image = image_with_gradient(wall)
	end)
end
convertDefault(beautiful.icon_path .. "music/artdefault.jpg")

return function(s)
	local music = wibox({
		screen = s,
		width = 600,
		height = 250,
		ontop = false,
		shape = beautiful.radius,
		visible = true,
	})
	helpers.placeWidget(music, "top_left", 76, 0, 2, 0)

	music:setup({
		art,
		{
			{
				{
					{
						{
							id = "songname",
							font = beautiful.sans .. " Medium 14",
							halign = "right",
							markup = helpers.colorizeText("Nothing Playing", beautiful.foreground),
							widget = wibox.widget.textbox,
						},
						left = 250,
						widget = wibox.container.margin,
					},
					{
						id = "artist",
						font = beautiful.sans .. " 12",
						halign = "right",
						markup = helpers.colorizeText(" Nobody", beautiful.foreground),
						widget = wibox.widget.textbox,
					},
					spacing = 15,
					layout = wibox.layout.fixed.vertical,
				},
				nil,
				{
					{
						{
							id = "shuffle",
							image = gears.color.recolor_image(beautiful.icon_path .. "music/shuffle.svg",
								beautiful.foreground),
							forced_width = 15,
							forced_height = 15,
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
								beautiful.foreground),
							forced_width = 15,
							forced_height = 15,
							widget = wibox.widget.imagebox,
							buttons = {
								awful.button({}, 1, function()
									playerctl:previous()
								end),
							},
						},
						{
							id = "play",
							image = gears.color.recolor_image(beautiful.icon_path .. "music/play.svg",
								beautiful.foreground),
							forced_width = 15,
							forced_height = 15,
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
								beautiful.foreground),
							forced_width = 15,
							forced_height = 15,
							widget = wibox.widget.imagebox,
							buttons = {
								awful.button({}, 1, function()
									playerctl:next()
								end),
							},
						},
						{
							id = "loop",
							image = gears.color.recolor_image(beautiful.icon_path .. "music/loop.svg",
								beautiful.foreground),
							forced_width = 15,
							forced_height = 15,
							widget = wibox.widget.imagebox,
							buttons = {
								awful.button({}, 1, function()
									playerctl:cycle_loop_status()
								end),
							},
						},
						spacing = 15,
						layout = wibox.layout.fixed.horizontal,
					},
					halign = "right",
					widget = wibox.container.place,
				},
				layout = wibox.layout.align.vertical,
			},
			margins = 25,
			widget = wibox.container.margin,
		},
		layout = wibox.layout.stack,
	})
	playerctl:connect_signal("metadata", function(_, title, artist, album_path, _, _, _)
		local album = not album_path or album_path == "" and beautiful.songdefpicture or album_path
		awful.spawn.easy_async_with_shell(
			"convert " .. album .. " -resize 16:9! ~/.cache/awesome/songdefpicture.jpg", function()
				local artt = gears.filesystem.get_cache_dir() .. "songdefpicture.jpg"
				helpers.gc(art, "art"):set_image(image_with_gradient(artt))
			end)

		if string.len(title) >= 60 then
			title = string.sub(title, 0, 60) .. "..."
		end
		helpers.gc(music, "songname"):set_markup_silently(helpers.colorizeText(title, beautiful.foreground))

		if artist ~= "" then
			helpers.gc(music, "artist"):set_markup_silently(helpers.colorizeText(artist, beautiful.foreground))
		end

		collectgarbage('collect')
	end)

	playerctl:connect_signal("playback_status", function(_, playing, _)
		helpers.gc(music, "play"):set_image(gears.color.recolor_image(playing and beautiful.icon_path ..
			"music/pause.svg" or beautiful.icon_path .. "music/play.svg", beautiful.foreground))
	end)

	playerctl:connect_signal('loop_status', function(_, loop_status, _)
		loop_status = loop_status:gsub('^%l', string.upper)
		if loop_status == "None" then
			helpers.gc(music, "loop"):set_image(gears.color.recolor_image(beautiful.icon_path ..
				"music/loop.svg", beautiful.foreground))
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
			shuff and beautiful.green or beautiful.foreground))
	end)

	helpers.hoverCursor(music, "next")
	helpers.hoverCursor(music, "previous")
	helpers.hoverCursor(music, "play")
	helpers.hoverCursor(music, "loop")
	helpers.hoverCursor(music, "shuffle")

	return music
end
