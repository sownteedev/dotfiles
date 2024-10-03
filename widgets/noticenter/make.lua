local helpers = require("helpers")
local beautiful = require("beautiful")
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local naughty = require("naughty")

return function(icon, n)
	local action_widget = {
		{
			{
				{
					{
						id            = "icon_role",
						forced_height = 1,
						forced_width  = 1,
						widget        = wibox.widget.imagebox
					},
					top = 5,
					bottom = 5,
					widget = wibox.container.margin,
				},
				{
					id = "text_role",
					font = beautiful.sans .. " 12",
					widget = wibox.widget.textbox,
				},
				layout = wibox.layout.fixed.horizontal,
			},
			align = "center",
			widget = wibox.container.place,
		},
		bg = beautiful.lighter1,
		forced_height = 30,
		shape = helpers.rrect(5),
		widget = wibox.container.background,
	}
	local actions       = wibox.widget({
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

	local icon_widget   = wibox.widget({
		widget = wibox.widget.imagebox,
		image = helpers.cropSurface(1, gears.surface.load_uncached(icon)),
		resize = true,
		clip_shape = gears.shape.circle,
	})

	local title_widget  = wibox.widget({
		{
			markup = n.title,
			font = beautiful.sans .. " Medium 15",
			align = "right",
			widget = wibox.widget.textbox,
		},
		forced_width = 250,
		widget = wibox.container.scroll.horizontal,
		step_function = wibox.container.scroll.step_functions.nonlinear_back_and_forth,
		speed = 40,
	})

	local time_widget   = wibox.widget({
		markup = helpers.colorizeText(os.date("%H:%M"), beautiful.foreground .. "BF"),
		font = beautiful.sans .. " Medium 11",
		halign = "right",
		widget = wibox.widget.textbox,
	})

	local text_notif    = wibox.widget({
		{
			markup = helpers.colorizeText("<span weight='normal'>" .. n.message .. "</span>", beautiful.foreground),
			font = beautiful.sans .. " 12",
			align = "left",
			wrap = "char",
			widget = wibox.widget.textbox,
		},
		forced_width = 300,
		layout = wibox.layout.fixed.horizontal,
	})

	local box           = wibox.widget({
		id = "bg",
		widget = wibox.container.background,
		forced_height = 180,
		shape = beautiful.radius,
		bg = beautiful.lighter,
		{
			{
				icon_widget,
				{
					{
						title_widget,
						nil,
						time_widget,
						layout = wibox.layout.align.horizontal,
					},
					text_notif,
					actions,
					layout = wibox.layout.align.vertical,
				},
				spacing = 30,
				layout = wibox.layout.fixed.horizontal,
				expand = "none",
			},
			widget = wibox.container.margin,
			margins = 20,
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

	box:buttons(gears.table.join(awful.button({}, 1, function()
		_G.notif_center_remove_notif(box)
		focus_client_by_class(n.app_name)
	end)))

	helpers.hoverCursor(box)
	helpers.addHoverBg(box, "bg", beautiful.lighter, beautiful.lighter1)

	return box
end
