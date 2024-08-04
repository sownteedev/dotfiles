local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")

local M = {}

local checkFolder = function(type)
	if type == "rec" and not os.rename(os.getenv("HOME") .. "/Videos/Recordings", os.getenv("HOME") .. "/Videos/Recordings") then
		os.execute("mkdir -p " .. os.getenv("HOME") .. "/Videos/Recordings")
	elseif type == "screenshot" and not os.rename(os.getenv("HOME") .. "/Pictures/Screenshots/", os.getenv("HOME") .. "/Pictures/Screenshots") then
		os.execute("mkdir -p " .. os.getenv("HOME") .. "/Pictures/Screenshots")
	end
end
local getName = function(type)
	---@diagnostic disable: param-type-mismatch
	if type == "rec" then
		local string = "~/Videos/Recordings/" .. os.date("%d-%m-%Y-%H:%M:%S") .. ".mp4"
		string = string:gsub("~", os.getenv("HOME"))
		return string
	elseif type == "screenshot" then
		local string = "~/Pictures/Screenshots/" .. os.date("%d-%m-%Y-%H:%M:%S") .. ".png"
		string = string:gsub("~", os.getenv("HOME"))
		return string
	end
end

M.rec_mic = function()
	local default_mic_source = io.popen("pactl info | grep 'Default Source' | awk '{print $3}'"):read("*l")
	local display = os.getenv("DISPLAY")
	local name = getName("rec")
	local defCommand = string.format(
		"sleep 1.25 && ffmpeg -y -f x11grab "
		.. "-r 60 -i %s -f pulse -i %s -c:v libx264 -qp 0 -profile:v main "
		.. "-preset ultrafast -tune zerolatency -crf 28 -pix_fmt yuv420p "
		.. "-c:a aac -b:a 64k -b:v 500k %s &",
		display,
		default_mic_source,
		name
	)
	print(defCommand)
	checkFolder("rec")
	awful.spawn.easy_async_with_shell(defCommand)
end

M.rec_audio = function()
	local speaker_input = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink.monitor"
	local display = os.getenv("DISPLAY")
	local name = getName("rec")
	local defCommand = string.format(
		"sleep 1.25 && ffmpeg -y -f x11grab "
		.. "-r 60 -i %s -f pulse -i %s -c:v libx264 -qp 0 -profile:v main "
		.. "-preset ultrafast -tune zerolatency -crf 28 -pix_fmt yuv420p "
		.. "-c:a aac -b:a 64k -b:v 500k %s &",
		display,
		speaker_input,
		name
	)
	print(defCommand)
	checkFolder("rec")
	awful.spawn.easy_async_with_shell(defCommand)
end


local function do_notify(tmp_path)
	local open = naughty.action({ name = "Open" })
	local delete = naughty.action({ name = "Delete" })

	open:connect_signal("invoked", function()
		awful.spawn.easy_async_with_shell('xclip -sel clip -target image/png "' ..
			tmp_path .. '" && xdg-open "' .. tmp_path .. '" &')
		naughty.notify({
			app_name = "Screenshot",
			app_icon = tmp_path,
			icon = tmp_path,
			title = "Screenshot",
			text = "Screenshot copied successfully.",
		})
	end)

	delete:connect_signal("invoked", function()
		awful.spawn.easy_async_with_shell(
			'xclip -sel clip -target image/png "' .. tmp_path .. '" && rm -f "' .. tmp_path .. '" &'
		)
		naughty.notify({
			app_name = "Screenshot",
			title = "Screenshot",
			text = "Screenshot copied and deleted successfully.",
		})
	end)

	naughty.notify({
		app_name = "Screenshot",
		app_icon = tmp_path,
		icon = tmp_path,
		title = "Screenshot",
		text = "Screenshot saved successfully",
		actions = {
			open,
			delete,
		},
	})
end

local function with_defaults(given_opts)
	return { notify = given_opts == nil and false or given_opts.notify }
end

function M.full(opts)
	checkFolder("screenshot")
	local tmp_path = getName("screenshot")
	gears.timer({
		timeout = 1.5,
		call_now = false,
		autostart = true,
		single_shot = true,
		callback = function()
			awful.spawn.easy_async_with_shell('maim "' .. tmp_path .. '" &', function()
				awesome.emit_signal("screenshot::done")
				if with_defaults(opts).notify then
					do_notify(tmp_path)
				end
			end)
		end,
	})
end

function M.area(opts)
	checkFolder("screenshot")
	local tmp_path = getName("screenshot")
	awful.spawn.easy_async_with_shell('sleep 1.5 && maim --select "' .. tmp_path .. '" &', function()
		awesome.emit_signal("screenshot::done")
		if with_defaults(opts).notify then
			do_notify(tmp_path)
		end
	end)
end

function M.window(opts)
	checkFolder("screenshot")
	local tmp_path = getName("screenshot")
	awful.spawn.easy_async_with_shell('maim --window=$(xdotool getactivewindow) "' .. tmp_path .. '" &', function()
		awesome.emit_signal("screenshot::done")
		if with_defaults(opts).notify then
			do_notify(tmp_path)
		end
	end)
end

return M
