local naughty = require("naughty")
local beautiful = require("beautiful")
local wibox = require("wibox")
local awful = require("awful")
local dpi = beautiful.xresources.apply_dpi
local helpers = require("helpers")
local ruled = require("ruled")
local menubar = require("menubar")
local gears = require("gears")
local animation = require("modules.animation")

naughty.connect_signal("request::icon", function(n, context, hints)
	if context ~= "app_icon" then return end
	local path = menubar.utils.lookup_icon(hints.app_icon) or menubar.utils.lookup_icon(hints.app_icon:lower())
	if path then n.icon = path end
end)

-- naughty config
naughty.config.defaults.timeout         = 10
naughty.config.defaults.title           = "Ding!"
naughty.config.defaults.position        = "top_right"
naughty.config.defaults.screen          = awful.screen.focused()

-- Timeouts
naughty.config.presets.low.timeout      = 10
naughty.config.presets.critical.timeout = 0

-- ruled notification
ruled.notification.connect_signal("request::rules", function()
	ruled.notification.append_rule {
		rule = {},
		properties = { screen = awful.screen.preferred, implicit_timeout = 6 },
	}
end)

--------------------------
naughty.connect_signal("request::display", function(n)
	-- action widget
	local action_widget = {
		{
			{
				id = "text_role",
				align = "center",
				valign = "center",
				font = beautiful.sans .. " 12",
				widget = wibox.widget.textbox
			},
			left = dpi(6),
			right = dpi(6),
			widget = wibox.container.margin
		},
		bg = beautiful.background,
		forced_height = dpi(30),
		shape = helpers.rrect(5),
		widget = wibox.container.background
	}

	-- actions
	local actions = wibox.widget {
		notification = n,
		base_layout = wibox.widget {
			spacing = dpi(8),
			layout = wibox.layout.flex.horizontal
		},
		widget_template = action_widget,
		style = { underline_normal = false, underline_selected = true },
		widget = naughty.list.actions
	}

	-- image
	local image_n = wibox.widget {
		{
			{
				image = n.icon and helpers.cropSurface(1, gears.surface.load_uncached(n.icon)) or
					gears.filesystem.get_configuration_dir() .. "themes/assets/bell.png",
				resize = true,
				halign = "center",
				valign = "center",
				clip_shape = helpers.rrect(50),
				widget = wibox.widget.imagebox,
			},
			strategy = "exact",
			height = dpi(50),
			width = dpi(50),
			widget = wibox.container.constraint,
		},
		id = "arc",
		widget = wibox.container.arcchart,
		max_value = 100,
		min_value = 0,
		value = 100,
		rounded_edge = true,
		thickness = dpi(4),
		start_angle = 4.71238898,
		bg = beautiful.blue,
		colors = { beautiful.foreground },
		forced_width = dpi(80),
		forced_height = dpi(80)
	}
	local anim = animation:new {
		duration = 6,
		target = 100,
		reset_on_stop = false,
		easing = animation.easing.linear,
		update = function(_, pos)
			image_n:get_children_by_id('arc')[1].value = pos
		end,
	}
	anim:connect_signal("ended", function()
		n:destroy()
	end)

	-- title
	local title_n = wibox.widget {
		{
			{
				markup = n.title,
				font   = beautiful.sans .. " 13",
				align  = "right",
				valign = "center",
				widget = wibox.widget.textbox
			},
			forced_width  = dpi(240),
			widget        = wibox.container.scroll.horizontal,
			step_function = wibox.container.scroll.step_functions.waiting_nonlinear_back_and_forth,
			speed         = 50
		},
		widget = wibox.container.margin,
	}


	local message_n = wibox.widget {
		{
			{
				markup = helpers.colorizeText("<span weight='normal'>" .. n.message .. "</span>", beautiful.foreground),
				font   = beautiful.sans .. " 9",
				align  = "left",
				valign = "center",
				wrap   = "char",
				widget = wibox.widget.textbox
			},
			forced_width = dpi(240),
			layout       = wibox.layout.fixed.horizontal
		},
		widget = wibox.container.margin
	}


	-- app name
	local aname = ''
	if n.app_name ~= '' then
		aname = n.app_name
	else
		aname = 'naughty'
	end
	local app_name_n = wibox.widget {
		markup = helpers.colorizeText(aname, beautiful.foreground .. "BF"),
		font   = beautiful.sans .. " 10",
		align  = "left",
		valign = "center",
		widget = wibox.widget.textbox
	}

	local time = os.date "%H:%M:%S"
	local time_n = wibox.widget {
		{
			markup = helpers.colorizeText(time, beautiful.foreground .. "BF"),
			font   = beautiful.sans .. " 10",
			align  = "right",
			valign = "center",
			widget = wibox.widget.textbox
		},
		margins = { right = 20 },
		widget  = wibox.container.margin
	}

	local close = wibox.widget {
		markup = helpers.colorizeText('󰅙 ', beautiful.red),
		font   = beautiful.icon_font .. " 10",
		align  = "ceneter",
		valign = "center",
		widget = wibox.widget.textbox,
	}

	close:buttons(gears.table.join(
		awful.button({}, 1, function() n:destroy(naughty.notification_closed_reason.dismissed_by_user) end)))


	-- extra info
	local notif_info = wibox.widget {
		app_name_n,
		{
			widget = wibox.widget.separator,
			shape = gears.shape.circle,
			forced_height = dpi(4),
			forced_width = dpi(4),
			color = beautiful.foreground .. "BF"
		},
		time_n,
		layout = wibox.layout.fixed.horizontal,
		spacing = dpi(5)
	}

	local widget = naughty.layout.box {
		notification    = n,
		shape           = helpers.rrect(10),
		widget_template = {
			{
				{
					{
						{
							{
								close,
								nil,
								notif_info,
								layout = wibox.layout.align.horizontal,
								expand = "none"
							},
							margins = { left = dpi(20), right = dpi(10), top = dpi(10), bottom = dpi(10) },
							widget = wibox.container.margin
						},
						widget = wibox.container.background,
						bg = beautiful.background,
					},
					layout = wibox.layout.fixed.vertical
				},
				{
					-- body
					{
						{
							title_n,
							message_n,
							layout = wibox.layout.fixed.vertical,
							spacing = dpi(5)
						},
						nil,
						image_n,
						layout = wibox.layout.align.horizontal,
						expand = "none"
					},
					margins = { left = dpi(20), top = dpi(10), right = dpi(30) },
					widget = wibox.container.margin
				},
				{
					actions,
					margins = dpi(5),
					widget = wibox.container.margin
				},
				layout = wibox.layout.fixed.vertical,
				spacing = dpi(10)
			},
			widget = wibox.container.background,
			bg = beautiful.background_dark,
		}
	}

	widget.buttons = {}
	anim:start()
end)
