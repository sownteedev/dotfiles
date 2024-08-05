local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local helpers = require("helpers")
local scale = 0.1

local function createpreview(t, s, geometry)
	local clientlayout = wibox.layout.manual()
	clientlayout.forced_height = geometry.height
	clientlayout.forced_width = geometry.width
	for _, c in ipairs(t:clients()) do
		if not c.hidden and not c.minimized then
			local imagebox = wibox.widget {
				resize = true,
				image = helpers.getIcon(c, c.name, c.class),
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
				forced_width = math.floor(c.width * scale) - 10,
				bg = beautiful.background,
				border_color = beautiful.foreground .. "55",
				border_width = 1,
				shape = helpers.rrect(5),
				widget = wibox.container.background
			})

			clientbox.point = {
				x = math.floor((c.x - geometry.x) * scale) + 3,
				y = math.floor((c.y - geometry.y) * scale) + 3,
			}

			clientlayout:add(clientbox)
		end
	end

	if t:clients()[1] == nil then
		return wibox.widget {
			{
				{
					image = gears.surface.crop_surface {
						surface = gears.surface.load_uncached(beautiful.wallpaper),
						ratio = s.geometry.width / s.geometry.height
					},
					widget = wibox.widget.imagebox
				},
				{
					{
						{
							widget = wibox.widget.textbox,
							text = " ",
							font = beautiful.icon .. " 30",
						},
						align = "center",
						widget = wibox.container.place
					},
					bg = beautiful.background .. "96",
					widget = wibox.container.background
				},
				layout = wibox.layout.stack
			},
			shape = helpers.rrect(5),
			widget = wibox.container.background
		}
	else
		return wibox.widget {
			{
				{
					image = gears.surface.crop_surface {
						surface = gears.surface.load_uncached(beautiful.wallpaper),
						ratio = s.geometry.width / s.geometry.height
					},
					widget = wibox.widget.imagebox
				},
				clientlayout,
				layout = wibox.layout.stack
			},
			shape = helpers.rrect(5),
			widget = wibox.container.background
		}
	end
end

local previewbox = wibox {
	ontop = true,
	visible = false,
	bg = beautiful.background .. "00",
	widget = wibox.container.background
}

local previewlist = wibox.widget {
	expand = true,
	spacing = 10,
	orientation = "horizontal",
	layout = wibox.layout.grid
}

awesome.connect_signal("toggle::preview", function()
	if previewbox.visible then
		previewbox.visible = false
		return
	end

	previewlist:reset()

	local geometry = awful.screen.focused():get_bounding_geometry()
	local tags = awful.screen.focused().tags
	local numtags

	for i, tag in ipairs(tags) do
		numtags = i

		local preview = wibox.widget {
			createpreview(tag, tag.screen, geometry),
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

	previewbox.width = geometry.width * scale * numtags + (numtags + 1) * 5
	previewbox.height = geometry.height * scale
	previewbox.widget = wibox.widget {
		previewlist,
		shape = helpers.rrect(5),
		widget = wibox.container.background,
	}
	helpers.placeWidget(previewbox, "bottom_left", 0, 2, 5, 0)
	previewbox.visible = true
end)

awesome.connect_signal("close::preview", function()
	previewbox.visible = false
end)