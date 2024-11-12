local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local animation = require("modules.animation")

local ICONS = {
	brightness = {
		[90] = "󰃠 ",
		[60] = "󰃝 ",
		[30] = "󰃟 ",
		[10] = "󰃞 ",
	},
	volume = {
		high = " ",
		medium = "󰕾 ",
		low = " ",
		muted = "󰖁 "
	},
	mic = {
		on = " ",
		off = " "
	}
}

local COLORS = {
	brightness = beautiful.blue,
	volume = beautiful.red,
	mic = beautiful.green
}

local function get_icon_markup(icon, is_muted)
	return _Utils.widget.colorizeText(icon, is_muted and beautiful.red or beautiful.foreground)
end

local function update_progressbar(widget, color)
	local bar = _Utils.widget.gc(widget, "progressbar")
	bar:set_color(color)
	bar:set_background_color(color .. '22')
end

local function get_brightness_icon(value)
	for threshold, icon in pairs(ICONS.brightness) do
		if value > threshold then
			return icon
		end
	end
	return ICONS.brightness[10]
end

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
				forced_width = 5,
				forced_height = 200,
				direction = 'east',
				layout = wibox.container.rotate,
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
		bg = beautiful.background .. "EE",
		shape = beautiful.radius,
		border_width = beautiful.border_width,
		border_color = beautiful.lighter,
		placement = function(d)
			awful.placement.right(d, {
				margins = beautiful.useless_gap * 2,
				honor_workarea = true
			})
		end,
		widget = info,
	}

	local anim = animation:new {
		duration = 0.33,
		easing = animation.easing.linear,
		update = function(_, pos)
			_Utils.widget.gc(info, "progressbar").value = pos
		end,
	}

	awesome.connect_signal("signal::brightness", function(value)
		anim:set(value)
		update_progressbar(info, COLORS.brightness)
		_Utils.widget.gc(info, "icon"):set_markup_silently(
			get_icon_markup(get_brightness_icon(value))
		)
	end)

	awesome.connect_signal("signal::volume", function(value)
		anim:set(value)
		update_progressbar(info, COLORS.volume)
		local icon = value > 66 and ICONS.volume.high
			or value > 33 and ICONS.volume.medium
			or value > 0 and ICONS.volume.low
			or ICONS.volume.muted
		_Utils.widget.gc(info, "icon"):set_markup_silently(
			get_icon_markup(icon, value == 0)
		)
	end)

	awesome.connect_signal("signal::volumemute", function(value)
		if value then
			_Utils.widget.gc(info, "icon"):set_markup_silently(get_icon_markup(ICONS.volume.muted, true))
		else
			local current_volume = _Utils.widget.gc(info, "progressbar").value
			local icon = current_volume > 66 and ICONS.volume.high
				or current_volume > 33 and ICONS.volume.medium
				or current_volume > 0 and ICONS.volume.low
				or ICONS.volume.muted
			_Utils.widget.gc(info, "icon"):set_markup_silently(get_icon_markup(icon, false))
		end
	end)

	awesome.connect_signal("signal::mic", function(value)
		anim:set(value)
		update_progressbar(info, COLORS.mic)
		_Utils.widget.gc(info, "icon"):set_markup_silently(get_icon_markup(value > 0 and ICONS.mic.on or ICONS.mic.off,
			value == 0))
	end)

	awesome.connect_signal("signal::micmute", function(value)
		if value then
			_Utils.widget.gc(info, "icon"):set_markup_silently(get_icon_markup(ICONS.mic.off, true))
		else
			_Utils.widget.gc(info, "icon"):set_markup_silently(get_icon_markup(ICONS.mic.on, false))
		end
	end)

	local slide = animation:new {
		duration = 0.5,
		pos = beautiful.width + osd.width,
		easing = animation.easing.inOutExpo,
		update = function(_, pos)
			osd.x = pos
		end,
	}

	local slide_hide = gears.timer {
		timeout = 0.5,
		single_shot = true,
		callback = function()
			osd.visible = false
		end,
	}

	local slide_end = gears.timer {
		timeout = 2,
		single_shot = true,
		callback = function()
			slide_hide:start()
			slide:set(beautiful.width + osd.width)
		end,
	}

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
