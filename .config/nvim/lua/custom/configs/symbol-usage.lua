local SymbolKind = vim.lsp.protocol.SymbolKind

require('symbol-usage').setup({
	kinds = { SymbolKind.Function, SymbolKind.Method },
	kinds_filter = {},
	vt_position = 'above',
	request_pending_text = 'loading...',
	references = { enabled = true, include_declaration = true },
	definition = { enabled = true },
	implementation = { enabled = true },
	disable = { lsp = {}, filetypes = {}, cond = {} },
	symbol_request_pos = 'end',
})
