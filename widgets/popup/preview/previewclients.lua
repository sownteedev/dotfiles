local mouse = mouse
local screen = screen
local wibox = require("wibox")
local table = table
local keygrabber = keygrabber
local math = require("math")
local awful = require("awful")
local gears = require("gears")
local timer = gears.timer
local client = client
awful.client = require("awful.client")

local string = string
local debug = debug
local pairs = pairs
local helpers = require("helpers")

local _M = {}

_M.settings = {
	preview_box = true,
	preview_box_bg = "#000000AA",
	preview_box_fps = 60,
	preview_box_delay = 0,
	preview_box_title_color = { 0, 0, 0, 1 },

	client_opacity = true,
	client_opacity_value_selected = 1,
	client_opacity_value_in_focus = 0.5,
	client_opacity_value = 0.3,

	cycle_raise_client = true,
}

_M.preview_wbox = wibox({ width = screen[mouse.screen].geometry.width })
_M.preview_wbox.border_width = 0
_M.preview_wbox.ontop = true
_M.preview_wbox.visible = false

_M.preview_live_timer = timer({ timeout = 1 / _M.settings.preview_box_fps })
_M.preview_widgets = {}

_M.altTabTable = {}
_M.altTabIndex = 1

_M.source = string.sub(debug.getinfo(1, "S").source, 2)
_M.path = string.sub(_M.source, 1, string.find(_M.source, "/[^/]*$"))
_M.noicon = _M.path .. "noicon.png"

function _M.getClients()
	local clients = {}
	local seen = {}

	local s = mouse.screen
	local current_tag = s.selected_tag

	local idx = 0
	local c = awful.client.focus.history.get(s, idx)

	while c do
		if not seen[c] and c:tags()[1] == current_tag then
			seen[c] = true
			table.insert(clients, c)
		end
		idx = idx + 1
		c = awful.client.focus.history.get(s, idx)
	end

	for _, x in ipairs(current_tag:clients()) do
		if not seen[x] then
			table.insert(clients, x)
		end
	end

	return clients
end

function _M.populateAltTabTable()
	local clients = _M.getClients()
	local old_states = {}

	if #_M.altTabTable > 0 then
		for _, data in ipairs(_M.altTabTable) do
			old_states[data.client] = {
				opacity = data.opacity,
				minimized = data.minimized
			}
		end
	end

	_M.altTabTable = {}

	for _, c in ipairs(clients) do
		if old_states[c] then
			c.opacity = old_states[c].opacity
			c.minimized = old_states[c].minimized
		end

		table.insert(_M.altTabTable, {
			client = c,
			minimized = c.minimized,
			opacity = c.opacity
		})
	end
end

function _M.clientsHaveChanged()
	return #_M.getClients() ~= #_M.altTabTable
end

function _M.clientOpacity()
	if not _M.settings.client_opacity then return end

	local base_opacity = math.min(_M.settings.client_opacity_value, 1)
	local selected_opacity = math.min(_M.settings.client_opacity_value_selected, 1)
	local focus_opacity = math.min(_M.settings.client_opacity_value_in_focus, 1)

	local current_client = _M.altTabTable[_M.altTabIndex].client
	local focused_client = client.focus

	for _, data in pairs(_M.altTabTable) do
		data.client.opacity = base_opacity
	end

	if focused_client == current_client then
		focused_client.opacity = math.min(selected_opacity + focus_opacity, 1)
	else
		focused_client.opacity = focus_opacity
		current_client.opacity = selected_opacity
	end
end

function _M.updatePreview()
	if _M.clientsHaveChanged() then
		_M.populateAltTabTable()
		_M.preview()
	end

	for i = 1, #_M.preview_widgets do
		_M.preview_widgets[i]:emit_signal("widget::updated")
	end
end

function _M.cycle(dir)
	local num_clients = #_M.altTabTable

	_M.altTabIndex = ((_M.altTabIndex + dir - 1) % num_clients) + 1

	local current_client = _M.altTabTable[_M.altTabIndex].client
	current_client.minimized = false

	if not (_M.settings.preview_box or _M.settings.client_opacity) then
		client.focus = current_client
	end

	if _M.settings.client_opacity and _M.preview_wbox.visible then
		_M.clientOpacity()
	end

	if _M.settings.cycle_raise_client then
		current_client:raise()
	end

	_M.updatePreview()
end

