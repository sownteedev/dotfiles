local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi

local widgets = {}

widgets.centered_client_placement = function(c)
	return gears.timer.delayed_call(function()
		awful.placement.centered(c, { honor_padding = true, honor_workarea = true })
	end)
end

widgets.rrect = function(radius)
	radius = radius or dpi(5)
	return function(cr, width, height)
		gears.shape.rounded_rect(cr, width, height, radius)
	end
end

widgets.prect = function(tl, tr, br, bl, radius)
	radius = radius or dpi(5)
	return function(cr, width, height)
		gears.shape.partially_rounded_rect(cr, width, height, tl, tr, br, bl, radius)
	end
end

widgets.addHoverBg = function(element, id, bg, hbg)
	element:connect_signal("mouse::enter", function()
		widgets.gc(element, id).bg = hbg
	end)
	element:connect_signal("mouse::leave", function()
		widgets.gc(element, id).bg = bg
	end)
end

widgets.hoverCursor = function(widget, id)
	local oldcursor, oldwibox
	if id ~= nil then
		widgets.gc(widget, id):connect_signal("mouse::enter", function()
			local wb = mouse.current_wibox
			if wb == nil then return end
			oldcursor, oldwibox = wb.cursor, wb
			wb.cursor = "hand2"
		end)
		widgets.gc(widget, id):connect_signal("mouse::leave", function()
			if oldwibox then
				oldwibox.cursor = oldcursor
				oldwibox = nil
			end
		end)
	else
		widget:connect_signal("mouse::enter", function()
			local wb = mouse.current_wibox
			if wb == nil then return end
			oldcursor, oldwibox = wb.cursor, wb
			wb.cursor = "hand2"
		end)
		widget:connect_signal("mouse::leave", function()
			if oldwibox then
				oldwibox.cursor = oldcursor
				oldwibox = nil
			end
		end)
	end
	return widget
end

widgets.popupOpacity = function(widget, opacity)
	local function check_clients_state(clients)
		if #clients == 0 then
			return true
		end
		for _, c in ipairs(clients) do
			if not c.minimized then
				return false
			end
		end
		return true
	end

	local function update_opacity(should_be_visible)
		widget.opacity = should_be_visible and 1 or opacity
	end

	local function handle_screen_clients(s)
		if not s or not s.selected_tag then
			update_opacity(true)
			return
		end
		update_opacity(check_clients_state(s.selected_tag:clients()))
	end

	client.connect_signal("focus", function()
		update_opacity(false)
	end)

	client.connect_signal("unmanage", function(c)
		handle_screen_clients(c.screen)
	end)

	client.connect_signal("unfocus", function(c)
		handle_screen_clients(c.screen)
	end)

	tag.connect_signal("property::selected", function(t)
		update_opacity(check_clients_state(t:clients()))
	end)
end

widgets.placeWidget = function(widget, where, t, b, l, r)
	if where == "top_right" then
		awful.placement.top_right(widget, {
			honor_workarea = true,
			margins = {
				top = beautiful.useless_gap * t,
				right = beautiful.useless_gap * r,
			},
		})
	elseif where == "bottom_right" then
		awful.placement.bottom_right(widget, {
			honor_workarea = true,
			margins = {
				bottom = beautiful.useless_gap * b,
				right = beautiful.useless_gap * r,
			},
		})
	elseif where == "top_left" then
		awful.placement.top_left(widget, {
			honor_workarea = true,
			margins = {
				top = beautiful.useless_gap * t,
				left = beautiful.useless_gap * l,
			},
		})
	elseif where == "bottom_left" then
		awful.placement.bottom_left(widget, {
			honor_workarea = true,
			margins = {
				bottom = beautiful.useless_gap * b,
				left = beautiful.useless_gap * l,
			},
		})
	elseif where == "bottom" then
		awful.placement.bottom(widget, { honor_workarea = true, margins = beautiful.useless_gap * b })
	elseif where == "top" then
		awful.placement.top(widget, { honor_workarea = true, margins = { top = beautiful.useless_gap * t } })
	elseif where == "center" then
		awful.placement.centered(widget, { honor_workarea = true, honor_padding = true })
	end
end

widgets.colorizeText = function(txt, fg)
	fg = fg or beautiful.foreground
	if fg == "" then
		fg = "#ffffff"
	end
	return "<span foreground='" .. fg .. "'>" .. txt .. "</span>"
end

widgets.gc = function(widget, id)
	return widget:get_children_by_id(id)[1]
end

widgets.split = function(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

return widgets
