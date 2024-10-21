local helpers = require("helpers")
local beautiful = require("beautiful")
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")

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
		bg = beautiful.lighter2,
		forced_height = 25,
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

	local app_icon = wibox.widget({
		image = helpers.getIcon(nil, n.app_name, n.app_name),
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
		forced_height = 50,
		forced_width = 50,
		valign = "center",
		widget = wibox.widget.imagebox,
	})

	local title_n = wibox.widget({
		{
			markup = n.title,
			font = beautiful.sans .. " Medium 13",
			halign = "left",
			widget = wibox.widget.textbox,
		},
		widget = wibox.container.scroll.horizontal,
		step_function = wibox.container.scroll.step_functions.nonlinear_back_and_forth,
		speed = 40,
		forced_width = 340,
	})

	local message_n = wibox.widget({
		markup = n.message,
		font = beautiful.sans .. " 11",
		halign = "left",
		wrap = "char",
		forced_width = 400,
		widget = wibox.widget.textbox,
	})

	local time = wibox.widget({
		markup = "",
		font = beautiful.sans .. " 11",
		halign = "left",
		widget = wibox.widget.textbox,
	})

	local function format_time_difference(start_time)
		local current_time = os.time()
		local diff = os.difftime(current_time, start_time)

		if diff < 60 then
			return "now"
		elseif diff < 3600 then
			local minutes = math.floor(diff / 60)
			return minutes .. "m ago"
		elseif diff < 7200 then
			local hours = math.floor(diff / 3600)
			return hours .. "h ago"
		else
			return os.date("%H:%M", start_time)
		end
	end

	local function update_time_widget(start_time)
		time.markup = helpers.colorizeText(format_time_difference(start_time), beautiful.foreground .. "AA")
	end

	local notification_template = {
		app_icon,
		{
			{
				{
					title_n,
					nil,
					time,
					layout = wibox.layout.align.horizontal,
				},
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

	if n.icon then
		message_n.forced_width = 340
		notification_template = {
			{
				app_icon,
				{
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
					valign = "center",
					widget = wibox.container.place,
				},
				spacing = 20,
				layout = wibox.layout.fixed.horizontal,
				expand = "none",
			},
			nil,
			{
				{
					time,
					top = -10,
					widget = wibox.container.margin,
				},
				image,
				spacing = 5,
				layout = wibox.layout.fixed.vertical,
			},
			layout = wibox.layout.align.horizontal,
		}
	end

	if n.actions and #n.actions > 0 then
		if n.icon then
			table.insert(notification_template[1][2][1], actions)
		else
			table.insert(notification_template[2], actions)
		end
	end

	local box = wibox.widget({
		{
			id = "bg",
			shape = beautiful.radius,
			bg = beautiful.lighter,
			shape_border_width = beautiful.border_width,
			shape_border_color = beautiful.lighter1,
			widget = wibox.container.background,
			{
				notification_template,
				widget = wibox.container.margin,
				margins = 20,
			},
		},
		widget = wibox.container.constraint,
		height = 300,
		strategy = "max",
	})

	local function get_timer_timeout(start_time)
		local current_time = os.time()
		local diff = os.difftime(current_time, start_time)
		if diff >= 10800 then
			return 1000000
		elseif diff >= 3600 then
			return 3600
		else
			return 60
		end
	end

	local notification_time = os.time()
	local initial_timeout = get_timer_timeout(notification_time)
	update_time_widget(notification_time)

	box.timer = gears.timer({
		timeout = initial_timeout,
		call_now = false,
		autostart = true,
		callback = function()
			update_time_widget(notification_time)
			box.timer.timeout = get_timer_timeout()
		end
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

	box:buttons(gears.table.join(awful.button({}, 1, function()
		_G.notif_center_remove_notif(box)
		focus_client_by_class(n.app_name)
	end)))

	helpers.hoverCursor(box)
	helpers.addHoverBg(box, "bg", beautiful.lighter, beautiful.lighter1)

	return box
end
