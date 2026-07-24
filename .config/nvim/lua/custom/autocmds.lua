local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local function reload_matugen_theme()
	local matugen_theme_path = vim.fn.stdpath("config") .. "/lua/custom/themes/schemes/matugen.lua"
	local use_matugen = vim.fn.filereadable(matugen_theme_path) == 1 and vim.fn.getfsize(matugen_theme_path) > 0

	vim.g.TeVimTheme = use_matugen and "matugen" or (vim.g.TeVimThemeSource or "yoru")

	if vim.g.loadTeVimTheme then
		require("tevim.themes").load()
	end
end

autocmd("Signal", {
	group = augroup("matugen_theme_reload", { clear = true }),
	pattern = "SIGUSR1",
	callback = reload_matugen_theme,
	desc = "Reload TeVim theme after matugen updates the generated palette",
})

--autocmd({ "BufWritePre" }, {
--	callback = function()
--		for _, client in ipairs(vim.lsp.get_active_clients()) do
--			if client.attached_buffers[vim.api.nvim_get_current_buf()] then
--				vim.lsp.buf.format()
--				return
--			else
--				return
--			end
--		end
--	end,
--})
