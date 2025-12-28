local on_attach = require("tevim.plugins.configs.lspconfig").on_attach
local capabilities = require("tevim.plugins.configs.lspconfig").capabilities

local servers = { "clangd", "cssls", "html", "jsonls", "bashls", "emmet_ls", "eslint" }

for _, lsp in ipairs(servers) do
	vim.lsp.config(lsp, {
		on_attach = on_attach,
		capabilities = capabilities,
	})
end

vim.lsp.config("lua_ls", {
	on_attach = on_attach,
	capabilities = capabilities,
	settings = {
		Lua = {
			hint = { enable = true },
			diagnostics = { globals = { "vim", "awesome", "client", "screen", "mouse", "tag" } },
			workspace = { checkThirdParty = false },
		},
	},
})

vim.lsp.config("ts_ls", {
	on_attach = on_attach,
	capabilities = capabilities,
	completions = {
		completeFunctionCalls = true,
	},
	settings = {
		javascript = {
			inlayHints = {
				includeInlayEnumMemberValueHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayVariableTypeHints = false,
			},
		},
		typescript = {
			inlayHints = {
				includeInlayEnumMemberValueHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayVariableTypeHints = false,
			},
		},
	},
})
