local awful       = require("awful")
local beautiful   = require("beautiful")
local wibox       = require("wibox")
local gears       = require("gears")
local timer       = require("gears.timer")
local naughty     = require("naughty")

local checkFolder = function(type)
	if type == "rec" and not os.rename(os.getenv("HOME") .. "/Videos/Recordings", os.getenv("HOME") .. "/Videos/Recordings") then
		os.execute("mkdir -p " .. os.getenv("HOME") .. "/Videos/Recordings")
	elseif type == "screenshot" and not os.rename(os.getenv("HOME") .. "/Pictures/Screenshots/", os.getenv("HOME") .. "/Pictures/Screenshots") then
		os.execute("mkdir -p " .. os.getenv("HOME") .. "/Pictures/Screenshots")
	end
end

local getName     = function(type)
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

local _run       = {}
_run.timer_table = {}
local function newtimer(name, timeout, fun, nostart, stoppable)
	if not name or #name == 0 then return end
	name = (stoppable and name) or timeout
	if not _run.timer_table[name] then
		_run.timer_table[name] = timer({ timeout = timeout })
		_run.timer_table[name]:start()
	end
	_run.timer_table[name]:connect_signal("timeout", fun)
	if not nostart then
		_run.timer_table[name]:emit_signal("timeout")
	end
	return stoppable and _run.timer_table[name]
end

local createButton = function(name, desc, img, cmd1, cmd2)
	local bg_container = wibox.container.background()
	local name_widget = wibox.widget({
		markup = name,
		font = beautiful.sans .. " Medium 12",
		widget = wibox.widget.textbox,
	})
	local desc_widget = wibox.widget({
		markup = desc,
		font = beautiful.sans .. " 9",
		widget = wibox.widget.textbox,
	})
	local img_widget = wibox.widget({
		image = gears.color.recolor_image(img, beautiful.foreground),
		resize = true,
		valign = "center",
		forced_height = name == "Screenshot" and 35 or 25,
		forced_width = name == "Screenshot" and 35 or 25,
		widget = wibox.widget.imagebox,
	})

	local elapsed_time = 0
	local function update_desc()
		elapsed_time = elapsed_time + 1
		local minutes = math.floor(elapsed_time / 60)
		local seconds = elapsed_time % 60
		desc_widget.markup = _Utils.widget.colorizeText(string.format("Recording... [%02d:%02d]", minutes, seconds),
			beautiful.lighter)
	end
	local recording_timer = nil

	local buttons = wibox.widget({
		{
			{
				{
					img_widget,
					{
						name_widget,
						desc_widget,
						spacing = 5,
						layout = wibox.layout.fixed.vertical,
					},
					spacing = name == "Screenshot" and 10 or 20,
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
		widget = bg_container,
		buttons = gears.table.join(
			awful.button({}, 1, function()
				awful.spawn.with_shell(cmd1)
				if name == "Recorder" then
					bg_container.bg = beautiful.red
					img_widget.image = gears.color.recolor_image(img, beautiful.lighter)
					name_widget.markup = _Utils.widget.colorizeText(name, beautiful.lighter)
					elapsed_time = 0
					recording_timer = newtimer("recording_timer", 1, update_desc, false, true)
				end
				awesome.emit_signal("close::control")
			end),
			awful.button({}, 3, function()
				awful.spawn.with_shell(cmd2)
				bg_container.bg = beautiful.lighter
				img_widget.image = gears.color.recolor_image(img, beautiful.foreground)
				name_widget.markup = _Utils.widget.colorizeText(name, beautiful.foreground)
				desc_widget.markup = _Utils.widget.colorizeText(desc, beautiful.foreground)
				if recording_timer then
					recording_timer:stop()
					_run.timer_table["recording_timer"] = nil
					recording_timer = nil
				end
				awesome.emit_signal("close::control")
			end)
		),
	})
	_Utils.widget.hoverCursor(buttons)

	return buttons
end

local button = wibox.widget({
	createButton("Screenshot", "Take Area", beautiful.icon_path .. "button/screenshot.svg", "awesome-client 'area()'", ""),
	createButton("Recorder", "Is Resting", beautiful.icon_path .. "button/record.svg",
		"awesome-client 'record()'",
		"killall ffmpeg"),
	spacing = 15,
	layout = wibox.layout.fixed.horizontal,
})

return button
