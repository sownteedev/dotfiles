local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")

local M = {}

local function get_path()
	local string = "~/Pictures/Screenshots/" .. os.date("%d-%m-%Y-%H:%M:%S") .. ".png"
	---@diagnostic disable-next-line: param-type-mismatch
	string = string:gsub("~", os.getenv("HOME"))
	return string
end

local checkFolder = function()
	if not os.rename(os.getenv("HOME") .. "/Pictures/Screenshots/", os.getenv("HOME") .. "/Pictures/Screenshots") then
		os.execute("mkdir -p " .. os.getenv("HOME") .. "/Pictures/Screenshots")
	end
end

function M.do_notify(tmp_path)
	local copy = naughty.action({ name = "Copy" })
	local delete = naughty.action({ name = "Delete" })

	copy:connect_signal("invoked", function()
		awful.spawn.easy_async_with_shell('xclip -sel clip -target image/png "' .. tmp_path .. '" &')
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
			copy,
			delete,
		},
	})
end

local function with_defaults(given_opts)
	return { notify = given_opts == nil and false or given_opts.notify }
end

function M.full(opts)
	checkFolder()
	local tmp_path = get_path()
	gears.timer({
		timeout = 1.25,
		call_now = false,
		autostart = true,
		single_shot = true,
		callback = function()
			awful.spawn.easy_async_with_shell('maim "' .. tmp_path .. '" &', function()
				awesome.emit_signal("screenshot::done")
				if with_defaults(opts).notify then
					M.do_notify(tmp_path)
				end
			end)
		end,
	})
end

function M.area(opts)
	checkFolder()
	local tmp_path = get_path()
	awful.spawn.easy_async_with_shell('sleep 1.25 && maim --select "' .. tmp_path .. '" &', function()
		awesome.emit_signal("screenshot::done")
		if with_defaults(opts).notify then
			M.do_notify(tmp_path)
		end
	end)
end

function M.window(opts)
	checkFolder()
	local tmp_path = get_path()
	awful.spawn.easy_async_with_shell('maim --window=$(xdotool getactivewindow) "' .. tmp_path .. '" &', function()
		awesome.emit_signal("screenshot::done")
		if with_defaults(opts).notify then
			M.do_notify(tmp_path)
		end
	end)
end

function M.with_options(opts)
	opts = {
		type = opts.type ~= nil and opts.type or "full",
		timeout = opts.timeout ~= nil and opts.timeout or 0,
		notify = opts.notify ~= nil and opts.notify or false,
	}

	local function core()
		if opts.type == "full" then
			M.full({ notify = opts.notify })
		elseif opts.type == "area" then
			M.area({ notify = opts.notify })
		elseif opts.type == "window" then
			M.window({ notify = opts.notify })
		else
			error(
				"Invalid `opts.type` in `screenshot.with_options` ("
				.. opts.type
				.. "), valid ones are: full, area and window"
			)
		end
	end
	if opts.timeout <= 0 then
		return core()
	end
	gears.timer({
		timeout = opts.timeout,
		call_now = false,
		autostart = true,
		single_shot = true,
		callback = core,
	})
end

return M
