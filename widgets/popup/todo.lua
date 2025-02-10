local gears = require("gears")
local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")

local DATA = gears.filesystem.get_cache_dir() .. 'todos.json'

local empty = wibox.widget {
	{
		image = beautiful.icon_path .. "awm/todo.svg",
		resize = true,
		forced_height = 150,
		forced_width = 150,
		widget = wibox.widget.imagebox,
	},
	left = 50,
	top = 25,
	widget = wibox.container.margin,
}

local todo_list = wibox.widget {
	layout = require("modules.overflow").vertical,
	scrollbar_enabled = false,
}

local writeData = function(d)
	os.execute('truncate -s 0 ' .. DATA)
	local f = assert(io.open(DATA, "wb"))
	local write = _Utils.json.encode(d)
	f:write(write)
	f:flush()
	f:close()
end

local grabber = {}
function grabber:init(finalWidget, open, close)
	local exclude = {
		["Shift_R"] = true,
		["Shift_L"] = true,
		["Tab"] = true,
		["Alt_R"] = true,
		["Alt_L"] = true,
		["Ctrl_L"] = true,
		["Ctrl_R"] = true,
		["CapsLock"] = true,
		["Home"] = true,
	}

	grabber.main = awful.keygrabber({
		auto_start = true,
		stop_event = "release",
		keypressed_callback = function(_, _, key, _)
			local addition = ''
			if key == "Escape" or key == "Super_L" then
				grabber.main:stop()
				close()
			elseif key == "BackSpace" then
				_Utils.widget.gc(finalWidget, "input").markup = _Utils.widget.gc(finalWidget, "input").markup:sub(1, -2)
			elseif key == "Return" then
				if string.len(_Utils.widget.gc(finalWidget, "input").markup) > 0 then
					open(_Utils.widget.gc(finalWidget, "input").markup)
					_Utils.widget.gc(finalWidget, "input").markup = ''
					grabber.main:stop()
				end
			elseif not exclude[key] then
				addition = key
			end
			_Utils.widget.gc(finalWidget, "input").markup = _Utils.widget.gc(finalWidget, "input").markup .. addition
		end,
	})
end

local function makeElement(i, n)
	awful.screen.connect_for_each_screen(function()
		local widget = wibox.widget {
			{
				{
					{
						{
							forced_width = 4,
							shape = _Utils.widget.rrect(5),
							bg = i.completed and beautiful.green or beautiful.red,
							widget = wibox.container.background,
						},
						top = 5,
						bottom = 5,
						widget = wibox.container.margin
					},
					{
						{
							id = "input",
							font = beautiful.sans .. " 12",
							markup = i.completed and "<s>" .. i.name .. "</s>" or i.name,
							text = i.name,
							valign = "center",
							halign = "left",
							widget = wibox.widget.textbox,
							editable = true,
							editing = false,
						},
						widget = wibox.container.constraint,
						width = 200,
						strategy = "max",
					},
					spacing = 10,
					layout = wibox.layout.fixed.horizontal,
				},
				nil,
				{
					{
						font = beautiful.icon .. " 15",
						markup = _Utils.widget.colorizeText("󰸞", beautiful.green),
						valign = "center",
						align = "center",
						widget = wibox.widget.textbox,
						buttons = {
							awful.button({}, 1, function()
								local new = {
									completed = not i.completed,
									name = i.name
								}
								local data = _Utils.json.readJson(DATA)
								data[n] = new
								writeData(data)
								refresh()
							end),
						},
					},
					{
						font = beautiful.icon .. " 15",
						markup = _Utils.widget.colorizeText("󰩹", beautiful.red),
						valign = "center",
						align = "center",
						widget = wibox.widget.textbox,
						buttons = {
							awful.button({}, 1, function()
								local data = _Utils.json.readJson(DATA)
								table.remove(data, n)
								writeData(data)
								todo_list:reset()
								if #data == 0 then
									todo_list:insert(1, empty)
								end
								for k, l in ipairs(data) do
									makeElement(l, k)
								end
							end),
						},
					},
					spacing = 15,
					layout = wibox.layout.fixed.horizontal
				},
				layout = wibox.layout.align.horizontal
			},
			widget = wibox.container.background,
			forced_height = 45,
			forced_width = 260,
			data = i
		}
		_Utils.widget.gc(widget, "input"):connect_signal("button::press", function(w, _, _, button)
			if not w.editing and button == 1 then
				w.editing = true
				widget.bg = beautiful.lighter
				w.text = i.name
				grabber.main = awful.keygrabber({
					auto_start = true,
					stop_event = "release",
					keypressed_callback = function(_, _, key, _)
						if key == "Return" then
							w.editing = false
							widget.bg = nil
							grabber.main:stop()
							local data = _Utils.json.readJson(DATA)
							data[n] = {
								completed = i.completed,
								name = w.text
							}
							writeData(data)
							refresh()
						elseif key == "Escape" then
							w.editing = false
							widget.bg = nil
							grabber.main:stop()
							w.markup = i.completed and "<s>" .. i.name .. "</s>" or i.name
						elseif key == "BackSpace" then
							w.text = string.sub(w.text, 1, -2)
						else
							if #key == 1 then
								w.text = w.text .. key
							end
						end
					end
				})
				grabber.main:start()
			end
		end)
		todo_list:add(widget)
	end)
