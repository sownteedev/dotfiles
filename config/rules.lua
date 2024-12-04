local awful = require("awful")
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
			placement = awful.placement.no_offscreen,
		},
	})

	ruled.client.append_rule({
		id = "titlebars",
		rule_any = { type = { "normal", "dialog" } },
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
		rule_any = { class = { "Notion", "discord", "armcord", "vesktop", "Caprine", "Zalo", "Telegram", "Spotify", "YouTube Music", _User.Custom_Icon[1].name } },
		properties = { tag = "Media" },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Thunar", "Nemo", "vlc", "libreoffice-impress", "libreoffice-writer", "libreoffice-calc" } },
		properties = { tag = "Other", switch_to_tags = true },
	})
end)

client.connect_signal("request::manage", function(c)
	if c.x == 0 and c.y == 40 then
		awful.placement.centered(c)
	end
end)
