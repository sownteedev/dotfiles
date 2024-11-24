local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local pctl = require("modules.playerctl")
local playerctl = pctl.lib()

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
		art.image = gears.surface.load_uncached(wall)
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
	_Utils.widget.placeWidget(music, "top_left", 76, 0, 2, 0)

	music:setup({
		{
			art,
			{
				bg = {
					type = "linear",
					from = { 0, 0 },
					to = { 430, 0 },
					stops = { { 0, beautiful.background .. "66" }, { 1, beautiful.background .. "FF" } },
				},
				widget = wibox.container.background,
			},
			layout = wibox.layout.stack,
		},
		{
			{
				{
					{
						{
							id = "songname",
							font = beautiful.sans .. " Medium 14",
							halign = "right",
							markup = _Utils.widget.colorizeText("Nothing Playing", beautiful.foreground),
							widget = wibox.widget.textbox,
						},
						left = 250,
						widget = wibox.container.margin,
					},
					{
						id = "artist",
						font = beautiful.sans .. " 12",
						halign = "right",
						markup = _Utils.widget.colorizeText(" Nobody", beautiful.foreground),
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
		{
			{
				id = "slider",
				bar_color = beautiful.foreground .. "00",
				bar_active_color = beautiful.foreground .. "00",
				handle_color = beautiful.foreground .. "00",
				bar_height = 10,
				forced_height = 10,
				opacity = 0.5,
				widget = wibox.widget.slider,
			},
			valign = "bottom",
			widget = wibox.container.place,
		},
		layout = wibox.layout.stack,
	})
	playerctl:connect_signal("metadata", function(_, title, artist, album_path, _, _, _)
		local album = not album_path or album_path == "" and _User.SongDefPicture or album_path
		awful.spawn.easy_async_with_shell(
			"convert " .. album .. " -resize 16:9! ~/.cache/awesome/songdefpicture.jpg", function()
				local artt = gears.filesystem.get_cache_dir() .. "songdefpicture.jpg"
				art.image = gears.surface.load_uncached(artt)
			end)

		if string.len(title) >= 60 then
			title = string.sub(title, 0, 60) .. "..."
		end
		_Utils.widget.gc(music, "songname"):set_markup_silently(_Utils.widget.colorizeText(title, beautiful.foreground))

		if artist ~= "" then
			_Utils.widget.gc(music, "artist"):set_markup_silently(_Utils.widget.colorizeText(artist, beautiful
				.foreground))
		end

		collectgarbage('collect')
	end)

	playerctl:connect_signal("playback_status", function(_, playing, _)
		_Utils.widget.gc(music, "play"):set_image(gears.color.recolor_image(playing and beautiful.icon_path ..
			"music/pause.svg" or beautiful.icon_path .. "music/play.svg", beautiful.foreground))
	end)

	playerctl:connect_signal('loop_status', function(_, loop_status, _)
		loop_status = loop_status:gsub('^%l', string.upper)
		if loop_status == "None" then
			_Utils.widget.gc(music, "loop"):set_image(gears.color.recolor_image(beautiful.icon_path ..
				"music/loop.svg", beautiful.foreground))
		elseif loop_status == "Track" then
			_Utils.widget.gc(music, "loop"):set_image(gears.color.recolor_image(beautiful.icon_path ..
				"music/loopone.svg", beautiful.green))
		elseif loop_status == "Playlist" then
			_Utils.widget.gc(music, "loop"):set_image(gears.color.recolor_image(beautiful.icon_path ..
				"music/loop.svg", beautiful.green))
		end
	end)

	playerctl:connect_signal('shuffle', function(_, shuff, _)
		_Utils.widget.gc(music, "shuffle"):set_image(gears.color.recolor_image(
			beautiful.icon_path .. "music/shuffle.svg",
			shuff and beautiful.green or beautiful.foreground))
	end)

	local previous_value = 0
	local internal_update = false
	_Utils.widget.gc(music, "slider"):connect_signal("property::value", function(_, new_value)
		if internal_update and new_value ~= previous_value then
			playerctl:set_position(new_value)
			previous_value = new_value
		end
	end)

	playerctl:connect_signal("position", function(_, interval_sec, length_sec)
		internal_update                         = true
		previous_value                          = interval_sec
		_Utils.widget.gc(music, "slider").value = interval_sec
		if length_sec ~= 0 then
			_Utils.widget.gc(music, "slider").bar_active_color = beautiful.foreground .. "33"
		else
			_Utils.widget.gc(music, "slider").bar_active_color = beautiful.foreground .. "00"
		end
	end)

	awful.spawn.with_line_callback("playerctl -F metadata -f '{{mpris:length}}'", {
		stdout = function(line)
			if line == " " then
				local position = 100
				_Utils.widget.gc(music, "slider").maximum = position
			else
				local position = tonumber(line)
				if position ~= nil then
					_Utils.widget.gc(music, "slider").maximum = position / 1000000 or nil
				end
			end
		end
	})

	_Utils.widget.hoverCursor(music, "next")
	_Utils.widget.hoverCursor(music, "previous")
	_Utils.widget.hoverCursor(music, "play")
	_Utils.widget.hoverCursor(music, "loop")
	_Utils.widget.hoverCursor(music, "shuffle")
	_Utils.widget.hoverCursor(music, "slider")

	_Utils.widget.popupOpacity(music, 0.3)

	return music
end
