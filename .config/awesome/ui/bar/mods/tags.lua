local awful = require("awful")
local wibox = require("wibox")
local helpers = require("helpers")
local animation = require("modules.animation")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi

return function(s)
	local taglist = awful.widget.taglist({
		layout = {
			spacing = dpi(10),
			layout = wibox.layout.fixed.horizontal,
		},
		style = { shape = helpers.rrect(9) },
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
				{
					markup = "",
					shape = helpers.rrect(3),
					widget = wibox.widget.textbox,
				},
				valign = "center",
				id = "background_role",
				shape = helpers.rrect(1),
				widget = wibox.container.background,
				forced_width = dpi(60),
				forced_height = dpi(15),
			},
			widget = wibox.container.place,
			create_callback = function(self, tag)
				self.taganim = animation:new({
					duration = 0.3,
					easing = animation.easing.linear,
					update = function(_, pos)
						self:get_children_by_id("background_role")[1].forced_width = pos
					end,
				})
				self.update = function()
					if tag.selected then
						self.taganim:set(dpi(120))
					elseif #tag:clients() > 0 then
						self.taganim:set(dpi(60))
					else
						self.taganim:set(dpi(50))
					end
				end

				self.update()
			end,
			update_callback = function(self)
				self.update()
			end,
		},
	})
	return taglist
end
