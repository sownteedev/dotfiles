local awful = require("awful")

local mod = "Mod4"
local alt = "Mod1"
local ctrl = "Control"
local shift = "Shift"

awful.keyboard.append_global_keybindings({
	-- Apps
	awful.key({ mod, alt }, "space", function()
		awesome.emit_signal("toggle::preview")
	end),
	awful.key({ alt }, "space", function()
		awesome.emit_signal("toggle::launcher")
	end),
	awful.key({ mod }, "e", function()
		awful.spawn.with_shell("nemo")
	end),
	awful.key({ mod }, "Return", function()
		awful.spawn.with_shell("alacritty")
	end),
	awful.key({ ctrl, shift }, "Escape", function()
		awful.spawn.with_shell("xfce4-taskmanager")
	end),

	-- Volume and Brightness
	awful.key({}, "XF86AudioPlay", function()
		awful.spawn.with_shell("playerctl play-pause")
	end),
	awful.key({}, "XF86AudioPrev", function()
		awful.spawn.with_shell("playerctl previous")
	end),
	awful.key({}, "XF86AudioNext", function()
		awful.spawn.with_shell("playerctl next")
	end),

	awful.key({}, "XF86AudioRaiseVolume", function()
		awful.spawn.with_shell("pactl set-sink-volume @DEFAULT_SINK@ +2%")
		volume_emit()
		awesome.emit_signal("open::brivolmic")
	end),
	awful.key({}, "XF86AudioLowerVolume", function()
		awful.spawn.with_shell("pactl set-sink-volume @DEFAULT_SINK@ -2%")
		volume_emit()
		awesome.emit_signal("open::brivolmic")
	end),
	awful.key({}, "XF86AudioMute", function()
		volume_toggle()
	end),

	awful.key({ mod }, "XF86AudioRaiseVolume", function()
		awful.spawn.with_shell("pactl set-source-volume @DEFAULT_SOURCE@ +5%")
		mic()
		awesome.emit_signal("open::brivolmic")
	end),
	awful.key({ mod }, "XF86AudioLowerVolume", function()
		awful.spawn.with_shell("pactl set-source-volume @DEFAULT_SOURCE@ -5%")
		mic()
		awesome.emit_signal("open::brivolmic")
	end),
	awful.key({}, "XF86AudioMicMute", function()
		mic_toggle()
	end),

	awful.key({}, "XF86MonBrightnessUp", function()
		awful.spawn.with_shell("brightnessctl s 5%+")
		brightness_emit()
		awesome.emit_signal("open::brivolmic")
	end),
	awful.key({}, "XF86MonBrightnessDown", function()
		awful.spawn.with_shell("brightnessctl s 5%-")
		brightness_emit()
		awesome.emit_signal("open::brivolmic")
	end),

	awful.key({ mod }, "Print", function()
		record()
	end),
	awful.key({ mod, shift }, "Print", function()
		awful.spawn.with_shell("pkill -f ffmpeg")
	end),
	awful.key({ mod, shift }, "s", function()
		area()
	end),
	awful.key({ alt }, "p", function()
		awful.spawn.with_shell("~/.config/awesome/scripts/colorpicker")
	end),
	awful.key({ alt }, "F4", function()
		if client.focus then
			client.focus:kill()
		else
			awesome.emit_signal("toggle::exit")
		end
	end),
	awful.key({ mod }, "d", function()
		_Utils.keys.toggle_show_desktop()
	end),
	awful.key({ mod }, "l", function()
		awesome.emit_signal("toggle::lock")
	end),
	awful.key({ mod, alt }, "r", awesome.restart),
	awful.key({ mod, alt }, "q", awesome.quit),
})

local table_insert = table.insert
local hasitem = awful.util.table.hasitem
local screen_focused = awful.screen.focused
local tag_find_by_name = awful.tag.find_by_name
local tagactive = {}
local tagdefault_count = #_User.Tag

