local naughty = require("naughty")
local beautiful = require("beautiful")
local wibox = require("wibox")
local awful = require("awful")
local helpers = require("helpers")
local gears = require("gears")
local animation = require("modules.animation")

return function(n)
	local action_widget = {
		{
			id = "text_role",
			align = "center",
			font = beautiful.sans .. " 12",
			widget = wibox.widget.textbox,
		},
		bg = helpers.change_hex_lightness(beautiful.background, 4),
		forced_height = 30,
		shape = helpers.rrect(5),
		widget = wibox.container.background,
	}
	local actions = wibox.widget({
		notification = n,
		base_layout = wibox.widget({
			spacing = 30,
			layout = wibox.layout.flex.horizontal,
		}),
		align = "center",
		widget_template = action_widget,
		style = { underline_normal = false, underline_selected = true },
		widget = naughty.list.actions,
	})

	local image_n = wibox.widget({
		{
			{
				image = n.icon and helpers.cropSurface(1, gears.surface.load_uncached(n.icon))
					or gears.color.recolor_image(beautiful.icon_path .. "awm/awm.png", helpers.randomColor()),
				resize = true,
				clip_shape = helpers.rrect(50),
				widget = wibox.widget.imagebox,
			},
			strategy = "exact",
			height = 140,
			width = 140,
			widget = wibox.container.constraint,
		},
		id = "arc",
		widget = wibox.container.arcchart,
		max_value = 100,
		min_value = 0,
		value = 100,
		rounded_edge = true,
		thickness = 4,
		start_angle = 4.71238898,
		bg = beautiful.blue,
		colors = { beautiful.foreground },
		forced_width = 140,
		forced_height = 140,
	})
	local anim = animation:new({
		duration = 5,
		target = 100,
		reset_on_stop = false,
		easing = animation.easing.linear,
		update = function(_, pos)
			helpers.gc(image_n, "arc"):set_value(pos)
		end,
	})

	local title_n = wibox.widget({
		{
			markup = n.title,
			font = beautiful.sans .. " Medium 15",
			halign = "left",
			widget = wibox.widget.textbox,
		},
		forced_width = 250,
		widget = wibox.container.scroll.horizontal,
		step_function = wibox.container.scroll.step_functions.nonlinear_back_and_forth,
		speed = 40,
	})

	local message_n = wibox.widget({
		markup = helpers.colorizeText("<span weight='normal'>" .. n.message .. "</span>", beautiful.foreground),
		font = beautiful.sans .. " 12",
		halign = "left",
		wrap = "char",
		widget = wibox.widget.textbox,
		forced_width = 300,
	})

	local time_n = wibox.widget({
		markup = helpers.colorizeText(os.date("%H:%M"), beautiful.foreground .. "BF"),
		font = beautiful.sans .. " Medium 11",
		halign = "right",
		widget = wibox.widget.textbox,
	})

	local notification = naughty.layout.box({
		notification = n,
		shape = beautiful.radius,
		bg = beautiful.background,
		widget_template = {
			{
				image_n,
				{
					{
						title_n,
						nil,
						time_n,
						layout = wibox.layout.align.horizontal,
					},
					message_n,
					actions,
					layout = wibox.layout.align.vertical,
				},
				spacing = 30,
				layout = wibox.layout.fixed.horizontal,
				expand = "none",
			},
			widget = wibox.container.margin,
			margins = 30,
		},
	})

	local function find_client_and_tag(class_name)
		for _, c in ipairs(client.get()) do
			if c.class == class_name then
				return c, c.first_tag
			end
		end
		return nil, nil
	end

	local function focus_client_by_class(class_name)
		local c, tag = find_client_and_tag(class_name)
		if c and tag then
			tag:view_only()
			client.focus = c
			c:raise()
		end
	end

	anim:start()
	notification:buttons(gears.table.join(awful.button({}, 1, function()
		anim:stop()
		focus_client_by_class(n.app_name)
		n:destroy(naughty.notification_closed_reason.dismissed_by_user)
	end)))
	anim:connect_signal("ended", function()
		n:destroy(naughty.notification_closed_reason.dismissed_by_user)
	end)
	helpers.hoverCursor(notification)

	return notification
end
