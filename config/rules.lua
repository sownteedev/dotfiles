local awful = require("awful")
local gears = require("gears")
local ruled = require("ruled")
local helpers = require("helpers")

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
		rule_any = { class = { "Google-chrome", "firefox", "Microsoft-edge" } },
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
local window_positions = helpers.readJson(save_file)

client.connect_signal("manage", function(c)
	if c.maximized then
		c.maximized = false
	end
	if c.class and window_positions[c.class] then
		local geo = window_positions[c.class]
		c:geometry({
			x = geo.x,
			y = geo.y,
			width = geo.width,
			height = geo.height
		})
	end
end)

client.connect_signal("unmanage", function(c)
	if c.class and not c.maximized then
		if c.class == "Alacritty" then
			window_positions[c.class] = {
				x = c:geometry().x,
				y = c:geometry().y,
				width = c:geometry().width,
				height = c:geometry().height
			}
		else
			window_positions[c.class] = {
				x = c:geometry().x,
				y = c:geometry().y,
			}
		end
		helpers.writeJson(save_file, window_positions)
	end
end)
