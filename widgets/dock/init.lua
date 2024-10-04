local awful = require("awful")
local beautiful = require("beautiful")
local helpers = require("helpers")
local wibox = require("wibox")
local gears = require("gears")
local Gio = require("lgi").Gio
local inspect = require("modules.inspect")
local animation = require("modules.animation")

local data = {
	metadata = {
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "nemo", "nemo"),
			clients = {},
			class = "Nemo",
			exec = "nemo",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "shotwell", "shotwell"),
			clients = {},
			class = "Shotwell",
			exec = "shotwell",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "thunderbird", "thunderbird"),
			clients = {},
			class = "thunderbird",
			exec = "thunderbird",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "firefox", "firefox"),
			clients = {},
			class = "firefox",
			exec = "firefox",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Alacritty", "Alacritty"),
			clients = {},
			class = "Alacritty",
			exec = "alacritty",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "visual-studio-code", "visual-studio-code"),
			clients = {},
			class = "Code",
			exec = "code",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-intellij", "jetbrains-intellij"),
			clients = {},
			class = "jetbrains-idea",
			exec = os.getenv("HOME") .. "/.local/share/JetBrains/Toolbox/apps/intellij-idea-ultimate/bin/idea",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-studio", "jetbrains-studio"),
			clients = {},
			class = "jetbrains-studio",
			exec = os.getenv("HOME") .. "/.local/share/JetBrains/Toolbox/apps/android-studio/bin/studio.sh",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-webstorm", "jetbrains-webstorm"),
			clients = {},
			class = "jetbrains-webstorm",
			exec = os.getenv("HOME") .. "/.local/share/JetBrains/Toolbox/apps/webstorm/bin/webstorm",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-pycharm", "jetbrains-pycharm"),
			clients = {},
			class = "jetbrains-pycharm",
			exec = os.getenv("HOME") .. "/.local/share/JetBrains/Toolbox/apps/pycharm-professional/bin/pycharm",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "jetbrains-datagrip", "jetbrains-datagrip"),
			clients = {},
			class = "jetbrains-datagrip",
			exec = os.getenv("HOME") .. "/.local/share/JetBrains/Toolbox/apps/datagrip/bin/datagrip",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "MongoDB Compass", "MongoDB Compass"),
			clients = {},
			class = "MongoDB Compass",
			exec = "mongodb-compass",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Mysql-workbench-bin", "Mysql-workbench-bin"),
			clients = {},
			class = "Mysql-workbench-bin",
			exec = "mysql-workbench",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Docker Desktop", "Docker Desktop"),
			clients = {},
			class = "Docker Desktop",
			exec = "systemctl --user start docker-desktop",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "postman", "postman"),
			clients = {},
			class = "Postman",
			exec = "postman",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "anydesk", "anydesk"),
			clients = {},
			class = "Anydesk",
			exec = "anydesk",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "vmware-workstation", "vmware"),
			clients = {},
			class = "Vmware",
			exec = "vmware",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "wps", "wps"),
			clients = {},
			class = "wps",
			exec = "wps",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "et", "et"),
			clients = {},
			class = "et",
			exec = "et",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "wpp", "wpp"),
			clients = {},
			class = "wpp",
			exec = "wpp",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Notion", "Notion"),
			clients = {},
			class = "Notion",
			exec = "notion-app",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "telegram", "telegram"),
			clients = {},
			class = "TelegramDesktop",
			exec = "telegram-desktop",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "caprine", "caprine"),
			clients = {},
			class = "Caprine",
			exec = "caprine",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "vesktop", "vesktop"),
			clients = {},
			class = "vesktop",
			exec = "vesktop",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "Spotify", "Spotify"),
			clients = {},
			class = "Spotify",
			exec = "spotify",
		},
		{
			count = 0,
			pinned = true,
			icon = helpers.getIcon(nil, "FFPWA-01J82T1YF1C7RZ9ZD2WV6FZ7GM", "FFPWA-01J82T1YF1C7RZ9ZD2WV6FZ7GM"),
			clients = {},
			class = "FFPWA-01J82T1YF1C7RZ9ZD2WV6FZ7GM",
			exec = "/usr/bin/firefoxpwa site launch 01J82T1YF1C7RZ9ZD2WV6FZ7GM --protocol",
		},
	},
	classes = {
		"nemo",
		"shotwell",
		"thunderbird",
		"firefox",
		"alacritty",
		"code",
		"jetbrains-idea",
		"jetbrains-studio",
		"jetbrains-webstorm",
		"jetbrains-pycharm",
		"jetbrains-datagrip",
		"mongodb compass",
		"mysql-workbench-bin",
		"docker desktop",
		"postman",
		"anydesk",
		"vmware",
		"wps",
		"et",
		"wpp",
		"notion",
		"telegramdesktop",
		"caprine",
		"vesktop",
		"spotify",
		"ffpwa-01j82t1yf1c7rz9zd2wv6fz7gm",
	},
}

