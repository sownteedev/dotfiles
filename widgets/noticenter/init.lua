local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local wibox = require("wibox")
local gears = require("gears")
local make = require(... .. ".make")

local empty = wibox.widget({
	{
		{
			{
				image = gears.color.recolor_image(beautiful.icon_path .. "awm/notification-empty.svg",
					beautiful.foreground),
				resize = true,
				forced_height = 300,
				halign = "center",
				widget = wibox.widget.imagebox,
			},
			{
				font = "azuki_font Bold 25",
				markup = _Utils.widget.colorizeText("No Notifications", beautiful.foreground),
				align = "center",
				widget = wibox.widget.textbox,
			},
			spacing = 30,
			layout = wibox.layout.fixed.vertical,
		},
		align = "center",
		widget = wibox.container.place,
	},
	widget = wibox.container.background,
	forced_height = 800,
})

local title = wibox.widget({
	font = beautiful.sans .. " Medium 15",
	markup = _Utils.widget.colorizeText("Notification Center", beautiful.foreground),
	widget = wibox.widget.textbox,
})

local clearButton = wibox.widget({
	{
		{
			image = gears.color.recolor_image(beautiful.icon_path .. "awm/clear.svg", beautiful.foreground),
			resize = true,
			forced_height = 25,
			forced_width = 25,
			halign = "center",
			widget = wibox.widget.imagebox,
		},
		margins = 10,
		widget = wibox.container.margin,
	},
	id = "bg",
	bg = beautiful.lighter,
	shape = gears.shape.circle,
	widget = wibox.container.background,
	buttons = {
		awful.button({}, 1, function()
			notif_center_reset_notifs_container()
		end),
	},
})
_Utils.widget.hoverCursor(clearButton)
_Utils.widget.addHoverBg(clearButton, "bg", beautiful.lighter, beautiful.lighter1)

local titleNotificenter = wibox.widget({
	{
		{
			title,
			nil,
			clearButton,
			widget = wibox.layout.align.horizontal,
		},
		top = 10,
		bottom = 10,
		left = 20,
		right = 20,
		widget = wibox.container.margin,
	},
	bg = beautiful.lighter,
	widget = wibox.container.background,
})

return function(s)
	local noticenter = wibox({
		screen = s,
		width = beautiful.width / 4.5,
		height = beautiful.height / 1.51,
		shape = beautiful.radius,
		border_width = beautiful.border_width,
		border_color = beautiful.lighter,
		ontop = true,
		visible = false,
	})

	local finalcontent = wibox.widget({
		layout = require("modules.overflow").vertical,
		scrollbar_enabled = false,
		spacing = 15,
	})
	finalcontent:insert(1, empty)

	local remove_notifs_empty = true

	notif_center_reset_notifs_container = function()
		for _, child in ipairs(finalcontent.children) do
			if child.timer then
				child.timer:stop()
				child.timer = nil
			end
		end
		finalcontent:reset()
		finalcontent:insert(1, empty)
		remove_notifs_empty = true
	end

	notif_center_remove_notif = function(box)
		if box.timer then
			if box.timer.started then
				box.timer:stop()
			end
			box.timer = nil
		end
		finalcontent:remove_widgets(box)
		if #finalcontent.children == 0 then
			finalcontent:insert(1, empty)
			remove_notifs_empty = true
		end
	end

	naughty.connect_signal("request::display", function(n)
		if remove_notifs_empty and #finalcontent.children == 1 then
			finalcontent:reset()
			remove_notifs_empty = false
		end
		finalcontent:insert(1, make(n))
	end)

	noticenter:setup({
		titleNotificenter,
		{
			{
				finalcontent,
				widget = wibox.container.margin,
				margins = 15,
			},
			widget = wibox.container.background,
		},
		layout = wibox.layout.fixed.vertical,
	})
	_Utils.widget.placeWidget(noticenter, "top_right", 2, 0, 0, 2)

	awesome.connect_signal("toggle::noticenter", function()
		noticenter.visible = not noticenter.visible
	end)

	awesome.connect_signal("close::noticenter", function()
		if noticenter.visible then
			noticenter.visible = false
		end
	end)

	awesome.connect_signal("signal::blur", function(status)
		titleNotificenter.bg = not status and beautiful.lighter or beautiful.lighter .. "DD"
		noticenter.bg = not status and beautiful.background or beautiful.background .. "DD"
	end)

	return noticenter
end
