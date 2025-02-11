local awful       = require("awful")
local beautiful   = require("beautiful")
local wibox       = require("wibox")
local gears       = require("gears")
local timer       = require("gears.timer")
local naughty     = require("naughty")

local checkFolder = function(type)
	local base_path = os.getenv("HOME")
	if type == "rec" then
		local recordings_path = base_path .. "/Videos/Recordings"
		if not os.rename(recordings_path, recordings_path) then
			os.execute("mkdir -p " .. recordings_path)
		end
	elseif type == "screenshot" then
		local screenshots_path = base_path .. "/Pictures/Screenshots"
		if not os.rename(screenshots_path, screenshots_path) then
			os.execute("mkdir -p " .. screenshots_path)
		end
	end
end

local getName     = function(type)
	---@diagnostic disable: param-type-mismatch
	local file_extension = (type == "rec") and ".mp4" or ".png"
	local folder_path = (type == "rec") and "~/Videos/Recordings/" or "~/Pictures/Screenshots/"
	local filename = folder_path .. os.date("%d-%m-%Y-%H:%M:%S") .. file_extension
	return filename:gsub("~", os.getenv("HOME"))
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
		-- display
		.. "-f x11grab -s 2560x1600 -i :0.0 "
		-- audio
		.. "-f pulse -i %s "
		-- video
		.. "-c:v libx264 -preset superfast -crf 23 "
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

local createButton = function(name, desc, img, cmd1)
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
	local clicked = false
	local recording_timer = nil
	local function update_desc()
		elapsed_time = elapsed_time + 1
		local minutes = math.floor(elapsed_time / 60)
		local seconds = elapsed_time % 60
		desc_widget.markup = _Utils.widget.colorizeText(string.format("Recording... [%02d:%02d]", minutes, seconds),
			beautiful.lighter)
	end

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
				if name == "Recorder" then
					if not clicked then
						awful.spawn.with_shell(cmd1)
						bg_container.bg = beautiful.red
						img_widget.image = gears.color.recolor_image(img, beautiful.lighter)
						name_widget.markup = _Utils.widget.colorizeText(name, beautiful.lighter)
						elapsed_time = 0
						recording_timer = newtimer("recording_timer", 1, update_desc, false, true)
						clicked = true
					else
						awful.spawn.with_shell("killall ffmpeg")
						bg_container.bg = beautiful.lighter
						img_widget.image = gears.color.recolor_image(img, beautiful.foreground)
						name_widget.markup = _Utils.widget.colorizeText(name, beautiful.foreground)
						desc_widget.markup = _Utils.widget.colorizeText(desc, beautiful.foreground)
						if recording_timer then
							recording_timer:stop()
							_run.timer_table["recording_timer"] = nil
							recording_timer = nil
						end
						clicked = false
					end
				else
					awful.spawn.with_shell(cmd1)
				end
				awesome.emit_signal("close::control")
			end)
		),
	})
	_Utils.widget.hoverCursor(buttons)

	return buttons
end

local button = wibox.widget({
	createButton("Screenshot", "Take Area", beautiful.icon_path .. "button/screenshot.svg", "awesome-client 'area()'"),
	createButton("Recorder", "Is Resting", beautiful.icon_path .. "button/record.svg", "awesome-client 'record()'"),
	spacing = 15,
	layout = wibox.layout.fixed.horizontal,
})

return button
