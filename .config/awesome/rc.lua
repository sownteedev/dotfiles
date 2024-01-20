pcall(require, "luarocks.loader")
require("awful.autofocus")
local gears = require("gears")
local beautiful = require("beautiful")

beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/theme.lua")
require("themes.toggle")

require("config")
require("signals")
require("ui")
