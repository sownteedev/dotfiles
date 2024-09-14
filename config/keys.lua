local awful = require("awful")
local beautiful = require("beautiful")

local mod = "Mod4"
local alt = "Mod1"
local ctrl = "Control"
local shift = "Shift"

awful.keyboard.append_global_keybindings({
	-- Apps
	awful.key({ mod }, "space", function()
		-- awesome.emit_signal("toggle::launcher")
	end),
	awful.key({ mod, alt }, "space", function()
		awesome.emit_signal("toggle::preview")
	end),
	awful.key({ alt }, "space", function()
		awful.spawn.with_shell("ulauncher-toggle &")
	end),
	awful.key({ mod }, "e", function()
		awful.spawn.with_shell("nemo &")
	end),
	awful.key({ mod }, "Return", function()
		awful.spawn.with_shell("alacritty &")
	end),
	awful.key({ ctrl, shift }, "Escape", function()
		awful.spawn.with_shell("alacritty -e btop &")
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
		awful.spawn.with_shell("pamixer -i 2")
		volume_emit()
		awesome.emit_signal("open::brivolmic")
	end),
	awful.key({}, "XF86AudioLowerVolume", function()
		awful.spawn.with_shell("pamixer -d 2")
		volume_emit()
		awesome.emit_signal("open::brivolmic")
	end),
	awful.key({}, "XF86AudioMute", function()
		awful.spawn.with_shell("pamixer -t")
		volume_emit()
		awesome.emit_signal("open::brivolmic")
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
		awful.spawn.with_shell("pactl set-source-mute @DEFAULT_SOURCE@ toggle")
		mic()
		awesome.emit_signal("open::brivolmic")
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
		awful.spawn.with_shell("~/.local/bin/colorpicker")
	end),
	awful.key({ alt }, "F4", function()
		if client.focus then
			client.focus:kill()
		else
			awesome.emit_signal("toggle::exit")
		end
	end),
	awful.key({ mod }, "l", function()
		awesome.emit_signal("toggle::lock")
	end),
	awful.key({ mod, alt }, "w", function()
		awful.spawn.with_shell("feh -z --no-fehbg --bg-fill ~/.walls/" .. beautiful.type .. " ")
	end),
	awful.key({ mod, alt }, "r", awesome.restart),
	awful.key({ mod, alt }, "q", awesome.quit),
})

local tagactive = {}
local tagactive_index = {}
local function update_tag_info()
	tagactive = {}
	tagactive_index = {}
	for i, t in ipairs(screen.primary.tags) do
		if #t:clients() > 0 then
			table.insert(tagactive, t.name)
			table.insert(tagactive_index, i)
		end
	end
end
client.connect_signal("manage", update_tag_info)
client.connect_signal("unmanage", update_tag_info)

awful.keyboard.append_global_keybindings({
	-- Tag
	awful.key({ mod }, "Tab", function()
		local current_tag = awful.screen.focused().selected_tag.name
		local current_index = nil
		for i, tag in ipairs(tagactive) do
			if tag == current_tag then
				current_index = i
				break
			else
				current_index = #tagactive
			end
		end
		if current_index ~= nil then
			awful.screen.focused().tags[tagactive_index[current_index % #tagactive + 1]]:view_only()
		end
	end),
	awful.key({ mod, shift }, "Tab", function()
		local current_tag = awful.screen.focused().selected_tag.name
		local current_index = nil
		for i, tag in ipairs(tagactive) do
			if tag == current_tag then
				current_index = i
				break
			else
				current_index = #tagactive
			end
		end
		if current_index ~= nil then
			awful.screen.focused().tags[tagactive_index[current_index - 1 == 0 and #tagactive or current_index - 1]]
				:view_only()
		end
	end),

	-- Client
	awful.key({ alt }, "Tab", function()
		require("modules.awesome-switcher").switch(1, "Mod1", "Alt_L", "Shift", "Tab")
	end),
})

client.connect_signal("request::default_keybindings", function()
	awful.keyboard.append_client_keybindings({
		awful.key({ mod }, "d", function(c)
			c.minimized = true
		end, { description = "minimize", group = "client" }),
		awful.key({ mod }, "m", function(c)
			c.maximized = not c.maximized
			c:raise()
		end, { description = "toggle maximize", group = "client" }),
	})
end)

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
		awful.key({ mod, shift }, "f", function(c)
			if c.maximized then
				c.maximized = false
			end
		end),
		awful.key({ mod, shift }, "f", awful.client.floating.toggle),
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
		awful.button({ mod }, 3, function(c)
			c:activate({ context = "mouse_click", action = "mouse_resize" })
		end),
	})
end)

awful.mouse.append_global_mousebindings({
	awful.button({}, 1, function()
		-- awesome.emit_signal("close::record")
		-- awesome.emit_signal("close::scrot")
		-- awesome.emit_signal("close::launcher")
		-- awesome.emit_signal("close::noticenter")
		-- awesome.emit_signal("close::moment")
		-- awesome.emit_signal("close::control")
		-- awesome.emit_signal("close::music")
		-- awesome.emit_signal("close::preview")
		-- awesome.emit_signal("close::exit")
	end),
	awful.button({}, 3, function()
		-- awesome.emit_signal("toggle::menu")
	end),
})
client.connect_signal("button::press", function()
	-- awesome.emit_signal("close::record")
	-- awesome.emit_signal("close::scrot")
	-- awesome.emit_signal("close::launcher")
	-- awesome.emit_signal("close::noticenter")
	-- awesome.emit_signal("close::moment")
	-- awesome.emit_signal("close::control")
	-- awesome.emit_signal("close::music")
	-- awesome.emit_signal("close::preview")
	-- awesome.emit_signal("close::exit")
end)
