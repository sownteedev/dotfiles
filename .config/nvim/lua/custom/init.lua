require("custom.options")
require("custom.keymaps")
require("custom.autocmds")

if vim.g.neovide then
    vim.o.guifont = "SF Mono:h11"
	vim.opt.linespace = 8

    vim.g.neovide_scale_factor = 1.0

    vim.g.neovide_padding_top = 20
    vim.g.neovide_padding_bottom = 20
    vim.g.neovide_padding_right = 40
    vim.g.neovide_padding_left = 40

    vim.g.neovide_scroll_animation_length = 0.3

    vim.g.neovide_cursor_animation_length = 0.13

    -- "railgun", "torpedo", "pixie", "wireframe"
    vim.g.neovide_cursor_vfx_mode = "pixiedust"

    vim.g.neovide_cursor_vfx_particle_density = 15.0
	vim.g.neovide_cursor_animate_in_insert_mode = true
end