end

local makeData = function(d)
	local data = _Utils.json.readJson(DATA)
	table.insert(data, d)
	writeData(data)
end

function refresh()
	todo_list:reset()
	local data = _Utils.json.readJson(DATA)
	if #data == 0 then
		todo_list:insert(1, empty)
	end
	for i, j in ipairs(data) do
		makeElement(j, i)
	end
end

local function addTodoItem()
	local new = {
		completed = false,
		name = ""
	}
	makeData(new)
	refresh()

	local lastWidget = todo_list.children[#todo_list.children]
	if lastWidget then
		-- Trigger edit mode immediately
		local input = _Utils.widget.gc(lastWidget, "input")
		input.editing = true
		input.text = ""
		lastWidget.bg = beautiful.lighter

		grabber.main = awful.keygrabber({
			auto_start = true,
			stop_event = "release",
			keypressed_callback = function(_, _, key, _)
				if key == "Return" then
					input.editing = false
					lastWidget.bg = nil
					grabber.main:stop()
					if #input.text == 0 then
						-- Remove if empty
						local data = _Utils.json.readJson(DATA)
						table.remove(data)
						writeData(data)
						refresh()
					else
						-- Save the changes
						local data = _Utils.json.readJson(DATA)
						data[#data] = {
							completed = false,
							name = input.text
						}
						writeData(data)
						refresh()
					end
				elseif key == "Escape" then
					input.editing = false
					lastWidget.bg = nil
					grabber.main:stop()
					-- Remove the empty todo if cancelled
					local data = _Utils.json.readJson(DATA)
					table.remove(data)
					writeData(data)
					refresh()
				elseif key == "BackSpace" then
					input.text = string.sub(input.text, 1, -2)
				else
					if #key == 1 then
						input.text = input.text .. key
					end
				end
			end
		})
		grabber.main:start()
	end
end

return function(s)
	local todo = wibox({
		screen = s,
		width = 290,
		height = 290,
		shape = beautiful.radius,
		ontop = false,
		visible = true,
	})

	todo:setup({
		{
			{
				{
					{
						font = beautiful.sans .. " Bold 13",
						markup = "Todo List",
						valign = "center",
						align = "center",
						widget = wibox.widget.textbox,
					},
					nil,
					{
						{
							{
								{
									font = beautiful.icon .. " 12",
									markup = _Utils.widget.colorizeText("󰐕", beautiful.background),
									valign = "center",
									align = "center",
									widget = wibox.widget.textbox,
								},
								margins = 3,
								widget = wibox.container.margin
							},
							bg = beautiful.blue,
							shape = gears.shape.circle,
							widget = wibox.container.background,
							buttons = {
								awful.button({}, 1, function()
									addTodoItem()
								end),
							},
						},
						{
							{
								{
									font = beautiful.icon .. " 12",
									markup = _Utils.widget.colorizeText("󰅖", beautiful.background),
									valign = "center",
									align = "center",
									widget = wibox.widget.textbox
								},
								margins = 3,
								widget = wibox.container.margin
							},
							bg = beautiful.red,
							shape = gears.shape.circle,
							widget = wibox.container.background,
							buttons = {
								awful.button({}, 1, function()
									os.execute("rm " .. DATA)
									refresh()
									todo_list:reset()
									todo_list:insert(1, empty)
								end),
							},
						},
						spacing = 10,
						layout = wibox.layout.fixed.horizontal
					},
					layout = wibox.layout.align.horizontal
				},
				top = 10,
				bottom = 10,
				right = 13,
				left = 15,
				widget = wibox.container.margin,
			},
			bg = beautiful.lighter,
			widget = wibox.container.background,
		},
		{
			todo_list,
			margins = 15,
			widget = wibox.container.margin
		},
		spacing = -5,
		layout = wibox.layout.fixed.vertical
	})

	_Utils.widget.placeWidget(todo, "top_right", 44, 0, 0, 2)
	_Utils.widget.popupOpacity(todo, 0.3)
	awesome.connect_signal("signal::blur", function(status)
		todo.bg = not status and beautiful.background or beautiful.background .. "AA"
	end)
	refresh()

	return todo
end
