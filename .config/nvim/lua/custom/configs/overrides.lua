local M = {}

M.mason = {
	ensure_installed = {
		"html-lsp",
		"css-lsp",
		"json-lsp",
		"typescript-language-server",
		"clangd",
		"clang-format",
		"prettier",
		"emmet-ls",
		"eslint_d",
		"eslint-lsp",
	},
}

M.whichkey = {
	setup = { triggers = { "<leader>" } },
}

return M
