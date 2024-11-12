local awful = require("awful")
local gears = require("gears")
local ruled = require("ruled")

ruled.notification.connect_signal("request::rules", function()
	ruled.notification.append_rule({
		rule = {},
		properties = { screen = awful.screen.preferred, implicit_timeout = 5 },
	})
end)

ruled.client.connect_signal("request::rules", function()
	ruled.client.append_rule({
		id = "global",
		rule = {},
		properties = {
			raise     = true,
			screen    = awful.screen.preferred,
			focus     = awful.client.focus.filter,
			placement = awful.placement.no_offscreen + awful.placement.centered,
		},
	})

	-- Titlebars
	ruled.client.append_rule({
		id = "titlebars",
		rule_any = { type = { "normal", "dialog" } },
		except_any = { class = { "Ulauncher" } },
		properties = { titlebars_enabled = true },
	})

	ruled.client.append_rule({
		rule_any = { class = { "St", "Alacritty", "Kitty" } },
		properties = { tag = "Terminal", switch_to_tags = true },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Google-chrome", "firefox", "Microsoft-edge", "zen-alpha" } },
		properties = { tag = "Browser", switch_to_tags = true },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Code", "jetbrains-idea", "jetbrains-webstorm", "jetbrains-pycharm", "jetbrains-datagrip", "jetbrains-studio", "MongoDB Compass", "Mysql-workbench-bin", "Docker Desktop", "Postman", "neovide" } },
		properties = { tag = "Develop" },
	})
	ruled.client.append_rule({
		rule_any = { class = { "discord", "armcord", "vesktop", "Caprine", "Telegram", "Spotify", "Notion" } },
		properties = { tag = "Media" },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Thunar", "Nemo", "vlc", "libreoffice-impress", "libreoffice-writer", "libreoffice-calc" } },
		properties = { tag = "Other", switch_to_tags = true },
	})
end)

local save_file = gears.filesystem.get_cache_dir() .. "window_positions.json"
local window_positions = _Utils.json.readJson(save_file)

local function save_window_position(c)
	if not (c.class and not c.maximized) then return end

	local geometry = c:geometry()
	window_positions[c.class] = {
		x = geometry.x,
		y = geometry.y,
		width = c.class == "Alacritty" and geometry.width or nil,
		height = c.class == "Alacritty" and geometry.height or nil
	}

	_Utils.json.writeJson(save_file, window_positions)
end

local function apply_window_position(c)
	if not (c.class and window_positions[c.class]) then return end

	local geo = window_positions[c.class]
	c:geometry({
		x = geo.x,
		y = geo.y,
		width = geo.width,
		height = geo.height
	})
end

client.connect_signal("request::manage", function(c)
	if awesome.startup then
		if not (c.size_hints.user_position or c.size_hints.program_position) then
			awful.placement.no_offscreen(c)
		end
	else
		awful.client.setslave(c)
	end

	if c.maximized then
		c.maximized = false
	end

	apply_window_position(c)
end)

client.connect_signal("unmanage", function(c)
	save_window_position(c)
end)
