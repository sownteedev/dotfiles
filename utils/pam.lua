local cache = os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")
local loader, message = package.loadlib(cache .. "/awesome/lua51/liblua_pam.so", "luaopen_liblua_pam")
assert(loader, "Build the LuaJIT PAM module with scripts/build-pam.sh: " .. tostring(message))
return loader()
