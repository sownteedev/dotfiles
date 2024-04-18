local autocmd = vim.api.nvim_create_autocmd
autocmd({ "BufWritePre" }, {
	callback = function()
		for _, client in ipairs(vim.lsp.get_active_clients()) do
			if client.attached_buffers[vim.api.nvim_get_current_buf()] then
				vim.lsp.buf.format()
				return
			else
				return
			end
		end
	end,
})

-- autocmd("VimEnter", {
-- 	command = ":silent !sed -i '27,30 { s/x = .*/x = 0/g; s/y = .*/y = 0/g; }' .config/alacritty/alacritty.toml",
-- })
-- autocmd("VimLeavePre", {
-- 	command = ":silent !sed -i '27,30 { s/x = .*/x = 40/g; s/y = .*/y = 40/g; }' .config/alacritty/alacritty.toml",
-- })
