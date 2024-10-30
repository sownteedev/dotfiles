local cairo = require("lgi").cairo
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

local surface = cairo.ImageSurface(cairo.Format.RGB24, 20, 20)
local cr = cairo.Context(surface)

local _M = {}

_M.settings = {
	preview_box = true,
	preview_box_bg = "#000000AA",
	preview_box_border = "#000000AA",
	preview_box_fps = 60,
	preview_box_delay = 0,
	preview_box_title_color = { 0, 0, 0, 1 },

	client_opacity = true,
	client_opacity_value_selected = 1,
	client_opacity_value_in_focus = 0.5,
	client_opacity_value = 0.3,

	cycle_raise_client = true,
}

-- Create a wibox to contain all the client-widgets
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


-- simple function for counting the size of a table
function _M.tableLength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

-- this function returns the list of clients to be shown.
function _M.getClients()
	local clients = {}

	local s = mouse.screen
	local idx = 0
	local c = awful.client.focus.history.get(s, idx)

	while c do
		table.insert(clients, c)

		idx = idx + 1
		c = awful.client.focus.history.get(s, idx)
	end

	local t = s.selected_tag
	local all = client.get(s)

	for i = 1, #all do
		c = all[i]
		local ctags = c:tags()

		-- check if the client is on the current tag
		local isCurrentTag = false
		for j = 1, #ctags do
			if t == ctags[j] then
				isCurrentTag = true
				break
			end
		end

		if isCurrentTag then
			-- check if client is already in the history
			-- if not, add it
			local addToTable = true
			for k = 1, #clients do
				if clients[k] == c then
					addToTable = false
					break
				end
			end

			if addToTable then
				table.insert(clients, c)
			end
		end
	end

	return clients
end

-- here we populate altTabTable using the list of clients taken from
-- _M.getClients(). In case we have altTabTable with some value, the list of the
-- old known clients is restored.
function _M.populateAltTabTable()
	local clients = _M.getClients()

	if _M.tableLength(_M.altTabTable) then
		for ci = 1, #clients do
			for ti = 1, #_M.altTabTable do
				if _M.altTabTable[ti].client == clients[ci] then
					_M.altTabTable[ti].client.opacity = _M.altTabTable[ti].opacity
					_M.altTabTable[ti].client.minimized = _M.altTabTable[ti].minimized
					break
				end
			end
		end
	end

	_M.altTabTable = {}

	for i = 1, #clients do
		table.insert(_M.altTabTable, {
			client = clients[i],
			minimized = clients[i].minimized,
			opacity = clients[i].opacity,
		})
	end
end

-- If the length of list of clients is not equal to the length of altTabTable,
-- we need to repopulate the array and update the UI. This function does this
-- check.
function _M.clientsHaveChanged()
	local clients = _M.getClients()
	return _M.tableLength(clients) ~= _M.tableLength(_M.altTabTable)
end

-- Preview is created here.
function _M.clientOpacity()
	if not _M.settings.client_opacity then
		return
	end

	local opacity = _M.settings.client_opacity_value
	if opacity > 1 then
		opacity = 1
	end
	for _, data in pairs(_M.altTabTable) do
		data.client.opacity = opacity
	end

	if client.focus == _M.altTabTable[_M.altTabIndex].client then
		local opacityFocusSelected = _M.settings.client_opacity_value_selected
			+ _M.settings.client_opacity_value_in_focus
		if opacityFocusSelected > 1 then
			opacityFocusSelected = 1
		end
		client.focus.opacity = opacityFocusSelected
	else
		-- Let's normalize the value up to 1.
		local opacityFocus = _M.settings.client_opacity_value_in_focus
		if opacityFocus > 1 then
			opacityFocus = 1
		end
		local opacitySelected = _M.settings.client_opacity_value_selected
		if opacitySelected > 1 then
			opacitySelected = 1
		end

		client.focus.opacity = opacityFocus
		_M.altTabTable[_M.altTabIndex].client.opacity = opacitySelected
	end
end

