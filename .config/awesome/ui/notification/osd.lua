local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local helpers = require("helpers")
local animation = require("modules.animation")

-- osd --
local info = wibox.widget({
	layout = wibox.layout.fixed.horizontal,
	{
		widget = wibox.container.margin,
		margins = 20,
		{
			layout = wibox.layout.fixed.horizontal,
			fill_space = true,
			spacing = 10,
			{
				widget = wibox.widget.textbox,
				id = "icon",
				font = beautiful.icon .. " 13",
			},
			{
				widget = wibox.container.background,
				forced_width = 25,
				{
					widget = wibox.widget.textbox,
					id = "text",
					font = beautiful.sans .. " 9",
					halign = "center",
				},
			},
			{
				widget = wibox.widget.progressbar,
				id = "progressbar",
				max_value = 100,
				forced_width = 200,
				forced_height = 10,
				background_color = beautiful.background_urgent,
				color = beautiful.accent,
			},
		},
	},
})

local osd = awful.popup({
	visible = false,
	ontop = true,
	bg = beautiful.background_dark,
	border_width = beautiful.border_width,
	border_color = beautiful.border_color_normal,
	minimum_height = 50,
	maximum_height = 55,
	forced_width = 300,
	shape = helpers.rrect(5),
	placement = function(d)
		awful.placement.bottom(d, { honor_workarea = true, margins = beautiful.useless_gap * 2 })
	end,
	widget = info,
})

local anim = animation:new({
	duration = 0.3,
	easing = animation.easing.linear,
	subscribed = function(value)
		info:get_children_by_id("progressbar")[1].value = value
	end,
})

-- volume --
awesome.connect_signal("signal::volume", function(value)
	anim:set(value)
	info:get_children_by_id("text")[1].text = value
	if value > 66 then
		info:get_children_by_id("icon")[1].text = " "
	elseif value > 33 then
		info:get_children_by_id("icon")[1].text = "󰕾 "
	elseif value > 0 then
		info:get_children_by_id("icon")[1].text = " "
	else
		info:get_children_by_id("icon")[1].text = "󰖁 "
	end
end)

-- bright --
awesome.connect_signal("signal::brightness", function(value)
	anim:set(value)
	info:get_children_by_id("text")[1].text = value
	if value > 90 then
		info:get_children_by_id("icon")[1].text = "󰃠 "
	elseif value > 60 then
		info:get_children_by_id("icon")[1].text = "󰃟 "
	elseif value > 30 then
		info:get_children_by_id("icon")[1].text = "󰃝 "
	elseif value > 10 then
		info:get_children_by_id("icon")[1].text = "󰃞 "
	end
end)

-- function --

local function osd_hide()
	osd.visible = false
	osd_timer:stop()
end

local osd_timer = gears.timer({
	timeout = 4,
	callback = osd_hide,
})

local function osd_toggle()
	if not osd.visible then
		osd.visible = true
		osd_timer:start()
	else
		osd_timer:again()
	end
end

awesome.connect_signal("sowntee::osd", function()
	osd_toggle()
end)
