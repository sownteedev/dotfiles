local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local scale = 0.18
opened_preview = false

local function create_empty_tag_widget(s)
	return wibox.widget {
		{
			{
				image = gears.surface.crop_surface {
					surface = gears.surface.load_uncached(_User.Wallpaper),
					ratio = s.geometry.width / s.geometry.height
				},
				widget = wibox.widget.imagebox
			},
			{
				{
					{
						widget = wibox.widget.textbox,
						markup = _Utils.widget.colorizeText(" ", beautiful.red),
						font = beautiful.icon .. " 30",
					},
					align = "center",
					widget = wibox.container.place
				},
				bg = beautiful.background .. "AA",
				widget = wibox.container.background
			},
			layout = wibox.layout.stack
		},
		shape = beautiful.radius,
		shape_border_width = beautiful.border_width,
		shape_border_color = beautiful.lighter,
		widget = wibox.container.background
	}
end

local function create_client_preview(c, geometry)
	local imagebox = wibox.widget {
		resize = true,
		image = _Utils.icon.getIcon(c, c.name, c.class),
		forced_height = 150 * scale,
		forced_width = 150 * scale,
		widget = wibox.widget.imagebox
	}

	local clientbox = wibox.widget({
		{
			imagebox,
			widget = wibox.container.place
		},
		forced_height = math.floor(c.height * scale),
		forced_width = math.floor(c.width * scale),
		bg = beautiful.background .. "AA",
		border_color = beautiful.foreground .. "33",
		border_width = 0.5,
		shape = _Utils.widget.rrect(5),
		widget = wibox.container.background
	})

	clientbox.point = {
		x = math.floor((c.x - geometry.x) * scale),
		y = math.floor((c.y - geometry.y) * scale),
	}

	return clientbox
end

local function createpreview(t, s, geometry)
	local clientlayout = wibox.layout.manual()
	clientlayout.forced_height = geometry.height
	clientlayout.forced_width = geometry.width

	local clients = t:clients()
	if #clients == 0 then
		local tags = create_empty_tag_widget(s)
		_Utils.widget.hoverCursor(tags)
		return tags
	end

	for _, c in ipairs(clients) do
		if not c.hidden and not c.minimized then
			clientlayout:add(create_client_preview(c, geometry))
		end
	end

	local tags = wibox.widget {
		{
			{
				image = gears.surface.crop_surface {
					surface = gears.surface.load_uncached(_User.Wallpaper),
					ratio = s.geometry.width / s.geometry.height
				},
				widget = wibox.widget.imagebox
			},
			clientlayout,
			layout = wibox.layout.stack
		},
		shape = beautiful.radius,
		shape_border_width = beautiful.border_width,
		shape_border_color = beautiful.lighter,
		widget = wibox.container.background
	}

	_Utils.widget.hoverCursor(tags)
	return tags
end

return function(s)
	local previewbox = wibox {
		screen = s,
		ontop = true,
		visible = false,
		shape = beautiful.radius,
		bg = beautiful.background .. "88",
		border_width = beautiful.border_width,
		border_color = beautiful.lighter,
		widget = wibox.container.background
	}

	local previewlist = wibox.widget {
		expand = true,
		spacing = 30,
		orientation = "horizontal",
		layout = wibox.layout.grid
	}

	local screen_geometry = s:get_bounding_geometry()

	local function startpreview()
		if previewbox.visible then
			previewbox.visible = false
			opened_preview = false
			return
		end

		previewlist:reset()
		local tags = awful.screen.focused().tags
		local numtags = #tags

		for _, tag in ipairs(tags) do
			local preview = wibox.widget {
				createpreview(tag, tag.screen, screen_geometry),
				buttons = {
					awful.button({}, 1, function()
						awesome.emit_signal("close::preview")
						tag:view_only()
					end)
				},
				widget = wibox.container.background
			}
			previewlist:add(preview)
		end

		previewbox.width = screen_geometry.width * scale * numtags + (numtags + 1) * 5 + 150
		previewbox.height = screen_geometry.height * scale + 60
		previewbox.widget = wibox.widget {
			previewlist,
			margins = 30,
			widget = wibox.container.margin
		}
		_Utils.widget.placeWidget(previewbox, "top", 2, 0, 0, 0)
		previewbox.visible = true
		opened_preview = true
	end

	awesome.connect_signal("toggle::preview", startpreview)
	awesome.connect_signal("close::preview", function()
		if previewbox.visible then
			previewbox.visible = false
			opened_preview = false
		end
	end)

	return previewbox
end
