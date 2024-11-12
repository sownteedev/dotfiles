local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")

return function(s)
	local image = wibox({
		screen = s,
		width = 290,
		height = 290,
		shape = beautiful.radius,
		ontop = false,
		visible = true,
	})

	image:setup({
		{
			image = gears.surface.load_uncached(beautiful.icon_path .. "sownteemerry.png"),
			widget = wibox.widget.imagebox,
		},
		{
			bg = {
				type = "linear",
				from = { 0, 0 },
				to = { 0, image.height },
				stops = { { 0.7, beautiful.background .. "00" }, { 1, beautiful.background } }
			},
			widget = wibox.container.background,
		},
		{
			{
				{
					{
						markup = _Utils.widget.colorizeText(_User.Name, beautiful.foreground),
						font = "azuki_font Bold 15",
						widget = wibox.widget.textbox,
					},
					{
						markup = _Utils.widget.colorizeText(_User.Username, beautiful.foreground),
						font = "azuki_font 12",
						widget = wibox.widget.textbox,
					},
					layout = wibox.layout.fixed.vertical,
				},
				margins = 10,
				widget = wibox.container.margin,
			},
			halign = "left",
			valign = "bottom",
			layout = wibox.container.place,
		},
		layout = wibox.layout.stack,
	})
	_Utils.widget.placeWidget(image, "top_left", 45, 0, 33, 0)
	_Utils.widget.popupOpacity(image, 0.3)

	return image
end
