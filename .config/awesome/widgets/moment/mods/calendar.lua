local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local datewidget = function(date, weekend, notIn)
	weekend = weekend or false
	if notIn then
		return wibox.widget({
			markup = helpers.colorizeText(date, beautiful.foreground),
			align = "center",
			font = beautiful.sans .. " 15",
			widget = wibox.widget.textbox,
		})
	else
		return wibox.widget({
			markup = weekend and helpers.colorizeText(date, beautiful.foreground) or date,
			align = "center",
			font = beautiful.sans .. " 15",
			widget = wibox.widget.textbox,
		})
	end
end

local daywidget = function(day, weekend, notIn)
	weekend = weekend or false
	return wibox.widget({
		markup = weekend and helpers.colorizeText(day, beautiful.red) or day,
		align = "center",
		font = beautiful.sans .. " Medium 15",
		widget = wibox.widget.textbox,
	})
end
local currwidget = function(day)
	return wibox.widget({
		{
			markup = helpers.colorizeText(day, beautiful.foreground),
			align = "center",
			font = beautiful.sans .. " 15",
			widget = wibox.widget.textbox,
		},
		widget = wibox.container.background,
		bg = helpers.blend(beautiful.blue, beautiful.background, 0.5),
		shape = helpers.rrect(50),
	})
end

local theGrid = wibox.widget({
	forced_num_rows = 7,
	forced_num_cols = 7,
	vertical_spacing = 25,
	horizontal_spacing = 25,
	min_cols_size = 40,
	min_rows_size = 40,
	homogenous = true,
	layout = wibox.layout.grid,
})

local title = wibox.widget({
	{
		{
			{
				id = "text",
				font = beautiful.sans .. " Bold 20",
				widget = wibox.widget.textbox,
				align = "center",
			},
			widget = wibox.container.margin,
			margins = 10,
		},
		widget = wibox.container.background,
		bg = beautiful.lighter1,
		shape = helpers.rrect(10),
	},
	widget = wibox.container.margin,
	left = 60,
	right = 60,
})

local curr

local updateCalendar = function(date)
	helpers.gc(title, "text").markup = os.date("%B %Y", os.time(date))
	theGrid:reset()
	for _, w in ipairs({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }) do
		if w == "Sun" or w == "Sat" then
			theGrid:add(daywidget(w, true, false))
		else
			theGrid:add(daywidget(w, false, false))
		end
	end
	local firstDate = os.date("*t", os.time({ day = 1, month = date.month, year = date.year }))
	local lastDate = os.date("*t", os.time({ day = 0, month = date.month + 1, year = date.year }))
	local days_to_add_at_month_start = firstDate.wday - 1
	local days_to_add_at_month_end = 42 - lastDate.day - days_to_add_at_month_start

	local previous_month_last_day = os.date("*t", os.time({ year = date.year, month = date.month, day = 0 })).day
	local row = 2
	local col = firstDate.wday

	for day = previous_month_last_day - days_to_add_at_month_start, previous_month_last_day - 1, 1 do
		theGrid:add(datewidget(day, false, true))
	end

	for day = 1, lastDate.day do
		if day == date.day then
			theGrid:add_widget_at(currwidget(day), row, col)
		elseif col == 1 or col == 7 then
			theGrid:add_widget_at(datewidget(day, true, false), row, col)
		else
			theGrid:add_widget_at(datewidget(day, false, false), row, col)
		end

		if col == 7 then
			col = 1
			row = row + 1
		else
			col = col + 1
		end
	end

	for day = 1, days_to_add_at_month_end do
		theGrid:add(datewidget(day, false, true))
	end
end

local next = wibox.widget({
	{
		{
			{
				text = "󰁔",
				font = beautiful.icon,
				widget = wibox.widget.textbox,
			},
			widget = wibox.container.margin,
			left = 20,
			right = 20,
			top = 10,
			bottom = 10,
		},
		id = "next_bg",
		widget = wibox.container.background,
		bg = beautiful.lighter1,
		shape = helpers.rrect(50),
		buttons = awful.button({}, 1, function()
			curr = os.date(
				"*t",
				os.time({
					day = curr.day,
					month = curr.month + 1,
					year = curr.year,
				})
			)
			updateCalendar(curr)
		end),
	},
	widget = wibox.container.margin,
	right = 40,
})
helpers.addHover(next, "next_bg", beautiful.lighter1, helpers.blend(beautiful.foreground, beautiful.background, 0.2))

local prev = wibox.widget({
	{
		{
			{
				text = "󰁍",
				font = beautiful.icon,
				widget = wibox.widget.textbox,
			},
			widget = wibox.container.margin,
			left = 20,
			right = 20,
			top = 10,
			bottom = 10,
		},
		id = "prev_bg",
		widget = wibox.container.background,
		bg = beautiful.lighter1,
		shape = helpers.rrect(30),
		buttons = awful.button({}, 1, function()
			curr = os.date(
				"*t",
				os.time({
					day = curr.day,
					month = curr.month - 1,
					year = curr.year,
				})
			)
			updateCalendar(curr)
		end),
	},
	widget = wibox.container.margin,
	left = 40,
})
helpers.addHover(prev, "prev_bg", beautiful.lighter1, helpers.blend(beautiful.foreground, beautiful.background, 0.2))

return function()
	curr = os.date("*t")
	updateCalendar(curr)
	gears.timer({
		timeout = 86400 - os.time() % 86400,
		call_now = true,
		autostart = true,
		callback = function()
			curr = os.date("*t")
			updateCalendar(curr)
		end,
	})
	return wibox.widget({
		{
			{
				{
					prev,
					title,
					next,
					layout = wibox.layout.align.horizontal,
				},
				{
					theGrid,
					widget = wibox.container.place,
					halign = "center",
				},
				spacing = 20,
				layout = wibox.layout.fixed.vertical,
			},
			widget = wibox.container.margin,
			margins = 30,
		},
		shape = helpers.rrect(10),
		widget = wibox.container.background,
		bg = beautiful.lighter,
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
	})
end