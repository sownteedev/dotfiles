local awful = require("awful")
local switcher = require("modules.awesome-switcher")
local Launcher = require("widgets.launcher")
local Menu = require("widgets.rightclick")
local volume = require("widgets.notification.volume")
local brightness = require("widgets.notification.brightness")
local lock = require("widgets.lock")
local exit = require("widgets.exit")
local screenshot = require("widgets.screenshot")
local screenshotarea = require("widgets.screenshot.mods")
local record = require("widgets.record")

local mod = "Mod4"
local alt = "Mod1"
local ctrl = "Control"
local shift = "Shift"

awful.keyboard.append_global_keybindings({
	-- Apps
	awful.key({ mod }, "space", function()
		Launcher:toggle()
	end),
	awful.key({ alt }, "space", function()
		awful.spawn.easy_async_with_shell("ulauncher-toggle &")
	end),
	awful.key({ mod }, "e", function()
		awful.spawn.easy_async_with_shell("thunar &")
	end),
	awful.key({ mod }, "Return", function()
		awful.spawn.easy_async_with_shell("alacritty &")
	end),
	awful.key({ ctrl, shift }, "Escape", function()
		awful.spawn.easy_async_with_shell("alacritty -e btop &")
	end),

	-- Volume and Brightness
	awful.key({}, "XF86AudioPlay", function()
		awful.spawn.easy_async_with_shell("playerctl play-pause &")
	end),
	awful.key({}, "XF86AudioPrev", function()
		awful.spawn.easy_async_with_shell("playerctl previous &")
	end),
	awful.key({}, "XF86AudioNext", function()
		awful.spawn.easy_async_with_shell("playerctl next &")
	end),
	awful.key({}, "XF86AudioRaiseVolume", function()
		awful.spawn.easy_async_with_shell("pamixer -i 2 &")
		volume_emit()
		volume.toggle()
	end),
	awful.key({}, "XF86AudioLowerVolume", function()
		awful.spawn.easy_async_with_shell("pamixer -d 2 &")
		volume_emit()
		volume.toggle()
	end),
	awful.key({}, "XF86AudioMute", function()
		awful.spawn.easy_async_with_shell("pamixer -t &")
		volume_emit()
		volume.toggle()
	end),
	awful.key({}, "XF86AudioMicMute", function()
		awful.spawn.easy_async_with_shell("pactl set-source-mute @DEFAULT_SOURCE@ toggle &")
	end),
	awful.key({}, "XF86MonBrightnessUp", function()
		awful.spawn.easy_async_with_shell("brightnessctl s 5%+ &")
		brightness_emit()
		brightness.toggle()
	end),
	awful.key({}, "XF86MonBrightnessDown", function()
		awful.spawn.easy_async_with_shell("brightnessctl s 5%- &")
		brightness_emit()
		brightness.toggle()
	end),

	awful.key({}, "Print", function()
		screenshot:toggle()
	end),
	awful.key({ mod, shift }, "s", function()
		screenshotarea.area({ notify = true })
	end),
	awful.key({ mod }, "Print", function()
		record:toggle()
	end),
	awful.key({ alt }, "p", function()
		awful.spawn.easy_async_with_shell("~/.local/bin/colorpicker &")
	end),
	awful.key({ alt }, "F4", function()
		if client.focus then
			client.focus:kill()
		else
			exit:toggle()
		end
	end),
	awful.key({ mod }, "l", function()
		lock:open()
	end),
	awful.key({ mod, alt }, "w", function()
		awful.spawn.easy_async_with_shell("feh -z --no-fehbg --bg-fill ~/.walls &")
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
	awful.key({ mod, shift }, "Tab", awful.tag.viewnext),
	awful.key({ mod, ctrl }, "Tab", awful.tag.viewprev),
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
		awful.screen.focused().tags[tagactive_index[current_index % #tagactive + 1]]:view_only()
	end),

	-- Client
	awful.key({ alt }, "Tab", function()
		switcher.switch(1, "Mod1", "Alt_L", "Shift", "Tab")
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
			c.fullscreen = not c.fullscreen
			c:raise()
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
		Launcher:close()
		screenshot:close()
		record:close()
		awesome.emit_signal("close::notify")
		awesome.emit_signal("close::moment")
		awesome.emit_signal("close::control")
		awesome.emit_signal("close::music")
	end),
	awful.button({}, 3, function()
		Menu.desktop:toggle()
	end),
})
client.connect_signal("button::press", function()
	Launcher:close()
	screenshot:close()
	record:close()
	awesome.emit_signal("close::notify")
	awesome.emit_signal("close::moment")
	awesome.emit_signal("close::control")
	awesome.emit_signal("close::music")
end)
