local awful = require("awful")
require("awful.hotkeys_popup.keys")
local xrandr = require("config.xrandr")
local switcher = require("modules.awesome-switcher")

local mod = "Mod4"
local alt = "Mod1"
local ctrl = "Control"
local shift = "Shift"

awful.keyboard.append_global_keybindings({
	-- Apps
	awful.key({ mod }, "d", function() awful.spawn("rofi -show drun -theme .config/configs/launcher.rasi") end),
	awful.key({ mod }, "e", function() awful.spawn("thunar") end),

	-- Volume and Brightness
	awful.key({}, "XF86AudioPlay", function() awful.spawn.with_shell("playerctl play-pause") end),
	awful.key({}, "XF86AudioPrev", function() awful.spawn.with_shell("playerctl previous") end),
	awful.key({}, "XF86AudioNext", function() awful.spawn.with_shell("playerctl next") end),
	awful.key({}, "XF86AudioRaiseVolume", function()
		awful.spawn.with_shell("pactl set-sink-volume @DEFAULT_SINK@ +2%")
		update_value_of_volume()
		awesome.emit_signal("summon::osd")
	end),
	awful.key({}, "XF86AudioLowerVolume", function()
		awful.spawn.with_shell("pactl set-sink-volume @DEFAULT_SINK@ -2%")
		update_value_of_volume()
		awesome.emit_signal("summon::osd")
	end),
	awful.key({}, "XF86AudioMute", function()
		awful.spawn.with_shell("pactl set-sink-mute @DEFAULT_SINK@ toggle")
		update_value_of_volume()
		awesome.emit_signal("summon::osd")
	end),
	awful.key({}, "XF86MonBrightnessUp", function()
		awful.spawn.with_shell("brightnessctl s 5%+")
		update_value_of_bright()
		awesome.emit_signal("summon::osd")
	end),
	awful.key({}, "XF86MonBrightnessDown", function()
		awful.spawn.with_shell("brightnessctl s 5%-")
		update_value_of_bright()
		awesome.emit_signal("summon::osd")
	end),

	-- Scripts
	awful.key({}, "Print", function() awful.spawn.with_shell("~/.config/scripts/Screenshot/Screenshot") end),
	awful.key({ alt, }, "p", function() awful.spawn.with_shell("~/.config/scripts/colorpicker") end),
	awful.key({ alt, }, "w", function() awful.spawn.with_shell("~/.config/scripts/Network/Network") end),
	awful.key({ alt, }, "b", function() awful.spawn.with_shell("~/.config/scripts/Bluetooth/Bluetooth") end),
	awful.key({ alt, }, "m", function() awesome.emit_signal("mplayer::toggle") end),
	awful.key({ alt, }, "F4", function() awful.spawn.with_shell("~/.config/scripts/Power/PowerMenu") end),
	awful.key({ alt, }, "space", function() awful.spawn.with_shell("~/.config/scripts/RiceSelect/RiceSelector") end),
	awful.key({ alt }, "l", function() awful.spawn.with_shell("betterlockscreen -l dimblur") end),
	awful.key({ mod, alt }, "w", function() awful.spawn.with_shell("feh -z --no-fehbg --bg-fill ~/.walls") end),
	awful.key({ mod, shift }, "b", function() awesome.emit_signal("hide::bar") end),
	awful.key({ mod, }, "Return", function() awful.spawn("alacritty") end),
	awful.key({ mod, ctrl }, "p", function() xrandr.xrandr() end),
	awful.key({ mod, alt }, "r", awesome.restart),
	awful.key({ mod, alt }, "q", awesome.quit)
})

-- Focus related keybindings
awful.keyboard.append_global_keybindings({
	awful.key({ mod, ctrl }, "j", function() awful.screen.focus_relative(1) end,
		{ description = "focus the next screen", group = "screen" }),
	awful.key({ mod, ctrl }, "k", function() awful.screen.focus_relative(-1) end,
		{ description = "focus the previous screen", group = "screen" }),
	awful.key({ mod, ctrl }, "n",
		function()
			local c = awful.client.restore()
			if c then
				c:activate { raise = true, context = "key.unminimize" }
			end
		end,
		{ description = "restore minimized", group = "client" }),
})