local widget = wibox.widget({
	layout = wibox.layout.fixed.horizontal,
	spacing = 7,
})

local function getExecutable(class)
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

local function genMetadata()
	local clients = mouse.screen.selected_tag and mouse.screen.selected_tag:clients() or {}
	for _, j in pairs(data.metadata) do
		j.count = 0
		j.clients = {}
	end
	for _, c in ipairs(clients) do
		local icon = helpers.getIcon(c, c.class, c.class)
		local class = string.lower(c.class or "default")
		local exe = getExecutable(c.class)
		if helpers.inTable(data.classes, class) then
			for _, j in pairs(data.metadata) do
				if j.class:lower() == class:lower() then
					table.insert(j.clients, c)
					j.count = j.count + 1
				end
			end
		else
			table.insert(data.classes, class)
			local toInsert = {
				count = 1,
				pinned = false,
				icon = icon,
				clients = { c },
				class = class,
				exec = exe,
			}
			table.insert(data.metadata, toInsert)
		end
		for _, j in pairs(data.metadata) do
			j.clients = removeDup(j.clients)
		end
	end
end

local function client_exists(class_name)
	for _, c in ipairs(client.get()) do
		if c.class == class_name then
			return true
		end
	end
	return false
end

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

local function genIcons()
	genMetadata()
	widget:reset()
	print(inspect(data.metadata))
	local added = false
	for _, j in ipairs(data.metadata) do
		if j.pinned or (not j.pinned and j.count > 0) then
			if not j.pinned and added then
				widget:add(wibox.widget({
					{
						orientation   = "vertical",
						forced_width  = 1,
						forced_height = 1,
						widget        = wibox.widget.separator,
					},
					top = 10,
					bottom = 10,
					widget = wibox.container.margin,
				}))
				added = false
			end
			local dot = wibox.widget({
				{
					bg            = beautiful.background .. "00",
					widget        = wibox.container.background,
					forced_width  = 0,
					forced_height = 5,
				},
				spacing = 2,
				layout = wibox.layout.fixed.horizontal,
			})
			local widgets = wibox.widget({
				{
					{
						widget = wibox.widget.imagebox,
						image = j.icon,
						forced_height = 50,
						forced_width = 50,
						resize = true,
					},
					top = 5,
					widget = wibox.container.margin,
				},
				{
					dot,
					halign = "center",
					widget = wibox.container.place,
				},
				spacing = 2,
				layout = wibox.layout.fixed.vertical,
			})
			helpers.hoverCursor(widgets)

			for _, c in ipairs(j.clients) do
				if client.focus and c.window == client.focus.window then
					dot:add({
						bg           = beautiful.foreground,
						shape        = helpers.rrect(2),
						widget       = wibox.container.background,
						forced_width = 12,
					})
				elseif c.minimized then
					dot:add({
						bg           = beautiful.yellow,
						shape        = gears.shape.circle,
						widget       = wibox.container.background,
						forced_width = 5,
					})
				else
					dot:add({
						bg           = beautiful.foreground .. "AA",
						shape        = gears.shape.circle,
						widget       = wibox.container.background,
						forced_width = 5,
					})
				end
			end
			j.current_client_index = j.current_client_index or 1
			widgets:buttons(gears.table.join(
				awful.button({}, 1, function()
					if j.count == 0 and client_exists(j.class) then
						focus_client_by_class(j.class)
						client.focus.minimized = false
					elseif j.count == 0 then
						awful.spawn(j.exec)
					elseif j.count == 1 then
						if j.clients[j.count].minimized then
							j.clients[j.count].minimized = false
							client.focus = j.clients[j.count]
							awful.client.movetotag(mouse.screen.selected_tag, j.clients[j.count])
						elseif client.focus and client.focus.class:lower() == j.class:lower() then
							j.clients[j.count].minimized = true
						elseif client.focus and client.focus.class:lower() ~= j.class:lower() then
							client.focus = j.clients[j.count]
							awful.client.movetotag(mouse.screen.selected_tag, j.clients[j.count])
						end
					else
						client.focus = j.clients[j.current_client_index]
						client.focus:raise()
						awful.client.movetotag(mouse.screen.selected_tag, client.focus)
						j.current_client_index = j.current_client_index % j.count + 1
					end
				end)
			))
			widget:add(widgets)
			added = j.pinned
		end
	end
