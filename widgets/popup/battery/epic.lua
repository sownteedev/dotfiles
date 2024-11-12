local wibox = require("wibox")
local beautiful = require("beautiful")
local gears = require("gears")

return function(icon_name)
	local my_charging_icon = {
		id = "my_charging_icon",
		image = gears.color.recolor_image(beautiful.icon_path .. "popup/charge.svg",
			beautiful.foreground),
		forced_width = 20,
		forced_height = 20,
		visible = false,
		widget = wibox.widget.imagebox,
	}

	local my_icon = {
		id = "my_icon",
		image = _Utils.icon.lookup_icon({ icon_name = icon_name, recolor = beautiful.foreground }) or
			gears.color.recolor_image(beautiful.icon_path .. "/popup/" .. icon_name .. ".svg",
				beautiful.foreground),
		widget = wibox.widget.imagebox,
		forced_width = 50,
		forced_height = 50,
	}

	local my_chart = {
		{
			{
				my_icon,
				margins = 20,
				widget = wibox.container.margin,
			},
			id = "my_chart",
			widget = wibox.container.arcchart,
			colors = { beautiful.green },
			rounded_edge = true,
			thickness = 10,
			min_value = 0,
			max_value = 100,
			value = 25,
			forced_width = 90,
			forced_height = 90,
			bg = beautiful.lighter,
			start_angle = 4.7,
		},
		{
			{
				my_charging_icon,
				widget = wibox.container.margin,
				top = -5,
			},
			widget = wibox.container.place,
			halign = "center",
			valign = "top",
		},
		layout = wibox.layout.stack,
	}

	local my_textbox = {
		id = "my_textbox",
		text = "0%",
		font = beautiful.sans .. " Medium 11",
		widget = wibox.widget.textbox,
		halign = "center",
	}

	local w = wibox.widget({
		my_chart,
		my_textbox,
		spacing = 10,
		layout = wibox.layout.fixed.vertical,
	})

	local chart = w:get_children_by_id("my_chart")[1]
	local textbox = w:get_children_by_id("my_textbox")[1]
	local charging_icon = w:get_children_by_id("my_charging_icon")[1]

	local battery

	if icon_name == "laptop-symbolic" then
		battery = _Utils.upower.gobject_to_gearsobject(_Utils.upower.upowers:get_display_device())
		local update = function(self)
			chart.colors = self.percentage <= 20 and { beautiful.red } or { beautiful.green }
			chart.value = self.percentage
			textbox.text = math.floor(self.percentage) .. "%"
		end

		if battery ~= nil then
			battery:connect_signal("property::percentage", update)
			battery:connect_signal("property::state", update)
			awesome.connect_signal("signal::batterystatus", function(status)
				charging_icon.visible = status
			end)
			battery:emit_signal("property::percentage", battery.percentage)
		end
	else
		local update = function()
			if battery ~= nil then
				chart.value = battery.percentage
				textbox.text = math.floor(battery.percentage) .. "%"
			elseif icon_name == "input-mouse-symbolic" then
				chart.value = 80
				textbox.text = "80%"
			elseif icon_name == "keyboards" then
				chart.value = 50
				textbox.text = "50%"
			elseif icon_name == "headphones-symbolic" then
				chart.value = 30
				textbox.text = "30%"
			end
		end
		update()

		local connect = function()
			battery:connect_signal("property::percentage", update)
			battery:connect_signal("property::state", update)
			battery:emit_signal("property::percentage")
			battery:emit_signal("property::state")
		end

		local disconnect = function()
			battery:disconnect_signal("property::percentage", update)
			battery:disconnect_signal("property::state", update)
			battery = nil
		end

		for _, dev in pairs(_Utils.upower.upowers:get_devices()) do
			if type(string.find(dev.model, "mouse")) == "number" then
				battery = _Utils.upower.gobject_to_gearsobject(dev)
				connect()
				update()
			end
		end

		_Utils.upower.upowers:connect_signal("device-added", function(_, dev)
			if type(string.find(dev.model, "mouse")) == "number" then
				battery = _Utils.upower.gobject_to_gearsobject(dev)
				connect()
				update()
			end
		end)

		_Utils.upower.upowers:connect_signal("device-removed", function(_, path)
			if battery and battery:get_object_path() == path then
				disconnect()
				update()
			end
		end)
	end

	return w
end
