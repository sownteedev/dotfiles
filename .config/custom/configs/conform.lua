require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		javascript = { "prettier" },
		javascriptreact = { "prettier" },
		typescript = { "prettier" },
		typescriptreact = { "prettier" },
		html = { "prettier" },
		css = { "prettier" },
		json = { "prettier" },
		sh = { "shfmt" },
		c = { "clang-format" },
		cpp = { "clang-format" },
	},
	format_on_save = {
		timeout_ms = 500,
		lsp_fallback = true,
	},
})