end
genIcons()

return function(s)
	local dock = awful.popup({
		screen = s,
		visible = true,
		shape = helpers.rrect(20),
		bg = helpers.blend("#ffffff", "#000000", 0.3) .. "44",
		placement = function(c)
			awful.placement.bottom(c, { margins = { bottom = beautiful.useless_gap * 2 } })
		end,
		widget = wibox.container.background,
	})

	dock:setup({
		{
			{
				widget,
				align = "center",
				widget = wibox.container.place,
			},
			widget = wibox.container.margin,
			top = 5,
			bottom = 5,
			left = 10,
			right = 10,
		},
		widget = wibox.container.background,
		shape = helpers.rrect(20),
		shape_border_width = 1,
		shape_border_color = beautiful.foreground .. "22",
	})

	local slide
	local enter_func, leave_func
	local autohide = function(c)
		if c.maximized then
			dock.ontop = true
			dock.y = beautiful.height - 1
			dock.opacity = 0
			if not slide then
				slide = animation:new({
					duration = 0.5,
					pos = beautiful.height - 1,
					easing = animation.easing.inOutExpo,
					update = function(_, pos)
						dock.y = pos
					end,
				})
			end
			enter_func = function()
				if slide then
					slide:set(beautiful.height - dock.height - beautiful.useless_gap * 2)
					dock.opacity = 1
				end
			end
			leave_func = function()
				if slide then
					slide:set(beautiful.height - 1)
					gears.timer.start_new(0.35, function()
						dock.opacity = 0
					end)
				end
			end

			dock:connect_signal("mouse::enter", enter_func)
			dock:connect_signal("mouse::leave", leave_func)

			c:connect_signal("unmanage", function()
				if slide then
					dock.ontop = false
					dock.opacity = 1
					if enter_func and leave_func then
						dock:disconnect_signal("mouse::enter", enter_func)
						dock:disconnect_signal("mouse::leave", leave_func)
					end
					slide = nil
				end
			end)
		else
			dock.ontop = false
			dock.y = beautiful.height - dock.height - beautiful.useless_gap * 2
			dock.opacity = 1
			if enter_func and leave_func then
				dock:disconnect_signal("mouse::enter", enter_func)
				dock:disconnect_signal("mouse::leave", leave_func)
			end
			if slide then
				slide = nil
			end
		end
	end

	client.connect_signal("focus", function()
		genIcons()
	end)
	client.connect_signal("unfocus", function()
		genIcons()
	end)
	client.connect_signal("property::minimized", function()
		genIcons()
	end)
	client.connect_signal("manage", function()
		genIcons()
	end)
	client.connect_signal("unmanage", function()
		genIcons()
	end)
	tag.connect_signal("property::selected", function(c)
		autohide(c)
	end)
	client.connect_signal("property::maximized", function(c)
		autohide(c)
	end)

	return dock
end
