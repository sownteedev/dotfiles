local M = {}
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
		"sleep 1.25 && ffmpeg -y -f x11grab "
		.. "-r %s -i %s -f pulse -i 59 -c:v libx264 -qp 0 -profile:v main "
		.. "-preset ultrafast -tune zerolatency -crf 28 -pix_fmt yuv420p "
		.. "-c:a aac -b:a 64k -b:v 500k %s &",
		fps,
		display,
		file_name
	)
	print(defCommand)
	awful.spawn.easy_async_with_shell(defCommand)
end

local rec_audio = function(fps, file_name)
	local display = os.getenv("DISPLAY")
	local defCommand = string.format(
		"sleep 1.25 && ffmpeg -y -f x11grab "
		.. "-r %s -i %s -f pulse -i 57 -c:v libx264 -qp 0 -profile:v main "
		.. "-preset ultrafast -tune zerolatency -crf 28 -pix_fmt yuv420p "
		.. "-c:a aac -b:a 64k -b:v 500k %s &",
		fps,
		display,
		file_name
	)
	print(defCommand)
	awful.spawn.easy_async_with_shell(defCommand)
end

local createButton = function(path, name, fn, col)
	local button = wibox.widget({
		{
			{
				{
					{
						image = path,
						forced_width = 50,
						forced_height = 50,
						resize = true,
						widget = wibox.widget.imagebox,
						halign = "center",
					},
					{
						font = beautiful.sans .. " 15",
						markup = name,
						align = "center",
						widget = wibox.widget.textbox,
					},
					layout = wibox.layout.fixed.vertical,
					spacing = 20,
				},
				widget = wibox.container.margin,
				margins = 15,
			},
			{
				forced_height = 10,
				forced_width = 130,
				bg = col,
				widget = wibox.container.background,
			},
			layout = wibox.layout.fixed.vertical,
		},
		forced_width = 130,
		bg = beautiful.lighter,
		shape_border_width = beautiful.border_width_custom,
		shape_border_color = beautiful.border_color,
		shape = helpers.rrect(5),
		id = "bg",
		widget = wibox.container.background,
		buttons = awful.button({}, 1, function()
			fn()
		end),
	})
	helpers.addHover(button, "bg", beautiful.lighter, helpers.blend(col, beautiful.background, 0.1))
	return button
end

local recorder = wibox({
	width = 450,
	height = 230,
	bg = beautiful.background,
	shape = helpers.rrect(5),
	ontop = true,
	visible = false,
})
local slide = animation:new({
	duration = 1,
	pos = 0 - recorder.height,
	easing = animation.easing.inOutExpo,
	update = function(_, pos)
		recorder.y = pos
	end,
})

local slide_end = gears.timer({
	single_shot = true,
	timeout = 1,
	callback = function()
		recorder.visible = false
	end,
})

local recaudio = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/record/recaudio.png",
	"Rec Audio",
	function()
		M.close()
		checkFolder()
		local name = getName()
		rec_audio("60", name)
	end,
	beautiful.green
)

local recmic = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/record/recmic.png",
	"Rec Mic",
	function()
		M.close()
		checkFolder()
		local name = getName()
		rec_mic("60", name)
	end,
	beautiful.blue
)

local stop = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/record/finish.png",
	"Finish",
	function()
		awful.spawn.easy_async_with_shell("killall ffmpeg &")
		M.close()
	end,
	beautiful.red
)

recorder:setup({
	{
		{
			{
				{
					{
						font = beautiful.sans .. " Bold 15",
						markup = "Video Recorder",
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
			shape_border_width = beautiful.border_width_custom,
			shape_border_color = beautiful.border_color,
			shape = helpers.rrect(5),
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

function M.close()
	slide_end:again()
	slide:set(0 - recorder.height)
end

function M.toggle()
	if recorder.visible then
		slide_end:again()
		slide:set(0 - recorder.height)
	elseif not recorder.visible then
		slide:set(beautiful.height / 2 - recorder.height / 2)
		recorder.visible = true
	end
	awful.placement.centered(recorder)
end

return M
