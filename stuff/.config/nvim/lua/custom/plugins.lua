local overrides = require("custom.configs.overrides")

return {
	{
		"github/copilot.vim",
		lazy = false,
	},
	{
		"williamboman/mason.nvim",
		opts = overrides.mason,
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			require("tevim.plugins.configs.lspconfig")
			require("custom.configs.lspconfig")
		end,
	},
	-- {
	-- 	"stevearc/conform.nvim",
	-- 	event = "BufWritePre",
	-- 	config = function()
	-- 		require("custom.configs.conform")
	-- 	end,
	-- },
	{
		"Exafunction/codeium.nvim",
		event = "InsertEnter",
		config = function()
			require("codeium").setup({})
		end,
	},
	{
		"iamcco/markdown-preview.nvim",
		ft = "markdown",
		build = ":call mkdp#util#install()",
	},
	{
		"folke/which-key.nvim",
		opts = overrides.whichkey,
	},
	{
		'Wansmer/symbol-usage.nvim',
		event = 'LspAttach',
		config = function()
			require("custom.configs.symbol-usage")
		end
	},
	-- {
	-- 	"kevinhwang91/nvim-ufo",
	-- 	event = { "BufReadPost", "BufNewFile" },
	-- 	dependencies = "kevinhwang91/promise-async",
	-- 	init = function()
	-- 		vim.o.foldcolumn = "1"
	-- 		vim.o.foldlevel = 99
	-- 		vim.o.foldlevelstart = 99
	-- 		vim.o.foldenable = true
	-- 	end,
	-- 	config = function()
	-- 		require("ufo").setup({
	-- 			provider_selector = function()
	-- 				return { "treesitter", "indent" }
	-- 			end,
	-- 		})
	-- 	end,
	-- },
}
