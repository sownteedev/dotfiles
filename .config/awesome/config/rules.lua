local awful = require("awful")
local ruled = require("ruled")
local helpers = require("helpers")

awful.layout.layouts = {
	awful.layout.suit.floating,
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

	ruled.client.append_rule {
		id         = "titlebars",
		rule_any   = { type = { "normal", "dialog" } },
		properties = { titlebars_enabled = true }
	}
end)

client.connect_signal('request::manage', function(c)
	if c.transient_for then
		awful.placement.centered(c, c.transient_for)
		awful.placement.no_offscreen(c)
	end
end)