-- Layout related keybindings
awful.keyboard.append_global_keybindings({
	awful.key({ mod, }, "u", awful.client.urgent.jumpto,
		{ description = "jump to urgent client", group = "client" }),
	awful.key({ mod, }, "h", function() awful.tag.incmwfact(-0.05) end,
		{ description = "decrease master width factor", group = "layout" }),
	awful.key({ mod, }, "l", function() awful.tag.incmwfact(0.05) end,
		{ description = "increase master width factor", group = "layout" }),
	awful.key({ mod, shift }, "j", function() awful.client.swap.byidx(1) end,
		{ description = "swap with next client by index", group = "client" }),
	awful.key({ mod, shift }, "k", function() awful.client.swap.byidx(-1) end,
		{ description = "swap with previous client by index", group = "client" }),
	awful.key({ mod, shift }, "h", function() awful.tag.incnmaster(1, nil, true) end,
		{ description = "increase the number of master clients", group = "layout" }),
	awful.key({ mod, shift }, "l", function() awful.tag.incnmaster(-1, nil, true) end,
		{ description = "decrease the number of master clients", group = "layout" }),
	awful.key({ mod, ctrl }, "h", function() awful.tag.incncol(1, nil, true) end,
		{ description = "increase the number of columns", group = "layout" }),
	awful.key({ mod, ctrl }, "l", function() awful.tag.incncol(-1, nil, true) end,
		{ description = "decrease the number of columns", group = "layout" }),
})

-- Switch between windows
awful.keyboard.append_global_keybindings({
	-- Tag
	awful.key({ mod, shift }, "Tab", awful.tag.viewnext),
	awful.key({ mod, ctrl }, "Tab", awful.tag.viewprev),
	awful.key({ mod }, "Tab", awful.tag.history.restore),
	-- Client
	awful.key({ alt }, "Tab", function() switcher.switch(1, "Mod1", "Alt_L", "Shift", "Tab") end),
	awful.key({ alt, shift }, "Tab", function() switcher.switch(-1, "Mod1", "Alt_L", "Shift", "Tab") end),
})

awful.keyboard.append_global_keybindings({
	awful.key {
		modifiers = { mod },
		keygroup  = "numrow",
		group     = "tag",
		on_press  = function(index)
			local screen = awful.screen.focused()
			local tag = screen.tags[index]
			if tag then
				tag:view_only()
			end
		end,
	},
	awful.key {
		modifiers   = { mod, ctrl },
		keygroup    = "numrow",
		description = "toggle tag",
		group       = "tag",
		on_press    = function(index)
			local screen = awful.screen.focused()
			local tag = screen.tags[index]
			if tag then
				awful.tag.viewtoggle(tag)
			end
		end,
	},
	awful.key {
		modifiers = { mod, shift },
		keygroup  = "numrow",
		group     = "tag",
		on_press  = function(index)
			if client.focus then
				local tag = client.focus.screen.tags[index]
				if tag then
					client.focus:move_to_tag(tag)
				end
			end
		end,
	},
	awful.key {
		modifiers   = { mod, ctrl, shift },
		keygroup    = "numrow",
		description = "toggle focused client on tag",
		group       = "tag",
		on_press    = function(index)
			if client.focus then
				local tag = client.focus.screen.tags[index]
				if tag then
					client.focus:toggle_tag(tag)
				end
			end
		end,
	},
	awful.key {
		modifiers   = { mod },
		keygroup    = "numpad",
		description = "select layout directly",
		group       = "layout",
		on_press    = function(index)
			local t = awful.screen.focused().selected_tag
			if t then
				t.layout = t.layouts[index] or t.layout
			end
		end,
	}
})

client.connect_signal("request::default_keybindings", function()
	awful.keyboard.append_client_keybindings({
		awful.key({ mod, }, "f",
			function(c)
				c.fullscreen = not c.fullscreen
				c:raise()
			end),
		awful.key({ mod, shift }, "f", awful.client.floating.toggle),
		awful.key({ mod, shift }, "q", function(c) c:kill() end),
		awful.key({ mod, }, "n", function(c) c.minimized = true end),
		awful.key({ mod, }, "m",
			function(c)
				c.maximized = not c.maximized
				c:raise()
			end
		),
	})
end)


-- MOUSE
client.connect_signal("request::default_mousebindings", function()
	awful.mouse.append_client_mousebindings({
		awful.button({}, 1, function(c)
			c:activate { context = "mouse_click" }
		end),
		awful.button({ mod }, 1, function(c)
			c:activate { context = "mouse_click", action = "mouse_move" }
		end),
		awful.button({ mod }, 3, function(c)
			c:activate { context = "mouse_click", action = "mouse_resize" }
		end),
	})
end)

-- awful.mouse.append_global_mousebindings({
-- awful.button({}, 3, function() mymainmenu:toggle() end),
-- awful.button({}, 4, awful.tag.viewprev),
-- awful.button({}, 5, awful.tag.viewnext),
-- })
