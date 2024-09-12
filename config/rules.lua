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
		rule_any = { class = { "St", "Alacritty" } },
		properties = { tag = "Terminal", switch_to_tags = true },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Google-chrome", "firefox", "Microsoft-edge" } },
		properties = { tag = "Browser", switch_to_tags = true },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Code", "jetbrains-idea", "jetbrains-webstorm", "jetbrains-pycharm", "jetbrains-datagrip", "Docker Desktop", "Postman", "neovide" } },
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
