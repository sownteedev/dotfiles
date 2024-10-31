local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local helpers = require("helpers")

local M = {}

local datewidget = function(date, weekend, notIn)
	weekend = weekend or false
	if notIn then
		return wibox.widget({
			markup = helpers.colorizeText(date, beautiful.foreground .. "55"),
			align = "center",
			font = beautiful.sans .. " Medium 10",
			widget = wibox.widget.textbox,
		})
	else
		return wibox.widget({
			markup = weekend and helpers.colorizeText(date, beautiful.foreground) or date,
			align = "center",
			font = beautiful.sans .. " Medium 10",
			widget = wibox.widget.textbox,
		})
	end
end

local daywidget = function(day, weekend, _)
	weekend = weekend or false
	return wibox.widget({
		markup = weekend and helpers.colorizeText(day, beautiful.red) or day,
		align = "center",
		font = beautiful.sans .. " Bold 11",
		widget = wibox.widget.textbox,
	})
end
local currwidget = function(day)
	return wibox.widget({
		{
			{
				markup = helpers.colorizeText(day, beautiful.foreground),
				align = "center",
				font = beautiful.sans .. " Medium 10",
				widget = wibox.widget.textbox,
			},
			margins = 8,
			widget = wibox.container.margin,
		},
		shape  = gears.shape.circle,
		bg     = beautiful.blue,
		widget = wibox.container.background,
	})
end

local theGrid = wibox.widget({
	forced_num_rows = 7,
	forced_num_cols = 7,
	vertical_spacing = 10,
	horizontal_spacing = 15,
	min_rows_size = 20,
	homogenous = true,
	layout = wibox.layout.grid,
})

local curr

local title = wibox.widget({
	{
		id = "text",
		font = beautiful.sans .. " Bold 12",
		widget = wibox.widget.textbox,
		halign = "left",
		valign = "center",
	},
	left = 15,
	widget = wibox.container.margin,
})

M.updateCalendar = function(date)
	helpers.gc(title, "text").markup = helpers.colorizeText(string.upper(os.date("%B %Y", os.time(date))), beautiful.red)
	theGrid:reset()
	for _, w in ipairs({ "S", "M", "T", "W", "T", "F", "S" }) do
		if w == "S" then
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

curr = os.date("*t")
M.updateCalendar(curr)
gears.timer({
	timeout = 86400,
	call_now = false,
	autostart = true,
	callback = function()
		curr = os.date("*t")
		M.updateCalendar(curr)
	end,
})

return function(s)
	local caca = wibox({
		screen = s,
		width = 290,
		height = 290,
		shape = beautiful.radius,
		ontop = false,
		visible = true,
	})

	caca:setup({
		{
			title,
			{
				theGrid,
				widget = wibox.container.place,
				halign = "center",
			},
			spacing = 10,
			layout = wibox.layout.fixed.vertical,
		},
		widget = wibox.container.margin,
		margins = 10,
		buttons = gears.table.join(
			awful.button({}, 4, function()
				curr = os.date(
					"*t",
					os.time({
						day = curr.day,
						month = curr.month + 1,
						year = curr.year,
					})
				)
				M.updateCalendar(curr)
			end),
			awful.button({}, 5, function()
				curr = os.date(
					"*t",
					os.time({
						day = curr.day,
						month = curr.month - 1,
						year = curr.year,
					})
				)
				M.updateCalendar(curr)
			end)
		),
	})
	helpers.placeWidget(caca, "top_left", 103, 0, 2, 0)
	helpers.popupOpacity(caca, 0.3)
	awesome.connect_signal("signal::blur", function(status)
		caca.bg = not status and beautiful.background or beautiful.background .. "88"
	end)

	return caca
end
