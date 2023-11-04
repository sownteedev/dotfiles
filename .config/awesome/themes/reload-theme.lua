local awful     = require("awful")
local file      = io.open(os.getenv("HOME") .. '/.theme', 'r')
local RICETHEME = file:read('*line')
file:close()

local function reload_theme()
	local reload = "python " .. "~/.config/scripts/reload_nvim.py"
	local reload_cmd = reload .. " 'lua require(\"themes.switch\").settheme(\"" .. RICETHEME .. "\")'"
	awful.spawn.easy_async_with_shell(reload_cmd, function() end)
	local newlines = {}
	local found    = false
	for line in io.lines(os.getenv("HOME") .. '/.config/nvim/lua/user/options.lua') do
		if line:find("vim.g.currentTheme = ") then
			line = "vim.g.currentTheme = \"" .. RICETHEME .. "\""
			found = true
		end
		table.insert(newlines, line)
	end
	if not found then
		table.insert(newlines, "vim.g.currentTheme = \"" .. RICETHEME .. "\"")
	end
	local file = io.open(os.getenv("HOME") .. '/.config/nvim/lua/user/options.lua', 'w')
	for _, line in ipairs(newlines) do
		file:write(line .. "\n")
	end
	file:close()
end

reload_theme()
