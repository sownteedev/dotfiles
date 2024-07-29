-- add your keymaps in here
local opts = { noremap = true, silent = true }
local map = vim.keymap.set

map(
	{ "n", "v" },
	"<Leader><TAB>",
	"<cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown{previewer = false, no_ignore=true, follow=true, hidden=true})<cr>",
	opts,
	{ desc = "Find Files Quick" }
)

vim.cmd([[imap <silent><script><expr> <C-a> copilot#Accept("\<CR>")]])
