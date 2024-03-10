local awful = require("awful")
local switcher = require("modules.awesome-switcher")
local Launcher = require("ui.launcher")
local Menu = require("ui.rightclick")

local mod = "Mod4"
local alt = "Mod1"
local ctrl = "Control"
local shift = "Shift"

awful.keyboard.append_global_keybindings({
	-- Apps
	awful.key({ alt }, "space", function()
		Launcher:toggle()
	end),
	awful.key({ mod }, "e", function()
		awful.spawn("thunar")
	end),
	awful.key({ mod }, "Return", function()
		awful.spawn("alacritty")
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
		awesome.emit_signal("sowntee::osd")
	end),
	awful.key({}, "XF86AudioLowerVolume", function()
		awful.spawn.with_shell("pamixer -d 2")
		volume_emit()
		awesome.emit_signal("sowntee::osd")
	end),
	awful.key({}, "XF86AudioMute", function()
		awful.spawn.with_shell("pamixer -t")
	end),
	awful.key({}, "XF86AudioMicMute", function()
		awful.spawn.with_shell("pactl set-source-mute @DEFAULT_SOURCE@ toggle")
	end),
	awful.key({}, "XF86MonBrightnessUp", function()
		awful.spawn.with_shell("brightnessctl s 5%+")
		brightness_emit()
		awesome.emit_signal("sowntee::osd")
	end),
	awful.key({}, "XF86MonBrightnessDown", function()
		awful.spawn.with_shell("brightnessctl s 5%-")
		brightness_emit()
		awesome.emit_signal("sowntee::osd")
	end),

	awful.key({}, "Print", function()
		awesome.emit_signal("toggle::scrotter")
	end),
	awful.key({ mod }, "Print", function()
		awesome.emit_signal("toggle::recorder")
	end),
	awful.key({ alt }, "p", function()
		awful.spawn.with_shell("~/.local/bin/colorpicker")
	end),
	awful.key({ alt }, "F4", function()
		awesome.emit_signal("toggle::exit")
	end),
	awful.key({ mod }, "l", function()
		awesome.emit_signal("toggle::lock")
	end),
	awful.key({ mod, alt }, "w", function()
		awful.spawn.with_shell("feh -z --no-fehbg --bg-fill ~/.walls")
	end),
	awful.key({ mod, alt }, "r", awesome.restart),
	awful.key({ mod, alt }, "q", awesome.quit),
})

-- Switch between windows
awful.keyboard.append_global_keybindings({
	-- Tag
	awful.key({ mod, shift }, "Tab", awful.tag.viewnext),
	awful.key({ mod, ctrl }, "Tab", awful.tag.viewprev),
	awful.key({ mod }, "Tab", awful.tag.history.restore),
	-- Client
	awful.key({ alt }, "Tab", function()
		switcher.switch(1, "Mod1", "Alt_L", "Shift", "Tab")
	end),
	awful.key({ alt, shift }, "Tab", function()
		switcher.switch(-1, "Mod1", "Alt_L", "Shift", "Tab")
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
			c.fullscreen = not c.fullscreen
			c:raise()
		end),
		awful.key({ mod, shift }, "f", awful.client.floating.toggle),
		awful.key({ mod, shift }, "q", function(c)
			c:kill()
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
		awful.button({ mod }, 3, function(c)
			c:activate({ context = "mouse_click", action = "mouse_resize" })
		end),
	})
end)

awful.mouse.append_global_mousebindings({
	awful.button({}, 1, function()
		Launcher:close()
		awesome.emit_signal("close::notify")
		awesome.emit_signal("close::moment")
		awesome.emit_signal("close::control")
		awesome.emit_signal("close::recorder")
		awesome.emit_signal("close::scrotter")
	end),
	awful.button({}, 3, function()
		Menu.desktop:toggle()
	end),
})
client.connect_signal("button::press", function()
	Launcher:close()
	awesome.emit_signal("close::notify")
	awesome.emit_signal("close::moment")
	awesome.emit_signal("close::control")
	awesome.emit_signal("close::recorder")
	awesome.emit_signal("close::scrotter")
end)