-- This is called any _M.settings.preview_box_fps milliseconds. In case the list
-- of clients is changed, we need to redraw the whole preview box. Otherwise, a
-- simple widget::updated signal is enough
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
	-- Switch to next client
	_M.altTabIndex = _M.altTabIndex + dir
	if _M.altTabIndex > #_M.altTabTable then
		_M.altTabIndex = 1         -- wrap around
	elseif _M.altTabIndex < 1 then
		_M.altTabIndex = #_M.altTabTable -- wrap around
	end

	_M.updatePreview()

	_M.altTabTable[_M.altTabIndex].client.minimized = false

	if not _M.settings.preview_box and not _M.settings.client_opacity then
		client.focus = _M.altTabTable[_M.altTabIndex].client
	end

	if _M.settings.client_opacity and _M.preview_wbox.visible then
		_M.clientOpacity()
	end

	if _M.settings.cycle_raise_client == true then
		_M.altTabTable[_M.altTabIndex].client:raise()
	end
end

function _M.preview()
	if not _M.settings.preview_box then
		return
	end

	-- Apply settings
	_M.preview_wbox:set_bg(_M.settings.preview_box_bg)
	_M.preview_wbox.border_color = _M.settings.preview_box_border

	-- Make the wibox the right size, based on the number of clients
	local n = math.max(7, #_M.altTabTable)
	local W = screen[mouse.screen].geometry.width -- + 2 * _M.preview_wbox.border_width
	local w = W / n                            -- widget width
	local h = w * 0.75                         -- widget height
	local textboxHeight = w * 0.125

	local x = screen[mouse.screen].geometry.x - _M.preview_wbox.border_width
	local y = screen[mouse.screen].geometry.y + (screen[mouse.screen].geometry.height - h - textboxHeight) / 2
	_M.preview_wbox:geometry({ x = x, y = y, width = W, height = h + textboxHeight })

	-- create a list that holds the clients to preview, from left to right
	local leftRightTab = {}
	local leftRightTabToAltTabIndex = {} -- save mapping from leftRightTab to altTabTable as well
	local nLeft
	local nRight
	if #_M.altTabTable == 2 then
		nLeft = 0
		nRight = 2
	else
		nLeft = math.floor(#_M.altTabTable / 2)
		nRight = math.ceil(#_M.altTabTable / 2)
	end

	for i = 1, nLeft do
		table.insert(leftRightTab, _M.altTabTable[#_M.altTabTable - nLeft + i].client)
		table.insert(leftRightTabToAltTabIndex, #_M.altTabTable - nLeft + i)
	end
	for i = 1, nRight do
		table.insert(leftRightTab, _M.altTabTable[i].client)
		table.insert(leftRightTabToAltTabIndex, i)
	end

	local text, textWidth, textHeight, maxText
	local maxTextWidth = 0
	local maxTextHeight = 0
	for _ = 1, #leftRightTab do
		textWidth = cr:text_extents(text).width
		textHeight = cr:text_extents(text).height
		if textWidth > maxTextWidth or textHeight > maxTextHeight then
			maxTextHeight = textHeight
			maxTextWidth = textWidth
			maxText = text
		end
	end

	while true do
		textWidth = cr:text_extents(maxText).width
		textHeight = cr:text_extents(maxText).height

		if textWidth < w - textboxHeight and textHeight < textboxHeight then
			break
		end
	end

	_M.preview_widgets = {}

	-- create all the widgets
	for i = 1, #leftRightTab do
		_M.preview_widgets[i] = wibox.widget.base.make_widget()
		_M.preview_widgets[i].fit = function()
			return w, h
		end
		local c = leftRightTab[i]
		_M.preview_widgets[i].draw = function(_, _, cr, width, height)
			if width ~= 0 and height ~= 0 then
				local a = 0.8
				local overlay = 0.5
				if c == _M.altTabTable[_M.altTabIndex].client then
					a = 0.9
					overlay = 0
				end

				local sx, sy, tx, ty

				-- Icons
				local icon = gears.surface(helpers.getIcon(c, c.name, c.class))
				local iconboxWidth = 0.9 * textboxHeight
				local iconboxHeight = iconboxWidth
				local titleboxWidth = textWidth + iconboxWidth

				-- Draw icons
				tx = (w - titleboxWidth) / 2
				ty = h - 20
				sx = iconboxWidth / icon.width
				sy = iconboxHeight / icon.height

				cr:translate(tx, ty)
				cr:scale(sx, sy)
				cr:set_source_surface(icon, 0, 0)
				cr:paint()
				cr:scale(1 / sx, 1 / sy)
				cr:translate(-tx, -ty)

				-- Draw previews
				local cg = c:geometry()
				if cg.width > cg.height then
					sx = (a * w / cg.width)
					sy = math.min(sx, a * h / cg.height)
				else
					sy = a * h / cg.height
					sx = math.min(sy, a * h / cg.width)
				end

				tx = (w - sx * cg.width) / 2
				ty = (h - sy * cg.height) / 2

				local tmp = gears.surface(c.content)
				cr:translate(tx, ty)
				cr:scale(sx, sy)
				cr:set_source_surface(tmp, 0, 0)
				cr:paint()
				tmp:finish()

				-- Overlays
				cr:scale(1 / sx, 1 / sy)
				cr:translate(-tx, -ty)
				cr:set_source_rgba(0, 0, 0, overlay)
				cr:rectangle(tx, ty, sx * cg.width, sy * cg.height)
				cr:fill()
			end
		end

		_M.preview_widgets[i]:connect_signal("mouse::enter", function()
			_M.cycle(leftRightTabToAltTabIndex[i] - _M.altTabIndex)
		end)
		helpers.hoverCursor(_M.preview_widgets[i])
	end

	-- Spacers left and right
	local spacer = wibox.widget.base.make_widget()
	spacer.fit = function()
		return (W - w * #_M.altTabTable) / 2, _M.preview_wbox.height
	end

	--layout
	local preview_layout = wibox.layout.fixed.horizontal()

	preview_layout:add(spacer)
	for i = 1, #leftRightTab do
		preview_layout:add(_M.preview_widgets[i])
	end
	preview_layout:add(spacer)

	_M.preview_wbox:set_widget(preview_layout)
end

-- This starts the timer for updating and it shows the preview UI.
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

	if #_M.altTabTable == 0 then
		return
	elseif #_M.altTabTable == 1 then
		_M.altTabTable[1].client.minimized = false
		_M.altTabTable[1].client:raise()
		return
	elseif #_M.altTabTable == 2 then
		local index = dir > 0 and 2 or 1
		local c = _M.altTabTable[index].client
		c.minimized = false
		c:raise()
		client.focus = c
		return
	end

	-- reset index
	_M.altTabIndex = 1

	-- preview delay timer
	local previewDelay = _M.settings.preview_box_delay / 1000
	_M.previewDelayTimer = timer({ timeout = previewDelay })
	_M.previewDelayTimer:connect_signal("timeout", function()
		_M.previewDelayTimer:stop()
		_M.showPreview()
	end)
	_M.previewDelayTimer:start()

	-- Now that we have collected all windows, we should run a keygrabber
	-- as long as the user is alt-tabbing:
	keygrabber.run(function(mod, key, event)
		-- Stop alt-tabbing when the alt-key is released
		if gears.table.hasitem(mod, mod_key1) then
			if (key == release_key or key == "Escape") and event == "release" then
				if _M.preview_wbox.visible == true then
					_M.preview_wbox.visible = false
					_M.preview_live_timer:stop()
				else
					_M.previewDelayTimer:stop()
				end

				if key == "Escape" then
					for i = 1, #_M.altTabTable do
						_M.altTabTable[i].client.opacity = _M.altTabTable[i].opacity
						_M.altTabTable[i].client.minimized = _M.altTabTable[i].minimized
					end
				else
					-- Raise clients in order to restore history
					local c
					for i = 1, _M.altTabIndex - 1 do
						c = _M.altTabTable[_M.altTabIndex - i].client
						if not _M.altTabTable[i].minimized then
							c:raise()
							client.focus = c
						end
					end

					-- raise chosen client on top of all
					c = _M.altTabTable[_M.altTabIndex].client
					c:raise()
					client.focus = c

					-- restore minimized clients
					for i = 1, #_M.altTabTable do
						if i ~= _M.altTabIndex and _M.altTabTable[i].minimized then
							_M.altTabTable[i].client.minimized = true
						end
						_M.altTabTable[i].client.opacity = _M.altTabTable[i].opacity
					end
				end

				keygrabber.stop()
			elseif key == key_switch and event == "press" then
				if gears.table.hasitem(mod, mod_key2) then
					_M.cycle(-1)
				else
					_M.cycle(1)
				end
			end
		end
	end)

	_M.cycle(dir)
end

return { switch = _M.switch, settings = _M.settings }
