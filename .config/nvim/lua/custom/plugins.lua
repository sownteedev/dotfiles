local overrides = require("custom.configs.overrides")

return {
	-- {
	-- 	"github/copilot.vim",
	-- 	lazy = false,
	-- },
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
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"dharmx/telescope-media.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		},
		opts = {
			extensions_list = { "fzf", "terms", "nerdy", "media" },
			extensions = {
				media = {
					backend = "ueberzug",
				},
			},
		},
	},
}
