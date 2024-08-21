local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local Gio = require("lgi").Gio
local helpers = require("helpers")
local beautiful = require("beautiful")
local inspect = require("modules.inspect")

local M = {
	metadata = {
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Alacritty", "Alacritty"),
			id = 1,
			clients = {},
			class = "alacritty",
			exec = "alacritty",
			name = "alacritty",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "firefox", "firefox"),
			id = 2,
			clients = {},
			class = "firefox",
			exec = "firefox",
			name = "firefox",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "visual-studio-code", "visual-studio-code"),
			id = 3,
			clients = {},
			class = "code",
			exec = "code",
			name = "code",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-intellij", "jetbrains-intellij"),
			id = 4,
			clients = {},
			class = "jetbrains-idea",
			exec = "intellij-idea-ultimate-edition",
			name = "jetbrains-idea",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-webstorm", "jetbrains-webstorm"),
			id = 5,
			clients = {},
			class = "jetbrains-webstorm",
			exec = "webstorm",
			name = "jetbrains-webstorm",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-pycharm", "jetbrains-pycharm"),
			id = 6,
			clients = {},
			class = "jetbrains-pycharm",
			exec = "pycharm-professional",
			name = "jetbrains-pycharm",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-datagrip", "jetbrains-datagrip"),
			id = 7,
			clients = {},
			class = "jetbrains-datagrip",
			exec = "datagrip",
			name = "datagrip",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Docker Desktop", "Docker Desktop"),
			id = 8,
			clients = {},
			class = "docker desktop",
			exec = "systemctl --user start docker-desktop",
			name = "Containers - Docker Desktop",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "postman", "postman"),
			id = 9,
			clients = {},
			class = "postman",
			exec = "postman",
			name = "Postman",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Notion", "Notion"),
			id = 10,
			clients = {},
			class = "notion",
			exec = "notion-app",
			name = "notion",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "telegram", "telegram"),
			id = 11,
			clients = {},
			class = "telegramdesktop",
			exec = "telegram-desktop",
			name = "telegramdesktop",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "discord", "discord"),
			id = 12,
			clients = {},
			class = "discord",
			exec = "discord",
			name = "discord",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Spotify", "Spotify"),
			id = 13,
			clients = {},
			class = "spotify",
			exec = "spotify",
			name = "spotify",
		},
	},
	classes = {
		"alacritty",
		"firefox",
		"code",
		"jetbrains-idea",
		"jetbrains-webstorm",
		"jetbrains-pycharm",
		"jetbrains-datagrip",
		"docker desktop",
		"postman",
		"notion",
		"telegramdesktop",
		"discord",
		"spotify",
	},
}

M.widget = wibox.widget({
	layout = wibox.layout.fixed.horizontal,
	spacing = 5,
})

M.popupWidget = wibox.widget({
	layout = wibox.layout.fixed.vertical,
	spacing = 30,
})

M.popup = awful.popup({
	minimum_width = 300,
	widget = wibox.container.background,
	visible = false,
	shape = helpers.rrect(5),
	ontop = true,
	bg = beautiful.background,
})

M.popup:setup({
	widget = wibox.container.margin,
	margins = 30,
	M.popupWidget,
})

