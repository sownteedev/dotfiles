local overrides = require("custom.configs.overrides")

local plugins = {
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
		event = "BufWritePre",
		config = function()
			require("custom.configs.conform")
		end,
	}
}

return plugins
