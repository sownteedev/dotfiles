local overrides = require("custom.configs.overrides")

return {
	{
		"github/copilot.vim",
	},
	{
		"williamboman/mason.nvim",
		opts = overrides.mason,
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			require("tevim.plugins.lsp.lspconfig")
			require("custom.configs.lspconfig")
		end,
	},
	{
		"stevearc/conform.nvim",
		lazy = true,
		event = "BufWritePre",
		config = function()
			require("custom.configs.conform")
		end,
	},
	{
		"Exafunction/codeium.nvim",
		lazy = true,
		event = "InsertEnter",
		config = function()
			require("codeium").setup({})
		end,
	},
	{
		"iamcco/markdown-preview.nvim",
		lazy = true,
		ft = "markdown",
		build = ":call mkdp#util#install()",
	},
}
