#!/usr/bin/env bash
set -euo pipefail

build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/awesome/lua51"
revision=373de20d6784f77d59abc1ffc1d0302f28ed46cd
mkdir -p "$build_dir"
curl --fail --location --proto '=https' --tlsv1.2 \
    "https://raw.githubusercontent.com/RMTT/lua-pam/$revision/src/main.cpp" \
    -o "$build_dir/main.cpp"
printf '%s  %s\n' 72836e78a6a6104df28fb7539c1f0da6ea877796d8ec4cdd3f8fee75dd7d9eea \
    "$build_dir/main.cpp" | sha256sum --check
read -r -a lua_cflags <<< "$(pkg-config --cflags luajit)"
read -r -a lua_libs <<< "$(pkg-config --libs luajit)"
c++ -std=c++14 -shared -fPIC -O2 "${lua_cflags[@]}" \
    "$build_dir/main.cpp" -o "$build_dir/liblua_pam.so.new" "${lua_libs[@]}" -lpam
AWESOME_PAM_MODULE="$build_dir/liblua_pam.so.new" luajit -e 'local loader = assert(package.loadlib(os.getenv("AWESOME_PAM_MODULE"), "luaopen_liblua_pam")); assert(type(loader().auth_current_user) == "function")'
mv "$build_dir/liblua_pam.so.new" "$build_dir/liblua_pam.so"
printf 'Built LuaJIT PAM module: %s\n' "$build_dir/liblua_pam.so"
