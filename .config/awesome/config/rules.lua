local awful = require("awful")
local ruled = require("ruled")
local helpers = require("helpers")

awful.layout.layouts = {
	awful.layout.suit.floating,
	awful.layout.suit.tile,
}

ruled.client.connect_signal("request::rules", function()
	ruled.client.append_rule({
		id = "global",
		rule = {},
		properties = {
			raise = true,
			size_hints_honor = false,
			honor_workarea = true,
			honor_padding = true,
			screen = awful.screen.focused,
			focus = awful.client.focus.filter,
			placement = awful.placement.no_overlap + awful.placement.no_offscreen,
		},
	})

	--- Centered
	ruled.client.append_rule({
		id = "centered",
		rule = {},
		properties = { placement = helpers.centered_client_placement },
	})

	-- Titlebars
	ruled.client.append_rule({
		id = "titlebars",
		rule_any = { type = { "normal", "dialog" } },
		properties = { titlebars_enabled = true },
	})

	ruled.client.append_rule({
		rule = { class = "Alacritty" },
		properties = { screen = 1, tag = "1", switch_to_tags = true, width = 1920, height = 1080 },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Google-chrome", "firefox", "Microsoft-edge" } },
		properties = { screen = 1, tag = "2", switch_to_tags = true, maximized = true },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Code", "jetbrains-idea", "webstom", "neovide" } },
		properties = { screen = 1, tag = "3" },
	})
	ruled.client.append_rule({
		rule_any = { class = { "discord", "Telegram" } },
		properties = { screen = 1, tag = "4" },
	})
	ruled.client.append_rule({
		rule = { class = "Spotify" },
		properties = { screen = 1, tag = "4", switch_to_tags = true },
	})
	ruled.client.append_rule({
		rule_any = { class = { "Thunar", "vlc", "libreoffice-impress", "libreoffice-calc", "libreoffice-writer" } },
		properties = { tag = "5", switch_to_tags = true },
	})
end)

client.connect_signal("request::manage", function(c)
	if c.transient_for then
		awful.placement.centered(c, c.transient_for)
		awful.placement.no_offscreen(c)
	end
end)
