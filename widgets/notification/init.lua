local naughty = require("naughty")
local beautiful = require("beautiful")
local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")

return function(n)
	local action_widget = {
		{
			{
				id = "text_role",
				font = beautiful.sans .. " 10",
				widget = wibox.widget.textbox,
			},
			align = "center",
			widget = wibox.container.place,
		},
		bg = beautiful.lighter1,
		forced_height = 25,
		shape = _Utils.widget.rrect(5),
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

	local app_icon = wibox.widget({
		image = _Utils.icon.getIcon(nil, n.app_name, n.app_name),
		resize = true,
		forced_height = 60,
		forced_width = 60,
		valign = "center",
		widget = wibox.widget.imagebox,
	})

	local image = wibox.widget({
		image = n.icon,
		resize = true,
		clip_shape = beautiful.radius,
		forced_height = 60,
		forced_width = 60,
		valign = "center",
		widget = wibox.widget.imagebox,
	})

	local title_n = wibox.widget({
		{
			{
				markup = n.title,
				font = beautiful.sans .. " Medium 13",
				halign = "left",
				widget = wibox.widget.textbox,
			},
			widget = wibox.container.scroll.horizontal,
			step_function = wibox.container.scroll.step_functions.nonlinear_back_and_forth,
			speed = 40,
		},
		widget = wibox.container.constraint,
		width = 310,
		strategy = "max",
	})

	local message_n = wibox.widget({
		{
			markup = n.message,
			font = beautiful.sans .. " 11",
			halign = "left",
			widget = wibox.widget.textbox,
		},
		widget = wibox.container.constraint,
		width = 310,
		strategy = "max",
	})

	local notification_template = {
		app_icon,
		{
			{
				title_n,
				message_n,
				spacing = 10,
				layout = wibox.layout.fixed.vertical,
			},
			spacing = 20,
			layout = wibox.layout.fixed.vertical,
		},
		spacing = 20,
		layout = wibox.layout.fixed.horizontal,
		expand = "none",
	}

	if n.actions and #n.actions > 0 then
		table.insert(notification_template[2], actions)
	end

	if n.icon then
		table.insert(notification_template, image)
	end

	local notification = naughty.layout.box({
		notification    = n,
		shape           = beautiful.radius,
		border_width    = beautiful.border_width,
		border_color    = beautiful.lighter,
		bg              = beautiful.background .. "EE",
		maximum_width   = 500,
		cursor          = "hand2",
		widget_template = {
			notification_template,
			widget = wibox.container.margin,
			margins = 20,
		},
	})

	local function focus_client_by_class(class_name)
		local clients = client.get()
		for i = 1, #clients do
			local c = clients[i]
			if c.class == class_name then
				local tag = c.first_tag
				if tag then
					tag:view_only()
					client.focus = c
					c:raise()
					return
				end
			end
		end
	end

	notification:buttons(gears.table.join(awful.button({}, 1, function()
		focus_client_by_class(n.app_name)
		n:destroy(naughty.notification_closed_reason.dismissed_by_user)
	end)))

	return notification
end
