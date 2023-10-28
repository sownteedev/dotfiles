local awful = require("awful")
local ruled = require("ruled")

ruled.client.connect_signal("request::rules", function()
	ruled.client.append_rule {
		id = "global",
		rule = {},
		properties = {
			focus = awful.client.focus.filter,
			raise = true,
			size_hints_honor = false,
			screen = awful.screen.preferred,
			placement = function(c)
				awful.placement.centered(c, c.transient_for)
				awful.placement.no_overlap(c)
				awful.placement.no_offscreen(c)
			end,
		}
	}

	-- Add titlebars to normal clients and dialogs
	ruled.client.append_rule {
		id         = "titlebars",
		rule_any   = { type = { "normal", "dialog" } },
		properties = { titlebars_enabled = true }
	}
	ruled.client.append_rule {
		rule       = { class = "kitty" },
		properties = { screen = 1, tag = "1" }
	}
	ruled.client.append_rule {
		rule       = { class = "Google-chrome" },
		properties = { screen = 1, tag = "2" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Code", "jetbrains-idea", "neovide" } },
		properties = { screen = 1, tag = "3" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "discord", "Telegram" } },
		properties = { screen = 1, tag = "4" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Spotify" } },
		properties = { screen = 1, tag = "5" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Thunar", "vlc" } },
		properties = { tag = "7" }
	}
end)

ruled.notification.connect_signal('request::rules', function()
	-- All notifications will match this rule.
	ruled.notification.append_rule {
		rule       = {},
		properties = {
			screen           = awful.screen.preferred,
			implicit_timeout = 5,
		}
	}
end)

client.connect_signal("mouse::enter", function(c)
	c:activate { context = "mouse_enter", raise = false }
end)

client.connect_signal('request::manage', function(c)
	if c.transient_for then
		awful.placement.centered(c, c.transient_for)
		awful.placement.no_offscreen(c)
	end
end)
