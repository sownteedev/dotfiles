local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local cairo = require("lgi").cairo
local beautiful = require("beautiful")
local scale = 0.18
opened_preview = false

local snapshots = setmetatable({}, { __mode = "k" })

local function get_snapshot(c)
	if not c.valid or c.hidden or c.minimized or not c:isvisible() then
		return snapshots[c]
	end

	local success, image = pcall(function()
		local content = gears.surface(c.content)
		local source_context = cairo.Context(content)
		local left, top, right, bottom = source_context:clip_extents()
		local width, height = right - left, bottom - top
		if width <= 0 or height <= 0 then return end

		local thumbnail_width = math.max(1, math.floor(width * scale))
		local thumbnail_height = math.max(1, math.floor(height * scale))
		local thumbnail = cairo.ImageSurface.create(cairo.Format.ARGB32, thumbnail_width, thumbnail_height)
		local context = cairo.Context(thumbnail)
		context:scale(thumbnail_width / width, thumbnail_height / height)
		context:set_source_surface(content, -left, -top)
		context.operator = cairo.Operator.SOURCE
		context:paint()
		return thumbnail
	end)
	if success and image then
		snapshots[c] = image
	end
	return snapshots[c]
end

gears.timer {
	timeout = 1,
	autostart = true,
	call_now = true,
	callback = function()
		for _, c in ipairs(client.get()) do
			get_snapshot(c)
		end
	end,
}

client.connect_signal("unmanage", function(c)
	snapshots[c] = nil
end)

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
					widget = wibox.widget.textbox,
					markup = _Utils.widget.colorizeText("󰅚", beautiful.red),
					align = "center",
					valign = "center",
					font = beautiful.icon .. " 30",
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

local function draw_widget(t, s, geo)
	local client_list = wibox.layout.manual()
	client_list.forced_height = geo.height
	client_list.forced_width = geo.width

	if #t:clients() == 0 then
		return create_empty_tag_widget(s)
	end

	for _, c in ipairs(t:clients()) do
		if not c.hidden and not c.minimized then
			local img_box = wibox.widget({
				resize = true,
				image = _Utils.icon.getIcon(c, c.name, c.class),
				forced_height = 150 * scale,
				forced_width = 150 * scale,
				widget = wibox.widget.imagebox,
			})

			local snapshot = get_snapshot(c)
			if snapshot then
				img_box = wibox.widget({
					image = snapshot,
					resize = true,
					opacity = 1,
					forced_height = math.floor(c.height * scale),
					forced_width = math.floor(c.width * scale),
					widget = wibox.widget.imagebox,
				})
			end

			local client_box = wibox.widget({
				{
					nil,
					{
						nil,
						img_box,
						nil,
						expand = "outside",
						layout = wibox.layout.align.horizontal,
					},
					nil,
					expand = "outside",
					widget = wibox.layout.align.vertical,
				},
				forced_height = math.floor(c.height * scale - 6),
				forced_width = math.floor(c.width * scale),
				bg = beautiful.background .. "AA",
				border_color = beautiful.foreground .. "33",
				border_width = 0.5,
				shape = _Utils.widget.rrect(5),
				widget = wibox.container.background,
			})

			client_box.point = {
				x = math.floor((c.x - geo.x) * scale),
				y = math.floor((c.y - geo.y) * scale),
			}

			client_list:add(client_box)
		end
	end

	local a = wibox.widget {
		{
			{
				image = gears.surface.crop_surface {
					surface = gears.surface.load_uncached(_User.Wallpaper),
					ratio = s.geometry.width / s.geometry.height
				},
				widget = wibox.widget.imagebox
			},
			{
				client_list,
				forced_height = geo.height,
				forced_width = geo.width,
				widget = wibox.container.place,
			},
			layout = wibox.layout.stack
		},
		shape = beautiful.radius,
		shape_border_width = beautiful.border_width,
		shape_border_color = beautiful.lighter,
		widget = wibox.container.background
	}

	_Utils.widget.hoverCursor(a)

	return a
end

return function(s)
	local previewbox = wibox {
		screen = s,
		ontop = true,
		visible = false,
		shape = beautiful.radius,
		bg = beautiful.background .. "AA",
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
				draw_widget(tag, tag.screen, screen_geometry),
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
			collectgarbage("collect")
		end
	end)

	return previewbox
end
