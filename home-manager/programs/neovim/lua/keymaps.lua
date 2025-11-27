local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set
local utils = require("utils")

-- @keymap <Space>: Set as leader key
--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)

-- ====================================================================================
-- QUICKFIX LISTS
-- ====================================================================================
-- @keymap <leader>co: Open quickfix list
keymap("n", "<leader>co", ":copen<CR>", opts)
-- @keymap <leader>cc: Close quickfix list
keymap("n", "<leader>cc", ":cclose<CR>", opts)

-- ====================================================================================
-- BUFFER AND FILE OPERATIONS
-- ====================================================================================
-- @keymap <leader><Tab>: Cycle to next buffer
keymap("n", "<leader><tab>", function()
	utils.cycle_buffer("next")
end, { noremap = true, silent = true })

-- @keymap <leader><S-Tab>: Cycle to previous buffer
keymap("n", "<leader><s-tab>", function()
	utils.cycle_buffer("prev")
end, { noremap = true, silent = true })

-- @keymap ]b: Cycle to next buffer
keymap("n", "]b", function()
	utils.cycle_buffer("next")
end, opts)

-- @keymap [b: Cycle to previous buffer
keymap("n", "[b", function()
	utils.cycle_buffer("prev")
end, opts)
-- @keymap <leader>q: Close current buffer
keymap("n", "<leader>q", ":Bdelete<CR>", opts)
-- @keymap <leader>bad: Wipe all buffers
keymap("n", "<leader>bad", ":%bwipeout!<cr>:intro<cr>", opts)
-- @keymap <leader>w: Write file
keymap("n", "<leader>w", ":write<CR>", opts)
-- @keymap <leader>r: Reload Neovim configuration
keymap("n", "<leader>r", function()
	vim.cmd("source $MYVIMRC")
end, opts)
-- @keymap ZZ: Save all buffers and quit
keymap("n", "ZZ", ":wa<CR>:q<CR>", opts)

-- ====================================================================================
-- TERMINAL
-- ====================================================================================
-- @keymap <leader>j: Toggle terminal (show/hide)
keymap("n", "<leader>j", "<cmd>ToggleTerm<cr>", opts)

-- ====================================================================================
-- NAVIGATION
-- ====================================================================================
-- @keymap n: Next search result and center screen
keymap("n", "n", "nzzzv", opts)
-- @keymap N: Previous search result and center screen
keymap("n", "N", "Nzzzv", opts)
-- @keymap <C-u>: Scroll up and center screen
keymap("n", "<C-u>", "<C-u>zz", opts)
-- @keymap <C-d>: Scroll down and center screen
keymap("n", "<C-d>", "<C-d>zz", opts)
-- @keymap <C-o>: Jump to older position and center screen
keymap("n", "<C-o>", "<C-o>zz", opts)
-- @keymap <C-i>: Jump to newer position and center screen
keymap("n", "<C-i>", "<C-i>zz", opts)

-- ====================================================================================
-- CLIPBOARD OPERATIONS
-- ====================================================================================
-- @keymap <leader>y: Yank to system clipboard
keymap({ "n", "v" }, "<leader>y", '"+y', opts)

-- @keymap <leader>py: Copy current file path to clipboard
keymap("n", "<leader>py", ':let @" = expand("%:p")<CR>', opts)

-- @keymap <leader>d: Delete to blackhole register
keymap({ "n", "v" }, "<leader>d", '"_d', opts)

-- ====================================================================================
-- GIT OPERATIONS
-- ====================================================================================
-- @keymap <leader>gs: Open Git status in new tab
keymap("n", "<leader>gs", ":tab Git<cr>", opts)
-- @keymap <F9>: Open Git mergetool in new tab
keymap("n", "<F9>", ":tab Git mergetool<cr>", opts)
-- @keymap <leader>gd: Preview hunk inline
keymap("n", "<leader>gd", ":Gitsign preview_hunk_inline<cr>", opts)

-- ====================================================================================
-- VISUAL MODE OPERATIONS
-- ====================================================================================
-- @keymap <: Decrease indent (visual mode)
keymap("v", "<", "<gv", opts)
-- @keymap >: Increase indent (visual mode)
keymap("v", ">", ">gv", opts)

-- @keymap p: Paste without replacing clipboard (visual mode)
keymap("v", "p", '"_dP', opts)

-- @keymap K: Move selected text up (visual mode)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
-- @keymap J: Move selected text down (visual mode)
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)

-- ====================================================================================
-- INSERT MODE OPERATIONS
-- ====================================================================================
-- @keymap -/_/,/./;/:/!/?: Add undo breakpoints after punctuation
for _, lhs in ipairs({ "-", "_", ",", ".", ";", ":", "/", "!", "?" }) do
	keymap("i", lhs, lhs .. "<c-g>u", opts)
end

-- @keymap jj: Exit insert mode
keymap("i", "jj", "<Esc>", opts)

-- ====================================================================================
-- DIAGNOSTICS
-- ====================================================================================
-- @keymap <leader>xx: Open diagnostics in quickfix
keymap("n", "<leader>xx", vim.diagnostic.setqflist, opts)
-- @keymap ]d: Go to next diagnostic
keymap("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
-- @keymap [d: Go to previous diagnostic
keymap("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous Diagnostic" })
-- @keymap <leader>dl: Show line diagnostics
keymap("n", "<leader>dl", vim.diagnostic.open_float, { desc = "Line Diagnostics" })

-- ====================================================================================
-- CODE NAVIGATION
-- ====================================================================================
-- @keymap <leader>oo: Navigate to related file (other.nvim)
keymap("n", "<leader>oo", ":Other<cr>", opts)
-- @keymap <leader>ov: Navigate to related file in vertical split
keymap("n", "<leader>ov", ":OtherVSplit<cr>", opts)
-- @keymap <leader>os: Navigate to related file in horizontal split
keymap("n", "<leader>os", ":OtherSplit<cr>", opts)

-- @keymap gco: Generate code annotation (neogen)
keymap("n", "gco", ":Neogen<cr>", opts)

-- @keymap <leader>st: Toggle treesitter split/join
require("treesj").setup({ use_default_keymaps = false })
keymap("n", "<leader>st", require("treesj").toggle, opts)

-- ====================================================================================
-- NvimTree
-- ====================================================================================
-- @keymap <leader>b: Toggle file tree (nvim-tree)
keymap("n", "<leader>b", ":NvimTreeToggle<CR>", opts)
