local awful = require("awful")
local ruled = require("ruled")
local beautiful = require("beautiful")

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
	if beautiful.autohidebar then
		ruled.client.append_rule({
			rule_any = { class = { "Google-chrome", "firefox", "Microsoft-edge" } },
			properties = { tag = "Browser", switch_to_tags = true, maximized_horizontal = true, height = beautiful.height, y = 0 },
		})
	else
		ruled.client.append_rule({
			rule_any = { class = { "Google-chrome", "firefox", "Microsoft-edge" } },
			properties = { tag = "Browser", switch_to_tags = true, maximized = true },
		})
	end
	ruled.client.append_rule({
		rule_any = { class = { "Code", "jetbrains-idea", "jetbrains-webstorm", "jetbrains-pycharm", "Docker Desktop", "Postman", "neovide" } },
		properties = { tag = "Develop" },
	})
	ruled.client.append_rule({
		rule_any = { class = { "discord", "Telegram", "Spotify", "Notion" } },
		properties = { tag = "Media" },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Thunar", "vlc", "libreoffice-impress", "libreoffice-writer", "libreoffice-calc" } },
		properties = { tag = "Other", switch_to_tags = true },
	})
end)
