local awful = require("awful")
local beautiful = require("beautiful")
local wibox = require("wibox")
local gears = require("gears")
local naughty = require("naughty")
local helpers = require("helpers")

local checkFolder = function(type)
	if type == "rec" and not os.rename(os.getenv("HOME") .. "/Videos/Recordings", os.getenv("HOME") .. "/Videos/Recordings") then
		os.execute("mkdir -p " .. os.getenv("HOME") .. "/Videos/Recordings")
	elseif type == "screenshot" and not os.rename(os.getenv("HOME") .. "/Pictures/Screenshots/", os.getenv("HOME") .. "/Pictures/Screenshots") then
		os.execute("mkdir -p " .. os.getenv("HOME") .. "/Pictures/Screenshots")
	end
end

local getName = function(type)
	---@diagnostic disable: param-type-mismatch
	local string = ""
	if type == "rec" then
		string = "~/Videos/Recordings/" .. os.date("%d-%m-%Y-%H:%M:%S") .. ".mp4"
	elseif type == "screenshot" then
		string = "~/Pictures/Screenshots/" .. os.date("%d-%m-%Y-%H:%M:%S") .. ".png"
	end
	string = string:gsub("~", os.getenv("HOME"))
	return string
end

local function do_notify(which, tmp_path)
	if which == "screenshot" then
		local open = naughty.action({ name = "Open", icon = beautiful.icon_path .. "button/openimage.svg" })
		local delete = naughty.action({ name = "Delete", icon = beautiful.icon_path .. "button/delete.svg" })

		open:connect_signal("invoked", function()
			awful.spawn.with_shell('xclip -sel clip -target image/png "' ..
				tmp_path .. '" && viewnior "' .. tmp_path .. '"')
			naughty.notify({
				app_name = "photo",
				icon = tmp_path,
				title = "Screenshot",
				text = "Screenshot copied successfully.",
			})
		end)

		delete:connect_signal("invoked", function()
			awful.spawn.with_shell('xclip -sel clip -target image/png "' ..
				tmp_path .. '" && rm -f "' .. tmp_path .. '"')
			naughty.notify({
				app_name = "photo",
				title = "Screenshot",
				text = "Screenshot copied and deleted successfully.",
			})
		end)

		naughty.notify({
			app_name = "photo",
			icon = tmp_path,
			title = "Screenshot",
			text = "Screenshot saved successfully",
			actions = {
				open,
				delete,
			},
		})
	elseif which == "rec" then
		local open = naughty.action({ name = "Open", icon = beautiful.icon_path .. "button/openvideo.svg" })
		local delete = naughty.action({ name = "Delete", icon = beautiful.icon_path .. "button/delete.svg" })

		open:connect_signal("invoked", function()
			awful.spawn.with_shell('xdg-open "' .. tmp_path .. '"')
		end)

		delete:connect_signal("invoked", function()
			awful.spawn.with_shell('rm -f "' .. tmp_path .. '"')
			naughty.notify({
				app_name = "screenrecorder",
				title = "Recording",
				text = "Recording deleted successfully.",
			})
		end)

		naughty.notify({
			app_name = "screenrecorder",
			title = "Recording",
			text = "Recording saved successfully",
			actions = {
				open,
				delete,
			},
		})
	end
end

function area()
	checkFolder("screenshot")
	local tmp_path = getName("screenshot")
	awful.spawn.easy_async_with_shell('sleep 1.5 && maim --select "' .. tmp_path .. '"', function()
		do_notify("screenshot", tmp_path)
	end)
end

function record()
	checkFolder("rec")
	local speaker_input = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink.monitor"
	local name = getName("rec")
	local defCommand = string.format(
		"sleep 1.25 && ffmpeg -y -r 60 "
		-- display and audio
		.. "-f x11grab -i :0.0 -f pulse -i %s "
		-- video
		.. "-c:v libx264 -crf 23 -preset veryfast -b:v 1M "
		-- audio
		.. "-c:a libvorbis -b:a 128k %s",
		speaker_input,
		name
	)
	print(defCommand)
	awful.spawn.easy_async_with_shell(defCommand, function()
		do_notify("rec", name)
	end)
end

local createButton = function(name, img, cmd1, cmd2)
	local buttons = wibox.widget({
		{
			{
				{
					{
						image = gears.color.recolor_image(img,
							beautiful.foreground),
						resize = true,
						forced_height = 35,
						forced_width = 35,
						widget = wibox.widget.imagebox,
					},
					{
						markup = name,
						font = beautiful.font,
						widget = wibox.widget.textbox,
					},
					spacing = 10,
					layout = wibox.layout.fixed.horizontal,
				},
				align = "center",
				widget = wibox.container.place,
			},
			margins = 20,
			widget = wibox.container.margin,
		},
		forced_width = 225,
		shape = beautiful.radius,
		bg = beautiful.lighter,
		widget = wibox.container.background,
		buttons = gears.table.join(
			awful.button({}, 1, function()
				awful.spawn.with_shell(cmd1)
				awesome.emit_signal("close::control")
			end),
			awful.button({}, 3, function()
				awful.spawn.with_shell(cmd2)
				awesome.emit_signal("close::control")
			end)
		),
	})
	helpers.hoverCursor(buttons)

	return buttons
end

local button = wibox.widget({
	createButton("Screenshot", beautiful.icon_path .. "button/screenshot.svg", "awesome-client 'area()'", ""),
	createButton("Record", beautiful.icon_path .. "button/record.svg", "awesome-client 'record()'", "killall ffmpeg"),
	spacing = 15,
	layout = wibox.layout.fixed.horizontal,
})

return button
