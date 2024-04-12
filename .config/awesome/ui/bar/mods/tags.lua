local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")
local beautiful = require("beautiful")
local animation = require("modules.animation")

return function(s)
	local taglist = awful.widget.taglist({
		layout = {
			spacing = 10,
			layout = wibox.layout.fixed.horizontal,
		},
		style = { shape = helpers.rrect(10) },
		screen = s,
		filter = awful.widget.taglist.filter.all,
		buttons = {
			awful.button({}, 1, function(t)
				t:view_only()
			end),
		},
		widget_template = {
			{
				id = "background_role",
				widget = wibox.container.background,
				forced_height = 15,
			},
			widget = wibox.container.place,
			create_callback = function(self, tag)
				self.taganim = animation:new({
					duration = 0.1,
					easing = animation.easing.linear,
					update = function(_, pos)
						helpers.gc(self, "background_role"):set_forced_width(pos)
					end,
				})
				self.update = function()
					if tag.selected then
						self.taganim:set(100)
					elseif #tag:clients() > 0 then
						self.taganim:set(70)
					else
						self.taganim:set(40)
					end
				end

				self.update()
			end,
			update_callback = function(self)
				self.update()
			end,
		},
	})

	local tags = wibox.widget({
		{
			{
				{
					taglist,
					layout = wibox.layout.fixed.horizontal,
				},
				widget = wibox.container.margin,
				left = 20,
				right = 20,
			},
			widget = wibox.container.background,
			bg = beautiful.background,
			shape = helpers.rrect(10),
		},
		widget = wibox.container.margin,
		top = 5,
		bottom = 5,
	})
	return tags
end
