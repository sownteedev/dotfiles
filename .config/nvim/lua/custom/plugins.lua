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
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		config = function()
			require("custom.configs.conform")
		end,
	},
	{
		"Exafunction/codeium.nvim",
		event = "InsertEnter",
		config = function()
			require("codeium").setup({})
		end,
	},
	{
		"codota/tabnine-nvim",
		lazy = false,
		build = "./dl_binaries.sh",
		config = function()
			require("tabnine").setup()
		end,
	},
	{
		"iamcco/markdown-preview.nvim",
		ft = "markdown",
		build = ":call mkdp#util#install()",
	},
}