local function update_tag_info()
	tagactive = {}
	local primary_tags = screen.primary.tags
	for _, t in ipairs(primary_tags) do
		if #t:clients() > 0 then
			table_insert(tagactive, t.name)
		end
	end
end
tag.connect_signal("property::selected", update_tag_info)

local function get_next_tag(current_tag, direction)
	local current_index = hasitem(tagactive, current_tag)

	if current_index then
		local tagactive_count = #tagactive
		local next_index = (current_index + direction - 1) % tagactive_count + 1
		return tagactive[next_index]
	end

	local default_index = hasitem(_User.Tag, current_tag) or 1
	local start = default_index + direction
	local limit = default_index + tagdefault_count * direction

	for i = start, limit, direction do
		local mod_i = (i - 1) % tagdefault_count + 1
		if hasitem(tagactive, _User.Tag[mod_i]) then
			return _User.Tag[mod_i]
		end
	end

	return nil
end

local function switch_to_tag(direction)
	local current_screen = screen_focused()
	local current_tag = current_screen.selected_tag.name
	local next_tag = get_next_tag(current_tag, direction)

	if next_tag then
		tag_find_by_name(current_screen, next_tag):view_only()
	end
end

awful.keyboard.append_global_keybindings({
	-- Tags
	awful.key({ ctrl }, "Right", function()
		switch_to_tag(1)
	end),

	awful.key({ ctrl }, "Left", function()
		switch_to_tag(-1)
	end),
	awful.key({ mod }, "Tab", function()
		switch_to_tag(1)
	end),

	awful.key({ mod, shift }, "Tab", function()
		switch_to_tag(-1)
	end),

	-- Client
	awful.key({ alt }, "Tab", function()
		if opened_preview then
			awesome.emit_signal("close::preview")
			return
		end
		require("widgets.popup.preview.previewclients").switch(1, "Mod1", "Alt_L", "Shift", "Tab")
	end),
})

awful.keyboard.append_global_keybindings({
	awful.key({
		modifiers = { mod },
		keygroup = "numrow",
		group = "tag",
		on_press = function(index)
			local screen = awful.screen.focused()
			local tag = screen.tags[index]
			if tag then
				tag:view_only()
			end
		end,
	}),
	awful.key({
		modifiers = { mod, shift },
		keygroup = "numrow",
		group = "tag",
		on_press = function(index)
			if client.focus then
				local tag = client.focus.screen.tags[index]
				if tag then
					client.focus:move_to_tag(tag)
				end
			end
		end,
	}),
})

client.connect_signal("request::default_keybindings", function()
	awful.keyboard.append_client_keybindings({
		awful.key({ mod }, "f", function(c)
			c.maximized = not c.maximized
		end),
	})
end)

-- MOUSE
client.connect_signal("request::default_mousebindings", function()
	awful.mouse.append_client_mousebindings({
		awful.button({}, 1, function(c)
			c:activate({ context = "mouse_click" })
		end),
		awful.button({ mod }, 1, function(c)
			c:activate({ context = "mouse_click", action = "mouse_move" })
		end),
		awful.button({ mod }, 4, function()
			switch_to_tag(1)
		end),
		awful.button({ mod }, 5, function()
			switch_to_tag(-1)
		end),
		awful.button({ mod }, 3, function(c)
			c:activate({ context = "mouse_click", action = "mouse_resize" })
		end),
	})
end)

awful.mouse.append_global_mousebindings({
	awful.button({}, 1, function()
		awesome.emit_signal("close::noticenter")
		awesome.emit_signal("close::control")
		awesome.emit_signal("close::preview")
		awesome.emit_signal("close::exit")
	end),
	awful.button({}, 3, function()
		-- awesome.emit_signal("toggle::menu")
	end),
})
client.connect_signal("button::press", function()
	awesome.emit_signal("close::noticenter")
	awesome.emit_signal("close::control")
	awesome.emit_signal("close::preview")
	awesome.emit_signal("close::exit")
end)
