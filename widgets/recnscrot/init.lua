local wibox = require("wibox")
local helpers = require("helpers")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local animation = require("modules.animation")
local general = require(... .. ".mods")

local M = {}

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
	helpers.addHoverBg(button, "bg", beautiful.lighter, helpers.blend(col, beautiful.background, 0.1))
	return button
end

local recorder = wibox({
	width = 450,
	height = 230,
	bg = beautiful.background,
	shape = helpers.rrect(10),
	ontop = true,
	visible = false,
})

local recaudio = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/record/recaudio.png",
	"Rec Audio",
	function()
		M.closeRecord()
		general.rec_audio()
	end,
	beautiful.green
)

local recmic = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/record/recmic.png",
	"Rec Mic",
	function()
		M.closeRecord()
		general.rec_mic()
	end,
	beautiful.blue
)

local stop = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/record/finish.png",
	"Finish",
	function()
		awful.spawn.easy_async_with_shell("killall ffmpeg &")
		M.closeRecord()
	end,
	beautiful.red
)

local fullscreen = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/screenshot/fullscreen.png",
	"Fullscreen",
	function()
		M.closeScrot()
		general.full({ notify = true })
	end,
	beautiful.green
)

local selection = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/screenshot/selection.png",
	"Selection",
	function()
		M.closeScrot()
		general.area({ notify = true })
	end,
	beautiful.blue
)

local window = createButton(
	gears.filesystem.get_configuration_dir() .. "/themes/assets/screenshot/window.png",
	"Window",
	function()
		M.closeScrot()
		general.window({ notify = true })
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
			shape = helpers.rrect(10),
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

local scrotter = wibox({
	width = 450,
	height = 230,
	shape = helpers.rrect(10),
	bg = beautiful.background,
	ontop = true,
	visible = false,
})

scrotter:setup({
	{
		{
			{
				{
					font = beautiful.sans .. " Bold 15",
					markup = "Screenshotter",
					align = "start",
					widget = wibox.widget.textbox,
				},
				widget = wibox.container.margin,
				margins = 15,
			},
			widget = wibox.container.background,
			bg = beautiful.lighter,
			shape_border_width = beautiful.border_width_custom,
			shape_border_color = beautiful.border_color,
			shape = helpers.rrect(10),
		},
		{
			fullscreen,
			selection,
			window,
			spacing = 15,
			layout = wibox.layout.fixed.horizontal,
		},
		spacing = 15,
		layout = wibox.layout.fixed.vertical,
	},
	widget = wibox.container.margin,
	margins = 15,
})

local slideSc = animation:new({
	duration = 1,
	pos = 0 - scrotter.height,
	easing = animation.easing.inOutExpo,
	update = function(_, pos)
		scrotter.y = pos
	end,
})
local slide_end_sc = gears.timer({
	timeout = 1,
	single_shot = true,
	callback = function()
		scrotter.visible = false
	end,
})

local slideRc = animation:new({
	duration = 1,
	pos = 0 - recorder.height,
	easing = animation.easing.inOutExpo,
	update = function(_, pos)
		recorder.y = pos
	end,
})
local slide_end_rc = gears.timer({
	timeout = 1,
	single_shot = true,
	callback = function()
		recorder.visible = false
	end,
})

function M.closeRecord()
	slide_end_rc:again()
	slideRc:set(0 - recorder.height)
end

function M.toggleRecord()
	if recorder.visible then
		slide_end_rc:again()
		slideRc:set(0 - recorder.height)
	elseif not recorder.visible then
		slideRc:set(beautiful.height / 2 - recorder.height / 2)
		recorder.visible = true
	end
	awful.placement.centered(recorder)
end

function M.closeScrot()
	slide_end_sc:again()
	slideSc:set(0 - scrotter.height)
end

function M.toggleScrot()
	if scrotter.visible then
		slide_end_sc:again()
		slideSc:set(0 - scrotter.height)
	elseif not scrotter.visible then
		slideSc:set(beautiful.height / 2 - scrotter.height / 2)
		scrotter.visible = true
	end
	awful.placement.centered(scrotter)
end

return M
