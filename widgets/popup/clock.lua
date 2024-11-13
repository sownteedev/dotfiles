local wibox      = require("wibox")
local beautiful  = require("beautiful")
local timer      = require("gears.timer")
local cairo      = require("lgi").cairo

local _run       = {}
_run.timer_table = {}
local function newtimer(name, timeout, fun, nostart, stoppable)
	if not name or #name == 0 then return end
	name = (stoppable and name) or timeout
	if not _run.timer_table[name] then
		_run.timer_table[name] = timer({ timeout = timeout })
		_run.timer_table[name]:start()
	end
	_run.timer_table[name]:connect_signal("timeout", fun)
	if not nostart then
		_run.timer_table[name]:emit_signal("timeout")
	end
	return stoppable and _run.timer_table[name]
end

M_clocl_sys  = {
	make_clock = function()
		local imagebox = wibox.widget {
			resize = true,
			widget = wibox.widget.imagebox
		}
		newtimer("update_clock", 1, function()
				local img = M_clocl_sys.make_clock_canvas()
				imagebox:set_image(img)
			end,
			false, true)

		return imagebox
	end,
	make_clock_canvas = function()
		local surface = cairo.ImageSurface.create(cairo.Format.ARGB32, 200, 200)
		local cr = cairo.Context(surface)

		local cx, cy, radius = 100, 100, 90
		local hour_hand_length, minute_hand_length, second_hand_length = 50, 70, 80

		cr:set_source_rgb(1, 1, 1)
		cr:arc(cx, cy, radius, 0, math.pi * 2)
		cr:fill()

		cr:set_line_cap(cairo.LineCap.ROUND)
		cr:set_source_rgb(0, 0, 0)
		for i = 1, 12 do
			local angle = math.pi / 6 * i
			local x1, y1 = cx + (radius - 15) * math.sin(angle),
				cy - (radius - 15) * math.cos(angle)
			local x2, y2 = cx + radius * math.sin(angle), cy - radius * math.cos(angle)
			cr:move_to(x1, y1)
			cr:line_to(x2, y2)
			cr:set_line_width(3)
			cr:stroke()

			local text_angle = math.pi / 6 * i
			local text_extents = cr:text_extents(tostring(i))
			local x = cx + (radius - 30) * math.sin(text_angle) - text_extents.width / 2 -
				text_extents.x_bearing
			local y = cy - (radius - 30) * math.cos(text_angle) - text_extents.height / 2 -
				text_extents.y_bearing
			cr:select_font_face("SF Pro Display", cairo.FontSlant.NORMAL, cairo.FontWeight.NORMAL)
			cr:set_font_size(15)
			cr:move_to(x, y)
			cr:show_text(tostring(i))
		end

		for i = 0, 59 do
			local angle = math.pi / 30 * i
			local x1, y1 = cx + (radius - 5) * math.sin(angle), cy - (radius - 5) * math.cos(angle)
			local x2, y2 = cx + (radius - 10) * math.sin(angle), cy - (radius - 10) * math.cos(angle)
			cr:move_to(x1, y1)
			cr:line_to(x2, y2)
			cr:set_line_width(2)
			cr:stroke()
		end

		local hour = os.date("%I")
		local minute = os.date("%M")
		local second = os.date("%S")

		local angle_hour = math.pi / 6 * hour + math.pi / 360 * minute
		local angle_minute = math.pi / 30 * minute
		local angle_second = math.pi / 30 * second

		cr:move_to(cx, cy)
		cr:line_to(cx + hour_hand_length * math.sin(angle_hour), cy - hour_hand_length * math.cos(angle_hour))
		cr:set_line_width(7)
		cr:stroke()

		cr:move_to(cx, cy)
		cr:line_to(cx + minute_hand_length * math.sin(angle_minute), cy - minute_hand_length * math.cos(angle_minute))
		cr:set_line_width(5)
		cr:stroke()

		cr:set_source_rgb(255, 128 / 255, 0)
		cr:move_to(cx, cy)
		cr:line_to(cx + second_hand_length * math.sin(angle_second), cy - second_hand_length * math.cos(angle_second))
		cr:set_line_width(1)
		cr:stroke()

		local img = surface:create_similar(cairo.Content.COLOR_ALPHA, 200, 200)
		local cr2 = cairo.Context(img)
		cr2:set_source_surface(surface)
		cr2:paint()

		return img
	end,
}

local clocks = M_clocl_sys.make_clock()

return function(s)
	local clock = wibox({
		screen = s,
		width = 290,
		height = 290,
		shape = beautiful.radius,
		ontop = false,
		visible = true,
	})
	clock:setup({
		clocks,
		layout = wibox.container.margin,
		margins = 10
	})
	_Utils.widget.placeWidget(clock, "top_right", 13, 0, 0, 2)
	_Utils.widget.popupOpacity(clock, 0.3)
	awesome.connect_signal("signal::blur", function(status)
		clock.bg = not status and beautiful.background or beautiful.background .. "88"
	end)

	return clock
end
