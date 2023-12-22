local awful = require("awful")
local ruled = require("ruled")
local helpers = require("helpers")

awful.layout.layouts = {
	awful.layout.suit.floating,
	awful.layout.suit.tile,
}

ruled.client.connect_signal("request::rules", function()
	ruled.client.append_rule {
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
		}
	}

	--- Centered
	ruled.client.append_rule({
		id = "centered",
		rule = {},
		properties = { placement = helpers.centered_client_placement },
	})

	-- Titlebars
	ruled.client.append_rule {
		id         = "titlebars",
		rule_any   = { type = { "normal", "dialog" } },
		properties = { titlebars_enabled = true }
	}

	ruled.client.append_rule {
		rule       = { class = "Alacritty" },
		properties = { screen = 1, tag = "1" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Google-chrome", "firefox" } },
		properties = { screen = 1, tag = "2" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Code", "jetbrains-idea", "neovide" } },
		properties = { screen = 1, tag = "3" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "discord", "Telegram", "Spotify" } },
		properties = { screen = 1, tag = "4" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Thunar", "vlc" } },
		properties = { tag = "5" }
	}
end)

client.connect_signal('request::manage', function(c)
	if c.transient_for then
		awful.placement.centered(c, c.transient_for)
		awful.placement.no_offscreen(c)
	end
end)

-- client.connect_signal("mouse::enter", function(c)
-- 	c:activate { context = "mouse_enter", raise = false }
-- end)