function _M.preview()
	if not _M.settings.preview_box then return end

	local SPACING = 15
	local screen_width = mouse.screen.geometry.width
	local num_clients = #_M.altTabTable

	local available_width = screen_width - (SPACING * (num_clients + 1))
	local w = math.min(300, available_width / num_clients)
	local h = w * 0.75
	local textboxHeight = w * 0.125

	_M.preview_wbox:set_bg(_M.settings.preview_box_bg)
	_M.preview_wbox:geometry({
		width = (w * num_clients) + (SPACING * (num_clients + 1)),
		height = h + textboxHeight,
	})
	awful.placement.centered(_M.preview_wbox)

	_M.preview_widgets = {}

	local function create_preview_widget(clients, index)
		local widget = wibox.widget.base.make_widget()

		widget.fit = function() return w, h end

		widget.draw = function(_, _, cr, width, height)
			if width == 0 or height == 0 then return end

			local is_selected = clients == _M.altTabTable[_M.altTabIndex].client
			local alpha = is_selected and 0.9 or 0.8
			local overlay = is_selected and 0 or 0.5

			local icon = gears.surface(helpers.getIcon(clients, clients.name, clients.class))
			local icon_size = 0.9 * textboxHeight
			local icon_x = (w - icon_size) / 2
			local icon_y = h - 20

			local scale_x = icon_size / icon.width
			local scale_y = icon_size / icon.height

			cr:save()
			cr:translate(icon_x, icon_y)
			cr:scale(scale_x, scale_y)
			cr:set_source_surface(icon, 0, 0)
			cr:paint()
			cr:restore()

			local geo = clients:geometry()

			if geo.width > geo.height then
				scale_x = (alpha * w / geo.width)
				scale_y = math.min(scale_x, alpha * h / geo.height)
			else
				scale_y = alpha * h / geo.height
				scale_x = math.min(scale_y, alpha * h / geo.width)
			end

			local tx = (w - scale_x * geo.width) / 2
			local ty = (h - scale_y * geo.height) / 2

			local content = gears.surface(clients.content)
			cr:save()
			cr:translate(tx, ty)
			cr:scale(scale_x, scale_y)
			cr:set_source_surface(content, 0, 0)
			cr:paint()
			content:finish()
			cr:restore()

			cr:set_source_rgba(0, 0, 0, overlay)
			cr:rectangle(tx, ty, scale_x * geo.width, scale_y * geo.height)
			cr:fill()
		end

		widget:connect_signal("mouse::enter", function()
			_M.cycle(index - _M.altTabIndex)
		end)
		helpers.hoverCursor(widget)

		return widget
	end

	local preview_layout = wibox.layout.fixed.horizontal()
	preview_layout.spacing = SPACING
	preview_layout:add(wibox.widget.textbox(" "))

	for i, a in ipairs(_M.altTabTable) do
		local widget = create_preview_widget(a.client, i)
		_M.preview_widgets[i] = widget
		preview_layout:add(widget)
	end

	preview_layout:add(wibox.widget.textbox(" "))
	_M.preview_wbox:set_widget(preview_layout)
end

function _M.showPreview()
	_M.preview_live_timer.timeout = 1 / _M.settings.preview_box_fps
	_M.preview_live_timer:connect_signal("timeout", _M.updatePreview)
	_M.preview_live_timer:start()

	_M.preview()
	_M.preview_wbox.visible = true

	_M.clientOpacity()
end

function _M.switch(dir, mod_key1, release_key, mod_key2, key_switch)
	_M.populateAltTabTable()
	local num_clients = #_M.altTabTable

	if num_clients == 0 then
		return
	elseif num_clients == 1 then
		local c = _M.altTabTable[1].client
		c.minimized = false
		c:raise()
		return
	elseif num_clients == 2 then
		local c = _M.altTabTable[dir > 0 and 2 or 1].client
		c.minimized = false
		c:raise()
		client.focus = c
		return
	end

	_M.altTabIndex = 1

	local preview_delay = _M.settings.preview_box_delay / 1000
	_M.previewDelayTimer = timer({
		timeout = preview_delay,
		callback = function()
			_M.previewDelayTimer:stop()
			_M.showPreview()
		end,
		single_shot = true
	})
	_M.previewDelayTimer:start()

	keygrabber.run(function(mod, key, event)
		if not gears.table.hasitem(mod, mod_key1) then return end

		if (key == release_key or key == "Escape") and event == "release" then
			if _M.preview_wbox.visible then
				_M.preview_wbox.visible = false
				_M.preview_live_timer:stop()
			else
				_M.previewDelayTimer:stop()
			end

			if key == "Escape" then
				for _, data in ipairs(_M.altTabTable) do
					data.client.opacity = data.opacity
					data.client.minimized = data.minimized
				end
			else
				local selected = _M.altTabTable[_M.altTabIndex].client

				for i = 1, _M.altTabIndex - 1 do
					local c = _M.altTabTable[_M.altTabIndex - i].client
					if not _M.altTabTable[i].minimized then
						c:raise()
						client.focus = c
					end
				end

				selected:raise()
				client.focus = selected

				for i, data in ipairs(_M.altTabTable) do
					if i ~= _M.altTabIndex then
						data.client.minimized = data.minimized
					end
					data.client.opacity = data.opacity
				end
			end

			keygrabber.stop()
		elseif key == key_switch and event == "press" then
			_M.cycle(gears.table.hasitem(mod, mod_key2) and -1 or 1)
		end
	end)

	_M.cycle(dir)
end

return { switch = _M.switch, settings = _M.settings }
