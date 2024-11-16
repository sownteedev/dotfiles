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
		valign = "center",
		widget = wibox.widget.imagebox,
	},
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

local function getPop(tit)
	local pop = wibox({
		type = "dock",
		height = 155,
		width = 400,
		ontop = true,
		shape = beautiful.radius,
		visible = true,
		bg = beautiful.background
	})
	awful.placement.centered(pop)
	local widget = wibox.widget {
		{
			{
				{
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
								grabber.main:stop()
								pop.visible = false
							end),
						},
					},
					{
						font = beautiful.sans .. " Medium 11",
						markup = tit,
						align = "center",
						valign = "center",
						widget = wibox.widget.textbox,
					},
					nil,
					layout = wibox.layout.align.horizontal
				},
				top = 10,
				bottom = 10,
				left = 20,
				right = 20,
				widget = wibox.container.margin,
			},
			bg = beautiful.lighter,
			widget = wibox.container.background,
		},
		{
			{
				{
					{
						id = "input",
						font = beautiful.sans .. " 12",
						markup = "",
						forced_height = 35,
						valign = "center",
						align = "start",
						widget = wibox.widget.textbox,
					},
					left = 20,
					right = 20,
					top = 10,
					bottom = 10,
					widget = wibox.container.margin,
				},
				widget = wibox.container.background,
				shape = _Utils.widget.rrect(10),
				border_width = beautiful.border_width,
				border_color = beautiful.lighter2,
				bg = beautiful.background .. "00"
			},
			margins = 15,
			widget = wibox.container.margin,
		},
		spacing = 15,
		layout = wibox.layout.fixed.vertical
	}
	pop:setup {
		widget,
		widget = wibox.container.margin,
	}
	return widget, pop
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
							valign = "center",
							align = "center",
							widget = wibox.widget.textbox,
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
								todo_list:reset()
								for k, l in ipairs(data) do
									makeElement(l, k)
								end
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
		_Utils.widget.gc(widget, "input"):add_button(awful.button({}, 1, function()
			local w, pop = getPop('Enter New Name')
			grabber:init(w, function(string)
				pop.visible = false
				local new = {
					completed = i.completed,
					name = string
				}
				local data = _Utils.json.readJson(DATA)
				data[n] = new
				writeData(data)
				todo_list:reset()
				for k, l in ipairs(data) do
					makeElement(l, k)
				end
			end, function()
				pop.visible = false
			end)
			grabber.main:start()
		end))
		todo_list:add(widget)
	end)
end

local makeData = function(d)
	local data = _Utils.json.readJson(DATA)
	table.insert(data, d)
	writeData(data)
end

local function refresh()
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
	local w, pop = getPop('Enter New Todo')
	grabber:init(w, function(input)
		if input and input ~= "" then
			local new = {
				completed = false,
				name = input
			}
			makeData(new)
			refresh()
		end
		pop.visible = false
	end, function()
		pop.visible = false
	end)
	grabber.main:start()
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
			{
				todo_list,
				widget = wibox.container.place,
				valign = 'top'
			},
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
