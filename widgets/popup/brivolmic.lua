local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local animation = require("modules.animation")
local helpers = require("helpers")

return function(s)
	local info = wibox.widget {
		margins = 20,
		widget = wibox.container.margin,
		{
			{
				{
					id = "progressbar",
					max_value = 100,
					shape = beautiful.radius,
					bar_shape = beautiful.radius,
					widget = wibox.widget.progressbar,
				},
				forced_width  = 5,
				forced_height = 200,
				direction     = 'east',
				layout        = wibox.container.rotate,
			},
			{
				{
					id = "icon",
					align = "center",
					font = beautiful.icon .. " 18",
					markup = "",
					widget = wibox.widget.textbox,
				},
				left = 10,
				widget = wibox.container.margin,
			},
			spacing = 20,
			layout = wibox.layout.fixed.vertical,
		},
	}

	local osd = awful.popup {
		visible = false,
		screen = s,
		ontop = true,
		bg = beautiful.background,
		shape = beautiful.radius,
		placement = function(d)
			awful.placement.right(d, { margins = beautiful.useless_gap * 2, honor_workarea = true })
		end,
		widget = info,
	}

	local anim = animation:new {
		duration = 0.3,
		easing = animation.easing.linear,
		update = function(self, pos)
			info:get_children_by_id("progressbar")[1].value = pos
		end,
	}

	awesome.connect_signal("signal::brightness", function(value)
		anim:set(value)
		helpers.gc(info, "progressbar"):set_color(beautiful.blue)
		helpers.gc(info, "progressbar"):set_background_color(beautiful.blue .. '22')
		if value > 90 then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰃠 ", beautiful.foreground))
		elseif value > 60 then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰃝 ", beautiful.foreground))
		elseif value > 30 then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰃟 ", beautiful.foreground))
		elseif value > 10 then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰃞 ", beautiful.foreground))
		end
	end)

	awesome.connect_signal("signal::volume", function(value)
		anim:set(value)
		helpers.gc(info, "progressbar"):set_color(beautiful.red)
		helpers.gc(info, "progressbar"):set_background_color(beautiful.red .. '22')
		if value > 66 then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText(" ", beautiful.foreground))
		elseif value > 33 then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰕾 ", beautiful.foreground))
		elseif value > 0 then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText(" ", beautiful.foreground))
		else
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰖁 ", beautiful.red))
		end
	end)
	awesome.connect_signal("signal::volumemute", function(value)
		if value then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText("󰖁 ", beautiful.red))
		end
	end)

	awesome.connect_signal("signal::mic", function(value)
		anim:set(value)
		helpers.gc(info, "progressbar"):set_color(beautiful.green)
		helpers.gc(info, "progressbar"):set_background_color(beautiful.green .. '22')
		if value > 0 then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText(" ", beautiful.foreground))
		else
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText(" ", beautiful.red))
		end
	end)
	awesome.connect_signal("signal::micmute", function(value)
		if value then
			helpers.gc(info, "icon"):set_markup_silently(helpers.colorizeText(" ", beautiful.red))
		end
	end)


	local slide = animation:new({
		duration = 0.5,
		pos = beautiful.width + osd.width,
		easing = animation.easing.inOutExpo,
		update = function(_, poss)
			osd.x = poss
		end,
	})

	local slide_hide = gears.timer({
		timeout = 0.5,
		single_shot = true,
		callback = function()
			osd.visible = false
		end,
	})

	local function osd_hide()
		slide_hide:start()
		slide:set(beautiful.width + osd.width)
	end

	local slide_end = gears.timer({
		timeout = 2,
		single_shot = true,
		callback = osd_hide,
	})

	awesome.connect_signal("open::brivolmic", function()
		if osd.visible then
			slide_end:again()
		else
			osd.visible = true
			slide:set(beautiful.width - 100)
			slide_end:start()
		end
	end)

	return osd
end
