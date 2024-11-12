local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local gears = require("gears")

local createButton = function(signal, name, desc, img, cmd1)
	local powerndark = wibox.widget({
		{
			{
				{
					{
						id = "icon",
						image = gears.color.recolor_image(img, beautiful.foreground),
						resize = true,
						valign = "center",
						forced_height = 30,
						forced_width = 30,
						widget = wibox.widget.imagebox,
					},
					{
						{
							id = "name",
							markup = name,
							font = beautiful.font,
							widget = wibox.widget.textbox,
						},
						{
							id = "desc",
							markup = desc,
							font = beautiful.sans .. " 10",
							widget = wibox.widget.textbox,
						},
						spacing = 5,
						layout = wibox.layout.fixed.vertical,
					},
					spacing = 20,
					layout = wibox.layout.fixed.horizontal,
				},
				align = "center",
				widget = wibox.container.place,
			},
			margins = 20,
			widget = wibox.container.margin,
		},
		id = "bg",
		forced_width = 225,
		shape = beautiful.radius,
		bg = beautiful.lighter,
		widget = wibox.container.background,
		buttons = gears.table.join(
			awful.button({}, 1, function()
				awful.spawn.with_shell(cmd1)
			end)
		),
	})

	local function updateWidget(bg, icon, names, descs)
		_Utils.widget.gc(powerndark, "icon"):set_image(gears.color.recolor_image(img, icon))
		_Utils.widget.gc(powerndark, "bg"):set_bg(bg)
		_Utils.widget.gc(powerndark, "name"):set_markup_silently(_Utils.widget.colorizeText(names, icon))
		_Utils.widget.gc(powerndark, "desc"):set_markup_silently(_Utils.widget.colorizeText(descs, icon))
	end

	if signal == "powermode" then
		awesome.connect_signal("signal::powermode", function(stdout)
			local bg, icon, names, descs
			if stdout == "power-saver" then
				bg = beautiful.yellow
				icon = beautiful.lighter
				names = "Power Save"
				descs = "Power Save"
			elseif stdout == "balanced" then
				bg = beautiful.lighter
				icon = beautiful.foreground
				names = "Balanced"
				descs = "Balanced"
			else
				bg = beautiful.blue
				icon = beautiful.lighter
				names = "Perfomance"
				descs = "Perfomance"
			end
			updateWidget(bg, icon, names, descs)
		end)
	else
		awesome.connect_signal("signal::darkmode", function(stdout)
			local bg, icon, names, descs
			if stdout then
				bg = beautiful.blue
				icon = beautiful.lighter
				names = "Darkmode"
				descs = "On"
			else
				bg = beautiful.lighter
				icon = beautiful.foreground
				names = "Darkmode"
				descs = "Off"
			end
			updateWidget(bg, icon, names, descs)
		end)
	end
	_Utils.widget.hoverCursor(powerndark)

	return powerndark
end

local button = wibox.widget({
	createButton("powermode", "Powermode", "Balanced", beautiful.icon_path .. "power/powermode.svg",
		"awesome-client 'switch_power_mode()'"),
	createButton("darkmode", "Darkmode", "Off", beautiful.icon_path .. "power/darkmode.svg",
		"awesome-client 'toggle_darkmode()'"),
	spacing = 15,
	layout = wibox.layout.fixed.horizontal,
})

return button
