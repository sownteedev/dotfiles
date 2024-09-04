local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")

return function(s)
	local image = wibox({
		screen = s,
		width = 290,
		height = 290,
		shape = beautiful.radius,
		bg = beautiful.background,
		ontop = false,
		visible = true,
	})

	image:setup({
		{
			image = beautiful.icon_path .. "sownteemerry.png",
			forced_width = 290,
			forced_height = 290,
			widget = wibox.widget.imagebox,
		},
		{
			{
				{
					{
						{
							{
								markup = helpers.colorizeText("Nguyen Thanh Son", beautiful.fg),
								font = "azuki_font Bold 15",
								widget = wibox.widget.textbox,
							},
							{
								markup = helpers.colorizeText("@sownteedev", beautiful.fg),
								font = "azuki_font 12",
								widget = wibox.widget.textbox,
							},
							layout = wibox.layout.fixed.vertical,
						},
						margins = 10,
						widget = wibox.container.margin,
					},
					shape = helpers.rrect(10),
					bg = beautiful.fg1 .. "66",
					widget = wibox.container.background,
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
	helpers.placeWidget(image, "top_left", 45, 0, 33, 0)

	return image
end
