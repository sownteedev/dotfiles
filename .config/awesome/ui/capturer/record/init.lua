local wibox = require("wibox")
local helpers = require("helpers")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local animation = require("modules.animation")

local checkFolder = function()
	if not os.rename(os.getenv("HOME") .. "/Videos/Recordings", os.getenv("HOME") .. "/Videos/Recordings") then
		os.execute("mkdir -p " .. os.getenv("HOME") .. "/Videos/Recordings")
	end
end

local getName = function()
	local string = "~/Videos/Recordings/" .. os.date("%d-%m-%Y-%H:%M:%S") .. ".mp4"
	string = string:gsub("~", os.getenv("HOME"))
	return string
end

local rec_mic = function(fps, file_name)
	local display = os.getenv("DISPLAY")
	local defCommand = string.format(
		"sleep 1 && ffmpeg -y -f x11grab "
			.. "-r %s -i %s -f pulse -i 59 -c:v libx264 -qp 0 -profile:v main "
			.. "-preset ultrafast -tune zerolatency -crf 28 -pix_fmt yuv420p "
			.. "-c:a aac -b:a 64k -b:v 500k %s",
		fps,
		display,
		file_name
	)
	print(defCommand)
	awful.spawn.with_shell(defCommand)
end

local rec_audio = function(fps, file_name)
	local display = os.getenv("DISPLAY")
	local defCommand = string.format(
		"sleep 1 && ffmpeg -y -f x11grab "
			.. "-r %s -i %s -f pulse -i 57 -c:v libx264 -qp 0 -profile:v main "
			.. "-preset ultrafast -tune zerolatency -crf 28 -pix_fmt yuv420p "
			.. "-c:a aac -b:a 64k -b:v 500k %s",
		fps,
		display,
		file_name
	)
	print(defCommand)
	awful.spawn.with_shell(defCommand)
end

local createButton = function(icon, name, fn, col)
	return wibox.widget({
		{
			{
				{
					{
						{
							font = beautiful.icon .. " 25",
							markup = icon,
							valign = "center",
							align = "center",
							widget = wibox.widget.textbox,
						},
						layout = wibox.container.margin,
						top = 10,
						left = 10,
					},
					{
						{
							font = beautiful.sans .. " 15",
							markup = name,
							valign = "center",
							align = "center",
							widget = wibox.widget.textbox,
						},
						layout = wibox.container.margin,
						bottom = 10,
					},
					layout = wibox.layout.fixed.vertical,
					spacing = 20,
				},
				widget = wibox.container.margin,
				margins = 15,
			},
			forced_width = 130,
			bg = beautiful.background,
			widget = wibox.container.background,
		},
		{
			forced_height = 5,
			forced_width = 130,
			bg = col,
			widget = wibox.container.background,
		},
		layout = wibox.layout.fixed.vertical,
		buttons = awful.button({}, 1, function()
			fn()
		end),
	})
end

awful.screen.connect_for_each_screen(function(s)
	local recorder = wibox({
		width = 450,
		height = 240,
		shape = helpers.rrect(5),
		bg = beautiful.darker,
		ontop = true,
		visible = false,
	})
	local slide = animation:new({
		duration = 1,
		pos = 0 - recorder.height,
		easing = animation.easing.inOutExpo,
		update = function(_, pos)
			recorder.y = s.geometry.y + pos
		end,
	})

	local slide_end = gears.timer({
		single_shot = true,
		timeout = 1,
		callback = function()
			recorder.visible = false
		end,
	})

	local close = function()
		slide_end:again()
		slide:set(0 - recorder.height)
	end

	local recaudio = createButton(" ", "Rec Audio", function()
		close()
		checkFolder()
		local name = getName()
		rec_audio("60", name)
	end, beautiful.green)

	local recmic = createButton("󰄄 ", "Rec Mic", function()
		close()
		checkFolder()
		local name = getName()
		rec_mic("60", name)
	end, beautiful.blue)

	local stop = createButton("󰜺 ", "Finish", function()
		close()
		awful.spawn.with_shell("killall ffmpeg")
	end, beautiful.red)

	recorder:setup({
		{
			{
				{
					{
						{
							font = beautiful.sans .. " Bold 15",
							markup = "Video Recorder",
							valign = "center",
							align = "start",
							widget = wibox.widget.textbox,
						},
						widget = wibox.layout.align.horizontal,
					},
					widget = wibox.container.margin,
					margins = 15,
				},
				widget = wibox.container.background,
				bg = beautiful.lighter,
			},
			{
				recaudio,
				recmic,
				stop,
				spacing = 15,
				layout = wibox.layout.fixed.horizontal,
			},
			spacing = 15,
			layout = wibox.layout.fixed.vertical,
		},
		widget = wibox.container.margin,
		margins = 15,
	})

	awesome.connect_signal("toggle::recorder", function()
		if recorder.visible then
			slide_end:again()
			slide:set(0 - recorder.height)
		elseif not recorder.visible then
			slide:set(beautiful.height / 2 - recorder.height / 2)
			recorder.visible = true
		end
		awful.placement.centered(recorder)
	end)
	awesome.connect_signal("close::recorder", function()
		close()
	end)
end)
