local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local gears = require("gears")
local Gio = require("lgi").Gio
local animation = require("modules.animation")
local HOME = os.getenv("HOME")

local base_apps = {
	{ name = "nemo",        class = "Nemo",        exec = "nemo" },
	{ name = "shotwell",    class = "Shotwell",    exec = "shotwell" },
	{ name = "thunderbird", class = "thunderbird", exec = "thunderbird" },
	{ name = "zen-alpha",   class = "zen-alpha",   exec = "zen-browser" },
}

local dev_apps = {
	{ name = "Alacritty",          class = "Alacritty",          exec = "alacritty" },
	{ name = "visual-studio-code", class = "Code",               exec = "code" },
	{ name = "cursor",             class = "Cursor",             exec = "cursor" },
	{ name = "jetbrains-intellij", class = "jetbrains-idea",     exec = HOME .. "/.local/share/JetBrains/Toolbox/apps/intellij-idea-ultimate/bin/idea" },
	{ name = "jetbrains-studio",   class = "jetbrains-studio",   exec = HOME .. "/.local/share/JetBrains/Toolbox/apps/android-studio/bin/studio.sh" },
	{ name = "jetbrains-webstorm", class = "jetbrains-webstorm", exec = HOME .. "/.local/share/JetBrains/Toolbox/apps/webstorm/bin/webstorm" },
	{ name = "jetbrains-pycharm",  class = "jetbrains-pycharm",  exec = HOME .. "/.local/share/JetBrains/Toolbox/apps/pycharm-professional/bin/pycharm" },
	{ name = "jetbrains-datagrip", class = "jetbrains-datagrip", exec = HOME .. "/.local/share/JetBrains/Toolbox/apps/datagrip/bin/datagrip" },
}

local dev_tools = {
	-- { name = "MongoDB Compass",     class = "MongoDB Compass",     exec = "mongodb-compass" },
	-- { name = "Mysql-workbench-bin", class = "Mysql-workbench-bin", exec = "mysql-workbench" },
	{ name = "Docker Desktop", class = "Docker Desktop", exec = "/opt/docker-desktop/bin/docker-desktop" },
	{ name = "postman",        class = "Postman",        exec = "postman" },
}

local utility_apps = {
	{ name = "anydesk", class = "Anydesk", exec = "anydesk" },
	{ name = "vmware",  class = "Vmware",  exec = "vmware" },
	{ name = "notion",  class = "Notion",  exec = "notion-app" },
}

local social_apps = {
	{ name = "telegram", class = "TelegramDesktop", exec = "telegram-desktop" },
	{ name = "caprine",  class = "Caprine",         exec = "caprine" },
	{ name = "vesktop",  class = "vesktop",         exec = "vesktop" },
	{ name = "Spotify",  class = "Spotify",         exec = "spotify" },
}

local custom_apps = {
	{
		name = _User.Custom_Icon[1].name,
		class = _User.Custom_Icon[1].name,
		exec = "/usr/bin/firefoxpwa site launch " .. string.sub(_User.Custom_Icon[1].name, 7) .. " --protocol"
	},
}

local function create_metadata_entry(app)
	return {
		count = 0,
		pinned = true,
		icon = _Utils.icon.getIcon(nil, app.name, app.name),
		clients = {},
		class = app.class,
		exec = app.exec
	}
end

local data = {
	metadata = {},
	classes = {},
	exclude = { "Ulauncher" },
}

local function populate_data(apps)
	for _, app in ipairs(apps) do
		table.insert(data.metadata, create_metadata_entry(app))
		table.insert(data.classes, string.lower(app.class))
	end
end

populate_data(base_apps)
populate_data(dev_apps)
populate_data(dev_tools)
populate_data(utility_apps)
populate_data(social_apps)
populate_data(custom_apps)

local widget = wibox.widget({
	layout = wibox.layout.fixed.horizontal,
	spacing = 7,
})

local executable_cache = {}
local function getExecutable(class)
	if executable_cache[class] then
		return executable_cache[class]
	end
	local class_variants = {
		class,
		class:match("(.-)-") or class,
		class:gsub("[%-]", ""),
		class:gsub("[%-]", ".")
	}
	local apps = Gio.AppInfo.get_all()
	for _, app in ipairs(apps) do
		local id = app:get_id():lower()
		for _, variant in ipairs(class_variants) do
			if type(variant) == "string" and id:find(variant:lower(), 1, true) then
				executable_cache[class] = app:get_executable()
				return executable_cache[class]
			end
		end
	end
	executable_cache[class] = class:lower()
	return executable_cache[class]
