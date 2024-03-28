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
		style = { shape = helpers.rrect(5) },
		screen = s,
		filter = awful.widget.taglist.filter.all,
		buttons = {
			awful.button({}, 1, function(t)
				t:view_only()
			end),
			awful.button({}, 4, function(t)
				awful.tag.viewprev(t.screen)
			end),
			awful.button({}, 5, function(t)
				awful.tag.viewnext(t.screen)
			end),
		},
		widget_template = {
			{
				id = "background_role",
				widget = wibox.container.background,
				forced_height = 12,
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
						self.taganim:set(60)
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
			forced_height = 10,
			widget = wibox.container.background,
			bg = beautiful.background,
			shape = helpers.rrect(5),
		},
		widget = wibox.container.margin,
		top = 10,
		bottom = 10,
	})
	return tags
end