function M:showMenu(data)
	local clients = data.clients
	self.popup.x = mouse.coords().x - 100
	self.popup.y = beautiful.height - 130 - (50 * (#clients + 2))
	self.popupWidget:reset()
	for i, j in ipairs(clients) do
		local widget = wibox.widget({
			{
				{
					{
						markup = j.name,
						font = beautiful.sans .. " 11",
						widget = wibox.widget.textbox,
					},
					width = 180,
					height = 16,
					widget = wibox.container.constraint,
				},
				nil,
				{
					markup = helpers.colorizeText("󰅖", beautiful.red),
					font = beautiful.icon .. " 11",
					widget = wibox.widget.textbox,
					buttons = {
						awful.button({}, 1, function()
							j:kill()
							self.popup.visible = false
						end),
					},
				},
				layout = wibox.layout.align.horizontal,
			},
			buttons = {
				awful.button({}, 1, function()
					if client.focus and client.focus.class:lower() == j.class then
						client.focus = j
						awful.client.movetotag(mouse.screen.selected_tag, j)
					elseif j.minimized then
						j.minimized = false
						client.focus = j
						awful.client.movetotag(mouse.screen.selected_tag, j)
					end
					self.popup.visible = false
				end),
			},
			bg = beautiful.background,
			widget = wibox.container.background,
		})
		M.popupWidget:connect_signal("mouse::leave", function()
			self.popup.visible = false
		end)
		self.popupWidget:add(widget)
	end

	local addNew = wibox.widget({
		{
			{
				markup = "Open New Window",
				font = beautiful.sans .. " 11",
				widget = wibox.widget.textbox,
			},
			width = 180,
			widget = wibox.container.constraint,
		},
		buttons = {
			awful.button({}, 1, function()
				awful.spawn.easy_async_with_shell(data.exec .. " &")
				self.popup.visible = false
			end),
		},
		bg = beautiful.background,
		widget = wibox.container.background,
	})
	local closeAll = wibox.widget({
		{
			markup = "Close All",
			font = beautiful.sans .. " 11",
			widget = wibox.widget.textbox,
		},
		buttons = {
			awful.button({}, 1, function()
				for i, j in ipairs(clients) do
					j:kill()
				end
				self.popup.visible = false
			end),
		},
		bg = beautiful.background,
		widget = wibox.container.background,
	})
	self.popupWidget:add(addNew)
	self.popupWidget:add(closeAll)
	self.popup.visible = true
end

local removeDup = function(arr)
	local hash = {}
	local res = {}
	for _, v in ipairs(arr) do
		if not hash[v] then
			res[#res + 1] = v
			hash[v] = true
		end
	end
	return res
end

function M:getExecutable(class)
	local class_1 = class:gsub("[%-]", "")
	local class_2 = class:gsub("[%-]", ".")

	local class_3 = class:match("(.-)-") or class
	class_3 = class_3:match("(.-)%.") or class_3
	class_3 = class_3:match("(.-)%s+") or class_3
	local apps = Gio.AppInfo.get_all()
	local possible_icon_names = { class, class_3, class_2, class_1 }
	for _, app in ipairs(apps) do
		local id = app:get_id():lower()
		for _, possible_icon_name in ipairs(possible_icon_names) do
			if id and id:find(possible_icon_name, 1, true) then
				return app:get_executable()
			end
		end
	end
	return class:lower()
end

function M:genMetadata()
	local clients = mouse.screen.selected_tag and mouse.screen.selected_tag:clients() or {}

	for _, j in pairs(self.metadata) do
		j.count = 0
		j.clients = {}
	end
	for _, c in ipairs(clients) do
		local icon = helpers.getIcon(c, c.class, c.class)
		local class = string.lower(c.class or "default")
		local exe = self:getExecutable(c.class)
		if helpers.inTable(self.classes, class) then
			for _, j in pairs(self.metadata) do
				if j.class:lower() == class:lower() then
					table.insert(j.clients, c)
					j.count = j.count + 1
				end
			end
		else
			table.insert(self.classes, class)
			local toInsert = {
				count = 1,
				pinned = false,
				icon = icon,
				id = #self.classes + 1,
				clients = { c },
				class = class,
				exec = exe,
				name = c.name,
			}
			table.insert(self.metadata, toInsert)
		end
		for _, j in pairs(self.metadata) do
			j.clients = removeDup(j.clients)
		end
	end
end

local function getMinimized(clients)
	local a = 0
	for i, j in ipairs(clients) do
		if j.minimized then
			a = a + 1
		end
	end
	return a
end

function M:genIcons()
	self:genMetadata()
	self.widget:reset()
	print(inspect(self.metadata))
	for i, j in ipairs(self.metadata) do
		if j.pinned == true or j.count > 0 then
			local minimized = getMinimized(j.clients)
			local bg = beautiful.darker
			if minimized > 0 then
				bg = beautiful.blue
			end
			if client.focus then
				if client.focus.class:lower() == j.class then
					bg = beautiful.foreground
				elseif j.count > 0 then
					bg = beautiful.foreground .. "AA"
				end
			end
			local widget = wibox.widget({
				{
					{
						widget = wibox.widget.imagebox,
						image = j.icon,
						forced_height = 50,
						forced_width = 50,
						resize = true,
					},
					widget = wibox.container.margin,
					top = 10,
				},
				{
					{
						font = beautiful.icon .. " 4",
						markup = helpers.colorizeText("●", bg),
						widget = wibox.widget.textbox,
						halign = "center",
					},
					widget = wibox.container.margin,
					top = -1,
				},
				layout = wibox.layout.fixed.vertical,
			})
			for i = 1, j.count - 1 do
				widget.children[2].widget.markup =
					helpers.colorizeText(widget.children[2].widget.markup .. " ●", bg)
			end
			widget:buttons(gears.table.join(
				awful.button({}, 1, function()
					if j.count == 0 then
						awful.spawn.easy_async_with_shell(j.exec .. " &")
					elseif j.count == 1 then
						if j.clients[j.count].minimized then
							j.clients[j.count].minimized = false
							client.focus = j.clients[j.count]
							awful.client.movetotag(mouse.screen.selected_tag, j.clients[j.count])
						elseif client.focus and client.focus.class:lower() == j.class then
							j.clients[j.count].minimized = true
						elseif client.focus and client.focus.class:lower() ~= j.class then
							client.focus = j.clients[j.count]
							awful.client.movetotag(mouse.screen.selected_tag, j.clients[j.count])
						end
					elseif j.count > 1 and self.popup.visible == false then
						self:showMenu(j)
					else
						self.popup.visible = false
					end
				end),
				awful.button({}, 3, function()
					if self.popup.visible == false then
						self:showMenu(j)
					else
						self.popup.visible = false
					end
				end)
			))
			self.widget:add(widget)
		end
	end
end

client.connect_signal("focus", function()
	M:genIcons()
end)
client.connect_signal("property::minimized", function()
	M:genIcons()
end)
client.connect_signal("property::maximized", function()
	M:genIcons()
end)
client.connect_signal("manage", function()
	M:genIcons()
	M.popup.visible = false
end)
client.connect_signal("unmanage", function()
	M:genIcons()
	M.popup.visible = false
end)
tag.connect_signal("property::selected", function()
	M:genIcons()
	M.popup.visible = false
end)
M:genIcons()

return M