end


local function removeDup(arr)
	local set = {}
	local res = {}
	for _, v in ipairs(arr) do
		if not set[v] then
			res[#res + 1] = v
			set[v] = true
		end
	end
	return res
end

local function genMetadata()
	local clients = mouse.screen.selected_tag and mouse.screen.selected_tag:clients() or {}
	local class_lookup = {}
	local new_metadata = {}

	local exclude_lookup = {}
	for _, class in ipairs(data.exclude) do
		exclude_lookup[class:lower()] = true
	end

	for _, j in pairs(data.metadata) do
		j.count = 0
		j.clients = {}
		if j.pinned then
			class_lookup[j.class:lower()] = j
		end
	end

	for _, c in ipairs(clients) do
		local class = (c.class or "default"):lower()

		if exclude_lookup[class] then
			goto continue
		end

		local metadata = class_lookup[class]
		if metadata then
			table.insert(metadata.clients, c)
			metadata.count = metadata.count + 1
		else
			local icon = _Utils.icon.getIcon(c, c.class, c.class)
			local exe = getExecutable(c.class)
			local new_entry = {
				count = 1,
				pinned = false,
				icon = icon,
				clients = { c },
				class = class,
				exec = exe,
			}
			table.insert(new_metadata, new_entry)
			class_lookup[class] = new_entry
		end

		::continue::
	end

	for _, entry in ipairs(new_metadata) do
		table.insert(data.metadata, entry)
		table.insert(data.classes, entry.class)
	end

	for _, j in pairs(data.metadata) do
		if j.count > 0 then
			j.clients = removeDup(j.clients)
		end
	end
end

local function client_exists(class_name)
	return awful.client.iterate(function(c) return c.class == class_name end)() ~= nil
end

local function focus_client_by_class(class_name)
	local clients = client.get()
	for i = 1, #clients do
		local c = clients[i]
		if c.class == class_name then
			local tag = c.first_tag
			if tag then
				tag:view_only()
				client.focus = c
				c:raise()
				return
			end
		end
	end
end

local function genIcons()
	genMetadata()
	widget:reset()
	local added = false
	for _, j in ipairs(data.metadata) do
		if j.pinned or (not j.pinned and j.count > 0) then
			if not j.pinned and added then
				widget:add(wibox.widget({
					{
						orientation   = "vertical",
						forced_width  = 2,
						forced_height = 1,
						shape         = gears.shape.rounded_rect,
						widget        = wibox.widget.separator,
					},
					top = 10,
					bottom = 10,
					left = 5,
					right = 5,
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
			local icon = wibox.widget({
				widget = wibox.widget.imagebox,
				image = j.icon,
				forced_height = 50,
				forced_width = 50,
				resize = true,
			})

			local widgets = wibox.widget({
				icon,
				{
					{
						dot,
						halign = "center",
						widget = wibox.container.place,
					},
					forced_width = 50,
					widget       = wibox.container.background,
				},
				spacing = 2,
				layout = wibox.layout.fixed.vertical,
			})
			_Utils.widget.hoverCursor(widgets)

			for _, c in ipairs(j.clients) do
				if client.focus and c.window == client.focus.window then
					dot:add({
						bg           = beautiful.foreground,
						shape        = _Utils.widget.rrect(2),
						widget       = wibox.container.background,
						forced_width = 15,
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
						bg           = beautiful.foreground,
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
						awful.spawn.with_shell(j.exec)
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
				end),
				awful.button({}, 2, function()
					for _, c in ipairs(j.clients) do
						c:kill()
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
		shape = _Utils.widget.rrect(20),
		bg = _Utils.color.change_hex_lightness(beautiful.background, 8) .. "AA",
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
			top = 12,
			bottom = 5,
			left = 12,
			right = 12,
		},
		widget = wibox.container.background,
		shape = _Utils.widget.rrect(20),
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
					slide:set(beautiful.height - dock.height - beautiful.useless_gap)
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
			dock.y = beautiful.height - dock.height - beautiful.useless_gap
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
	client.connect_signal("unmanage", function()
		genIcons()
	end)
	tag.connect_signal("property::selected", function()
		genIcons()
	end)
	if _User.AutoHideDock then
		client.connect_signal("property::maximized", function(c)
			autohide(c)
		end)
	else
		client.connect_signal("property::maximized", function(c)
			if c.maximized then
				c:geometry({ height = c:geometry().height - beautiful.useless_gap * 2 - dock.height })
			end
		end)
	end

	return dock
end
