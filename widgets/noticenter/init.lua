local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local helpers = require("helpers")
local wibox = require("wibox")
local gears = require("gears")
local make = require(... .. ".mods.make")
local progs = require(... .. ".mods.progs")

local empty = wibox.widget({
	{
		{
			image = gears.filesystem.get_configuration_dir() .. "/themes/assets/notify/wedding-bells.png",
			resize = true,
			forced_height = 400,
			halign = "center",
			widget = wibox.widget.imagebox,
		},
		widget = wibox.container.place,
		valign = "center",
	},
	widget = wibox.container.background,
	forced_height = 800,
})

local title = wibox.widget({
	font = "azuki_font Bold 15",
	markup = helpers.colorizeText("Notification Center", beautiful.foreground),
	widget = wibox.widget.textbox,
})

local clearButton = wibox.widget({
	image = gears.filesystem.get_configuration_dir() .. "/themes/assets/notify/trash.png",
	resize = true,
	forced_height = 20,
	forced_width = 20,
	halign = "center",
	widget = wibox.widget.imagebox,
	buttons = {
		awful.button({}, 1, function()
			notif_center_reset_notifs_container()
		end),
	},
})

awful.screen.connect_for_each_screen(function(s)
	local notify = wibox({
		screen = s,
		width = beautiful.width / 4.5,
		height = beautiful.height / 1.3,
		shape = helpers.rrect(5),
		ontop = true,
		visible = false,
	})

	local finalcontent = wibox.widget({
		layout = require("modules.overflow").vertical,
		scrollbar_enabled = false,
		spacing = 10,
	})
	finalcontent:insert(1, empty)

	local remove_notifs_empty = true

	notif_center_reset_notifs_container = function()
		finalcontent:reset(finalcontent)
		finalcontent:insert(1, empty)
		remove_notifs_empty = true
	end

	notif_center_remove_notif = function(box)
		finalcontent:remove_widgets(box)
		if #finalcontent.children == 0 then
			finalcontent:insert(1, empty)
			remove_notifs_empty = true
		end
	end

	naughty.connect_signal("request::display", function(n)
		if #finalcontent.children == 1 and remove_notifs_empty then
			finalcontent:reset(finalcontent)
			remove_notifs_empty = false
		end

		local appicon = n.icon or n.app_icon
		if not appicon then
			appicon = gears.color.recolor_image(
				gears.filesystem.get_configuration_dir() .. "/themes/assets/awm.png",
				helpers.randomColor()
			)
		end
		finalcontent:insert(1, make(appicon, n))
	end)

	notify:setup({
		{
			{
				{
					{
						title,
						nil,
						clearButton,
						widget = wibox.layout.align.horizontal,
					},
					widget = wibox.container.margin,
					margins = 20,
				},
				widget = wibox.container.background,
				bg = beautiful.lighter,
			},
			{
				{
					finalcontent,
					widget = wibox.container.margin,
					margins = 15,
				},
				widget = wibox.container.background,
			},
			progs,
			layout = wibox.layout.align.vertical,
		},
		widget = wibox.container.background,
		shape = helpers.rrect(10),
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
	})
	helpers.placeWidget(notify, "bottom_right", 0, 2, 0, 2)
	awesome.connect_signal("toggle::noticenter", function()
		notify.visible = not notify.visible
	end)
	awesome.connect_signal("close::noticenter", function()
		notify.visible = false
	end)
end)
