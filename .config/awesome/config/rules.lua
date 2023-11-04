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
		properties = { tag = "1", switch_to_tags = true }
	}
	ruled.client.append_rule {
		rule       = { class = "Google-chrome" },
		properties = { tag = "2", switch_to_tags = true }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Code", "jetbrains-idea", "neovide" } },
		properties = { tag = "3" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "discord", "Telegram" } },
		properties = { tag = "4" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Spotify" } },
		properties = { screen = 1, tag = "5" }
	}
	ruled.client.append_rule {
		rule_any   = { class = { "Thunar", "vlc" } },
		properties = { tag = "7", switch_to_tags = true }
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
