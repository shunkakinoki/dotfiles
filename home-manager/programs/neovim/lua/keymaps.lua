local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set
local utils = require("utils")

-- Enhanced navigation with label-based motion jump targets.
-- From: https://github.com/folke/flash.nvim
local flash = require("flash")

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
-- @keymap <leader>u: Spawn a new managed terminal
keymap({ "n", "t" }, "<leader>u", function()
	SpawnTerminal()
end, opts)
-- @keymap <leader>h: Close the current managed terminal
keymap({ "n", "t" }, "<leader>h", function()
	KillCurrentTerminal()
end, opts)
-- @keymap <leader>j: Toggle the focused managed terminal
keymap({ "n", "t" }, "<leader>j", function()
	ToggleTerminal()
end, opts)
-- @keymap <leader><S-]>: Jump to next managed terminal
keymap({ "n", "t" }, "<leader><S-]>", function()
	CycleNextTerm()
end, opts)
-- @keymap <leader><S-[>: Jump to previous managed terminal
keymap({ "n", "t" }, "<leader><S-[>", function()
	CyclePreviousTerm()
end, opts)

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

-- @keymap s: Flash jump
keymap({ "n", "x", "o" }, "s", function()
	flash.jump()
end, opts)

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
keymap("n", "<leader>gd", ":Gitsigns preview_hunk_inline<cr>", opts)
-- @keymap <leader>hs: Stage hunk (Gitsigns)
keymap("n", "<leader>hs", ":Gitsigns stage_hunk<cr>", opts)
-- @keymap <leader>hr: Reset hunk (Gitsigns)
keymap("n", "<leader>hr", ":Gitsigns reset_hunk<cr>", opts)
-- @keymap <leader>hp: Preview hunk (Gitsigns)
keymap("n", "<leader>hp", ":Gitsigns preview_hunk<cr>", opts)
-- @keymap <leader>hb: Blame line (Gitsigns)
keymap("n", "<leader>hb", ":Gitsigns blame_line<cr>", opts)

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
-- @keymap <leader>xx: Open diagnostics (Trouble)
keymap("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", opts)
-- @keymap <leader>xX: Toggle Trouble
keymap("n", "<leader>xX", "<cmd>Trouble toggle<cr>", opts)
-- @keymap <leader>cs: Open symbols (Trouble)
keymap("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", opts)
-- @keymap <leader>cl: Open LSP references/defs (Trouble)
keymap("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", opts)
-- @keymap <leader>xq: Open quickfix (Trouble)
keymap("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", opts)
-- @keymap <leader>xl: Open loclist (Trouble)
keymap("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", opts)
-- @keymap ]d: Go to next diagnostic
keymap("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
-- @keymap [d: Go to previous diagnostic
keymap("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous Diagnostic" })
-- @keymap <leader>dl: Show line diagnostics
keymap("n", "<leader>dl", vim.diagnostic.open_float, { desc = "Line Diagnostics" })

-- ====================================================================================
-- CODE NAVIGATION & EDITING
-- ====================================================================================
-- @keymap -: Open parent directory (Oil)
keymap("n", "-", "<CMD>Oil<CR>", { desc = "Open Parent Directory" })

-- @keymap <leader>S: Open Search/Replace (GrugFar)
keymap("n", "<leader>S", ":GrugFar<cr>", opts)

-- @keymap <leader>oo: Navigate to related file (other.nvim)
keymap("n", "<leader>oo", ":Other<cr>", opts)
-- @keymap <leader>ov: Navigate to related file in vertical split
keymap("n", "<leader>ov", ":OtherVSplit<cr>", opts)
-- @keymap <leader>os: Navigate to related file in horizontal split
keymap("n", "<leader>os", ":OtherSplit<cr>", opts)

-- @keymap gco: Generate code annotation (neogen)
keymap("n", "gco", ":Neogen<cr>", opts)

-- @keymap <leader>st: Toggle treesitter split/join
-- Treesitter-based split/join helper for code structures.
-- From: https://github.com/wansmer/treesj
local treesj = require("treesj")
treesj.setup({ use_default_keymaps = false })
keymap("n", "<leader>st", treesj.toggle, opts)

-- ====================================================================================
-- NVIMTREE
-- ====================================================================================
-- @keymap <leader>b: Toggle file tree (nvim-tree)
keymap("n", "<leader>b", ":NvimTreeToggle<CR>", opts)

-- @keymap <leader>sk: Toggle Sidekick CLI (per docs)
keymap("n", "<leader>sk", ":Sidekick cli toggle<CR>", opts)

-- ====================================================================================
-- SIDEKICK
-- ====================================================================================
-- @keymap <tab> (insert): jump/apply Sidekick NES or insert literal <Tab>
local function nes_tab_fallback()
 	if not require("sidekick").nes_jump_or_apply() then
 		return "<Tab>"
	end
end
keymap("i", "<tab>", nes_tab_fallback, { expr = true, desc = "Sidekick NES jump/apply" })
-- @keymap <c-.>: Toggle Sidekick CLI in any mode
keymap({ "n", "t", "i", "x" }, "<c-.>", function()
	require("sidekick.cli").toggle()
end, { desc = "Sidekick Toggle" })
-- @keymap <leader>aa: Toggle Sidekick CLI window (alternate)
keymap("n", "<leader>aa", function()
	require("sidekick.cli").toggle()
end, opts)
-- @keymap <leader>as: Select a CLI tool
keymap("n", "<leader>as", function()
	require("sidekick.cli").select()
end, opts)
-- @keymap <leader>ad: Close detached CLI
keymap("n", "<leader>ad", function()
	require("sidekick.cli").close()
end, opts)
-- @keymap <leader>at: Send current context, per docs
keymap({ "n", "x" }, "<leader>at", function()
	require("sidekick.cli").send({ msg = "{this}" })
end, opts)
-- @keymap <leader>af: Send entire buffer
keymap("n", "<leader>af", function()
	require("sidekick.cli").send({ msg = "{file}" })
end, opts)
-- @keymap <leader>av: Send selection
keymap("x", "<leader>av", function()
	require("sidekick.cli").send({ msg = "{selection}" })
end, opts)
-- @keymap <leader>ap: Open Sidekick prompt/command picker
keymap({ "n", "x" }, "<leader>ap", function()
	require("sidekick.cli").prompt()
end, opts)
-- @keymap <leader>ac: Toggle Claude session and focus it
keymap("n", "<leader>ac", function()
	require("sidekick.cli").toggle({ name = "claude", focus = true })
end, opts)

-- ====================================================================================
-- WHICH-KEY GROUPS
-- ====================================================================================
-- Popup helper that groups and hints keybindings as you start a mapping.
-- From: https://github.com/folke/which-key.nvim
local wk = require("which-key")
wk.add({
	{ "<leader>g", group = "Git" },
	{ "<leader>l", group = "LSP" },
	{ "<leader>f", group = "Find/Telescope" },
	{ "<leader>x", group = "Trouble/Diagnostics" },
	{ "<leader>c", group = "Code" },
	{ "<leader>h", group = "Hunk (Git)" },
})
