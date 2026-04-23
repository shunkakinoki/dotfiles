local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set
local utils = require("config.utils")

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
keymap("n", "<leader>co", ":copen<CR>", { noremap = true, silent = true, desc = "Open quickfix list" })
-- @keymap <leader>cc: Close quickfix list
keymap("n", "<leader>cc", ":cclose<CR>", { noremap = true, silent = true, desc = "Close quickfix list" })

-- ====================================================================================
-- BUFFER AND FILE OPERATIONS
-- ====================================================================================
-- @keymap <leader><Tab>: Cycle to next buffer
keymap("n", "<leader><tab>", function()
	utils.cycle_buffer("next")
end, { noremap = true, silent = true, desc = "Next buffer" })

-- @keymap <leader><S-Tab>: Cycle to previous buffer
keymap("n", "<leader><s-tab>", function()
	utils.cycle_buffer("prev")
end, { noremap = true, silent = true, desc = "Previous buffer" })

-- @keymap ]b: Cycle to next buffer
keymap("n", "]b", function()
	utils.cycle_buffer("next")
end, { noremap = true, silent = true, desc = "Next buffer" })

-- @keymap [b: Cycle to previous buffer
keymap("n", "[b", function()
	utils.cycle_buffer("prev")
end, { noremap = true, silent = true, desc = "Previous buffer" })
-- @keymap <leader>q: Close current window/split, or delete buffer if last window
keymap("n", "<leader>q", function()
	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		vim.cmd("close")
	else
		vim.cmd("Bdelete")
	end
end, { noremap = true, silent = true, desc = "Close window / delete buffer" })
-- @keymap <leader>BD: Wipe all buffers
keymap("n", "<leader>BD", ":%bwipeout!<cr>:intro<cr>", { noremap = true, silent = true, desc = "Wipe all buffers" })
-- @keymap <leader>w: Write file
keymap("n", "<leader>w", ":write<CR>", { noremap = true, silent = true, desc = "Save file" })
-- @keymap <leader>W: Save all and quit
keymap("n", "<leader>W", ":wall | qall<CR>", { noremap = true, silent = true, desc = "Save all and quit" })
-- @keymap <leader>r: Reload Neovim configuration
keymap("n", "<leader>r", function()
	vim.cmd("source $MYVIMRC")
end, { noremap = true, silent = true, desc = "Reload config" })
-- @keymap <leader>R: Full reload of all nvim config files
keymap("n", "<leader>R", function()
	for name, _ in pairs(package.loaded) do
		if name:match("^config%.") then
			package.loaded[name] = nil
		end
	end
	vim.cmd("source $MYVIMRC")
	vim.notify("Neovim config reloaded", vim.log.levels.INFO)
end, { desc = "Full reload of Neovim config" })
-- @keymap ZZ: Save all buffers and quit
keymap("n", "ZZ", ":wa<CR>:q<CR>", { noremap = true, silent = true, desc = "Save all and quit" })

-- ====================================================================================
-- TERMINAL
-- ====================================================================================
-- Keep <leader>-based terminal controls out of terminal mode itself.
-- <leader> is Space, so terminal-mode leader mappings will intercept normal prose sent to the shell.
-- @keymap <leader>u: Spawn a new managed terminal
keymap("n", "<leader>u", function()
	SpawnTerminal()
end, { noremap = true, silent = true, desc = "Spawn terminal" })
-- @keymap <leader>h: Close the current managed terminal
keymap("n", "<leader>h", function()
	KillCurrentTerminal()
end, { noremap = true, silent = true, desc = "Kill terminal" })
-- @keymap <leader>j: Toggle the focused managed terminal
keymap("n", "<leader>j", function()
	ToggleTerminal()
end, { noremap = true, silent = true, desc = "Toggle terminal" })
-- @keymap <M-u>: Spawn a new managed terminal (terminal mode)
keymap("t", "<M-u>", function()
	SpawnTerminal()
end, { noremap = true, silent = true, desc = "Spawn terminal" })
-- @keymap <M-h>: Close the current managed terminal (terminal mode)
keymap("t", "<M-h>", function()
	KillCurrentTerminal()
end, { noremap = true, silent = true, desc = "Kill terminal" })
-- @keymap <M-j>: Toggle the focused managed terminal (terminal mode)
keymap("t", "<M-j>", function()
	ToggleTerminal()
end, { noremap = true, silent = true, desc = "Toggle terminal" })
-- @keymap <M-n>: Jump to next managed terminal (terminal mode only)
keymap("t", "<M-n>", function()
	CycleNextTerm()
end, { noremap = true, silent = true, desc = "Next terminal" })
-- @keymap <M-p>: Jump to previous managed terminal (terminal mode only)
keymap("t", "<M-p>", function()
	CyclePreviousTerm()
end, { noremap = true, silent = true, desc = "Previous terminal" })

-- ====================================================================================
-- NAVIGATION
-- ====================================================================================
-- @keymap n: Next search result and center screen
keymap("n", "n", "nzzzv", { noremap = true, silent = true, desc = "Next search result" })
-- @keymap N: Previous search result and center screen
keymap("n", "N", "Nzzzv", { noremap = true, silent = true, desc = "Previous search result" })
-- @keymap <C-u>: Scroll up and center screen
keymap("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true, desc = "Scroll up" })
-- @keymap <C-d>: Scroll down and center screen
keymap("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true, desc = "Scroll down" })
-- @keymap <C-o>: Jump to older position and center screen
keymap("n", "<C-o>", "<C-o>zz", { noremap = true, silent = true, desc = "Jump back" })
-- @keymap <C-i>: Jump to newer position and center screen
keymap("n", "<C-i>", "<C-i>zz", { noremap = true, silent = true, desc = "Jump forward" })

-- @keymap s: Flash jump
keymap({ "n", "x", "o" }, "s", function()
	flash.jump()
end, { noremap = true, silent = true, desc = "Flash jump" })

-- ====================================================================================
-- CLIPBOARD OPERATIONS
-- ====================================================================================
-- @keymap <leader>y: Yank to system clipboard
keymap({ "n", "v" }, "<leader>y", '"+y', { noremap = true, silent = true, desc = "Yank to clipboard" })

-- @keymap <leader>py: Copy current file path to clipboard
keymap("n", "<leader>py", ':let @" = expand("%:p")<CR>', { noremap = true, silent = true, desc = "Copy file path" })

-- @keymap <leader>d: Delete to blackhole register
keymap({ "n", "v" }, "<leader>d", '"_d', { noremap = true, silent = true, desc = "Delete (no clipboard)" })

-- @keymap dd: Smart delete (uses blackhole register for empty lines)
-- From: https://github.com/dmtrKovalenko/dotfiles
keymap("n", "dd", function()
	return utils.smart_delete("dd")
end, { noremap = true, expr = true, desc = "Smart delete line" })

-- @keymap <Esc>: Close floating windows
keymap("n", "<Esc>", function()
	utils.close_floating_wins()
	vim.cmd("nohlsearch")
end, { noremap = true, silent = true, desc = "Close floats / clear search" })

-- ====================================================================================
-- GIT OPERATIONS
-- ====================================================================================
-- @keymap <leader>gs: Open Git status in new tab
keymap("n", "<leader>gs", ":tab Git<cr>", { noremap = true, silent = true, desc = "Git status" })
-- @keymap <F9>: Open Git mergetool in new tab
keymap("n", "<F9>", ":tab Git mergetool<cr>", { noremap = true, silent = true, desc = "Git mergetool" })
-- @keymap <leader>gg: Open LazyGit
keymap("n", "<leader>lg", ":LazyGit<cr>", { noremap = true, silent = true, desc = "LazyGit" })
-- @keymap <leader>gD: VscDiff explorer (git status browser)
keymap("n", "<leader>gD", function()
	require("vscode-diff.commands").vscode_diff({ fargs = {} })
end, { noremap = true, silent = true, desc = "Diff explorer" })
-- @keymap <leader>gH: VscDiff current file vs HEAD
keymap("n", "<leader>gH", function()
	require("vscode-diff.commands").vscode_diff({ fargs = { "file", "HEAD" } })
end, { noremap = true, silent = true, desc = "Diff file vs HEAD" })
-- @keymap <leader>gr: VscDiff current file vs prompted revision
keymap("n", "<leader>gr", function()
	vim.ui.input({ prompt = "Diff against revision: ", default = "HEAD" }, function(rev)
		if rev and rev ~= "" then
			require("vscode-diff.commands").vscode_diff({ fargs = { "file", rev } })
		end
	end)
end, { noremap = true, silent = true, desc = "Diff file vs revision" })
-- @keymap <leader>gf: VscDiff two files (prompted)
keymap("n", "<leader>gf", function()
	vim.ui.input({ prompt = "File A: ", completion = "file" }, function(a)
		if not a or a == "" then
			return
		end
		vim.ui.input({ prompt = "File B: ", completion = "file" }, function(b)
			if b and b ~= "" then
				require("vscode-diff.commands").vscode_diff({ fargs = { "file", a, b } })
			end
		end)
	end)
end, { noremap = true, silent = true, desc = "Diff two files" })
-- @keymap <leader>gd: Preview hunk inline
keymap(
	"n",
	"<leader>gd",
	":Gitsigns preview_hunk_inline<cr>",
	{ noremap = true, silent = true, desc = "Preview hunk inline" }
)
-- @keymap <leader>Hs: Stage hunk (Gitsigns)
keymap("n", "<leader>Hs", ":Gitsigns stage_hunk<cr>", { noremap = true, silent = true, desc = "Stage hunk" })
-- @keymap <leader>Hr: Reset hunk (Gitsigns)
keymap("n", "<leader>Hr", ":Gitsigns reset_hunk<cr>", { noremap = true, silent = true, desc = "Reset hunk" })
-- @keymap <leader>Hp: Preview hunk (Gitsigns)
keymap("n", "<leader>Hp", ":Gitsigns preview_hunk<cr>", { noremap = true, silent = true, desc = "Preview hunk" })
-- @keymap <leader>Hb: Blame line (Gitsigns)
keymap("n", "<leader>Hb", ":Gitsigns blame_line<cr>", { noremap = true, silent = true, desc = "Blame line" })
-- @keymap <leader>Hn: Next hunk (Gitsigns)
keymap("n", "<leader>Hn", ":Gitsigns next_hunk<cr>", { noremap = true, silent = true, desc = "Next hunk" })
-- @keymap <leader>HN: Prev hunk (Gitsigns)
keymap("n", "<leader>HN", ":Gitsigns prev_hunk<cr>", { noremap = true, silent = true, desc = "Prev hunk" })
-- @keymap <leader>gs: Fugitive vertical diff split (current file vs index)
keymap("n", "<leader>gs", ":Gvdiffsplit<cr>", { noremap = true, silent = true, desc = "Diff split (index)" })
-- @keymap <leader>gS: Fugitive diff split vs HEAD
keymap("n", "<leader>gS", ":Gvdiffsplit HEAD<cr>", { noremap = true, silent = true, desc = "Diff split vs HEAD" })

-- ====================================================================================
-- VISUAL MODE OPERATIONS
-- ====================================================================================
-- @keymap <: Decrease indent (visual mode)
keymap("v", "<", "<gv", { noremap = true, silent = true, desc = "Decrease indent" })
-- @keymap >: Increase indent (visual mode)
keymap("v", ">", ">gv", { noremap = true, silent = true, desc = "Increase indent" })

-- @keymap p: Paste without replacing clipboard (visual mode)
keymap("v", "p", '"_dP', { noremap = true, silent = true, desc = "Paste (keep clipboard)" })

-- @keymap K: Move selected text up (visual mode)
keymap("x", "K", ":move '<-2<CR>gv-gv", { noremap = true, silent = true, desc = "Move selection up" })
-- @keymap J: Move selected text down (visual mode)
keymap("x", "J", ":move '>+1<CR>gv-gv", { noremap = true, silent = true, desc = "Move selection down" })

-- ====================================================================================
-- INSERT MODE OPERATIONS
-- ====================================================================================
-- @keymap -/_/,/./;/:/!/?: Add undo breakpoints after punctuation
for _, lhs in ipairs({ "-", "_", ",", ".", ";", ":", "/", "!", "?" }) do
	keymap("i", lhs, lhs .. "<c-g>u", { noremap = true, silent = true, desc = "Undo breakpoint: " .. lhs })
end

-- @keymap jj: Exit insert mode
keymap("i", "jj", "<Esc>", { noremap = true, silent = true, desc = "Exit insert mode" })

-- ====================================================================================
-- DIAGNOSTICS
-- ====================================================================================
-- @keymap <leader>xx: Open diagnostics (Trouble)
keymap(
	"n",
	"<leader>xx",
	"<cmd>Trouble diagnostics toggle<cr>",
	{ noremap = true, silent = true, desc = "Diagnostics" }
)
-- @keymap <leader>xX: Toggle Trouble
keymap("n", "<leader>xX", "<cmd>Trouble toggle<cr>", { noremap = true, silent = true, desc = "Toggle Trouble" })
-- @keymap <leader>cs: Open symbols (Trouble)
keymap(
	"n",
	"<leader>cs",
	"<cmd>Trouble symbols toggle focus=false<cr>",
	{ noremap = true, silent = true, desc = "Symbols" }
)
-- @keymap <leader>cl: Open LSP references/defs (Trouble)
keymap(
	"n",
	"<leader>cl",
	"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
	{ noremap = true, silent = true, desc = "LSP refs/defs" }
)
-- @keymap <leader>xq: Open quickfix (Trouble)
keymap("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { noremap = true, silent = true, desc = "Quickfix list" })
-- @keymap <leader>xl: Open loclist (Trouble)
keymap("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>", { noremap = true, silent = true, desc = "Location list" })
-- @keymap ]d: Go to next diagnostic
keymap("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
-- @keymap [d: Go to previous diagnostic
keymap("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous Diagnostic" })
-- @keymap <leader>dl: Show line diagnostics
keymap("n", "<leader>dl", vim.diagnostic.open_float, { desc = "Line Diagnostics" })

-- ====================================================================================
-- FFF.NVIM (Fast Fuzzy File Finder)
-- ====================================================================================
-- @keymap <leader>ff: Open fff file picker
keymap("n", "<leader>ff", function()
	require("fff").find_files()
end, { desc = "FFF File Picker" })

-- @keymap <leader>fp: Open fff file picker (alternate)
keymap("n", "<leader>fp", function()
	require("fff").find_files()
end, { desc = "FFF File Picker" })

-- ====================================================================================
-- CODE NAVIGATION & EDITING
-- ====================================================================================
-- @keymap -: Open parent directory (Oil)
keymap("n", "-", "<CMD>Oil<CR>", { desc = "Open Parent Directory" })
-- @keymap <leader>-: Oil split - open two dirs side by side (prompted)
keymap("n", "<leader>-", function()
	vim.ui.input({ prompt = "Dir A: ", default = vim.fn.expand("%:p:h"), completion = "dir" }, function(a)
		if not a or a == "" then
			return
		end
		vim.ui.input({ prompt = "Dir B: ", completion = "dir" }, function(b)
			if not b or b == "" then
				return
			end
			vim.cmd("vsplit")
			vim.cmd("wincmd h")
			require("oil").open(a)
			vim.cmd("wincmd l")
			require("oil").open(b)
		end)
	end)
end, { desc = "Oil: open two dirs side by side" })

-- @keymap <leader>S: Open Search/Replace (GrugFar)
keymap("n", "<leader>S", ":GrugFar<cr>", { noremap = true, silent = true, desc = "Search & replace" })

-- @keymap <leader>oo: Navigate to related file (other.nvim)
keymap("n", "<leader>oo", ":Other<cr>", { noremap = true, silent = true, desc = "Related file" })
-- @keymap <leader>ov: Navigate to related file in vertical split
keymap("n", "<leader>ov", ":OtherVSplit<cr>", { noremap = true, silent = true, desc = "Related file (vsplit)" })
-- @keymap <leader>os: Navigate to related file in horizontal split
keymap("n", "<leader>os", ":OtherSplit<cr>", { noremap = true, silent = true, desc = "Related file (split)" })

-- @keymap <leader>ca: Generate code annotation (neogen)
keymap("n", "<leader>ca", ":Neogen<cr>", { noremap = true, silent = true, desc = "Generate annotation" })

-- @keymap <leader>st: Toggle treesitter split/join
-- Treesitter-based split/join helper for code structures.
-- From: https://github.com/wansmer/treesj
local treesj = require("treesj")
treesj.setup({ use_default_keymaps = false })
keymap("n", "<leader>st", treesj.toggle, { noremap = true, silent = true, desc = "Split/join toggle" })

-- ====================================================================================
-- NVIMTREE
-- ====================================================================================
-- @keymap <leader>b: Toggle file tree (nvim-tree)
keymap("n", "<leader>b", ":NvimTreeToggle<CR>", { noremap = true, silent = true, desc = "File tree" })

-- @keymap <leader>sk: Toggle Sidekick CLI (per docs)
keymap("n", "<leader>sk", ":Sidekick cli toggle<CR>", { noremap = true, silent = true, desc = "Sidekick CLI" })

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
end, { noremap = true, silent = true, desc = "Sidekick toggle" })
-- @keymap <leader>as: Select a CLI tool
keymap("n", "<leader>as", function()
	require("sidekick.cli").select()
end, { noremap = true, silent = true, desc = "Sidekick select tool" })
-- @keymap <leader>ad: Close detached CLI
keymap("n", "<leader>ad", function()
	require("sidekick.cli").close()
end, { noremap = true, silent = true, desc = "Sidekick close" })
-- @keymap <leader>at: Send current context, per docs
keymap({ "n", "x" }, "<leader>at", function()
	require("sidekick.cli").send({ msg = "{this}" })
end, { noremap = true, silent = true, desc = "Sidekick send context" })
-- @keymap <leader>af: Send entire buffer
keymap("n", "<leader>af", function()
	require("sidekick.cli").send({ msg = "{file}" })
end, { noremap = true, silent = true, desc = "Sidekick send file" })
-- @keymap <leader>av: Send selection
keymap("x", "<leader>av", function()
	require("sidekick.cli").send({ msg = "{selection}" })
end, { noremap = true, silent = true, desc = "Sidekick send selection" })
-- @keymap <leader>ap: Open Sidekick prompt/command picker
keymap({ "n", "x" }, "<leader>ap", function()
	require("sidekick.cli").prompt()
end, { noremap = true, silent = true, desc = "Sidekick prompt picker" })
-- @keymap <leader>ac: Toggle Claude session and focus it
keymap("n", "<leader>ac", function()
	require("sidekick.cli").toggle({ name = "claude", focus = true })
end, { noremap = true, silent = true, desc = "Sidekick Claude" })

-- ====================================================================================
-- WHICH-KEY GROUPS
-- ====================================================================================
-- Popup helper that groups and hints keybindings as you start a mapping.
-- From: https://github.com/folke/which-key.nvim
local wk = require("which-key")
wk.add({
	{ "<leader>g", group = "Git" },
	{ "<leader>l", group = "LSP" },
	{ "<leader>f", group = "Find/Files" },
	{ "<leader>x", group = "Trouble/Diagnostics" },
	{ "<leader>c", group = "Code" },
	{ "<leader>H", group = "Hunk (Git)" },
})

-- ====================================================================================
-- PLUGIN BINARY INSTALL
-- ====================================================================================
-- :NvimPluginsInstall — download/build all plugins that require native binaries,
-- then install all treesitter parsers.
-- Covers: fff.nvim, blink.cmp, telescope-fzf-native, vscode-diff, nvim-treesitter
vim.api.nvim_create_user_command("NvimPluginsInstall", function()
	-- fff.nvim (Rust .so — has built-in downloader)
	local ok_fff, fff_dl = pcall(require, "fff.download")
	if ok_fff then
		fff_dl.download_or_build_binary()
	else
		vim.notify("fff.nvim not loaded, skipping", vim.log.levels.WARN)
	end

	-- blink.cmp (Rust .so — download from GitHub releases by git tag)
	local blink_dir = vim.fn.globpath(vim.o.packpath, "*/opt/blink.cmp", 0, 1)[1]
		or vim.fn.globpath(vim.o.packpath, "*/start/blink.cmp", 0, 1)[1]
	if blink_dir and blink_dir ~= "" then
		local blink_bin = blink_dir .. "/target/release/libblink_cmp_fuzzy.so"
		if vim.fn.filereadable(blink_bin) == 0 then
			vim.system({ "git", "-C", blink_dir, "describe", "--tags", "--exact-match", "HEAD" }, {}, function(tag_res)
				local tag = tag_res.stdout and tag_res.stdout:gsub("%s+", "") or ""
				if tag == "" then
					vim.schedule(function()
						vim.notify("blink.cmp: not on a git tag, skipping prebuilt download", vim.log.levels.WARN)
					end)
					return
				end
				local libc = "gnu"
				local cc_res = vim.system({ "cc", "-dumpmachine" }, { text = true }):wait()
				if cc_res.code == 0 then
					local parts = vim.split(cc_res.stdout:gsub("%s+", ""), "-")
					local last = parts[#parts]
					if last == "musl" or last == "gnu" then
						libc = last
					end
				end
				local arch = jit.arch:lower():match("x64") and "x86_64" or "aarch64"
				local triple = arch .. "-unknown-linux-" .. libc
				local url = "https://github.com/saghen/blink.cmp/releases/download/" .. tag .. "/" .. triple .. ".so"
				vim.schedule(function()
					vim.notify("Downloading blink.cmp binary (" .. tag .. ")...", vim.log.levels.INFO)
				end)
				vim.fn.mkdir(blink_dir .. "/target/release", "p")
				vim.system(
					{ "curl", "--fail", "--location", "--silent", "--show-error", "-o", blink_bin, url },
					{},
					function(dl)
						if dl.code == 0 then
							vim.schedule(function()
								vim.notify("blink.cmp binary downloaded successfully", vim.log.levels.INFO)
							end)
						else
							vim.schedule(function()
								vim.notify("blink.cmp download failed: " .. (dl.stderr or ""), vim.log.levels.ERROR)
							end)
						end
					end
				)
			end)
		end
	end

	-- telescope-fzf-native (C, make)
	local fzf_dir = vim.fn.globpath(vim.o.packpath, "*/opt/telescope-fzf-native.nvim", 0, 1)[1]
		or vim.fn.globpath(vim.o.packpath, "*/start/telescope-fzf-native.nvim", 0, 1)[1]
	if fzf_dir and fzf_dir ~= "" then
		if vim.fn.filereadable(fzf_dir .. "/build/libfzf.so") == 0 then
			vim.notify("Building telescope-fzf-native.nvim...", vim.log.levels.INFO)
			vim.system({ "make", "-C", fzf_dir, "clean", "all" }, {}, function(res)
				if res.code == 0 then
					vim.schedule(function()
						vim.notify("telescope-fzf-native.nvim built successfully", vim.log.levels.INFO)
					end)
				else
					vim.schedule(function()
						vim.notify("telescope-fzf-native build failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
					end)
				end
			end)
		end
	end

	-- vscode-diff.nvim (C, build.sh)
	local vsd_dir = vim.fn.globpath(vim.o.packpath, "*/opt/vscode-diff.nvim", 0, 1)[1]
		or vim.fn.globpath(vim.o.packpath, "*/start/vscode-diff.nvim", 0, 1)[1]
	if vsd_dir and vsd_dir ~= "" then
		if vim.fn.empty(vim.fn.glob(vsd_dir .. "/libvscode_diff*.so")) == 1 then
			vim.notify("Building vscode-diff.nvim...", vim.log.levels.INFO)
			vim.system({ "bash", vsd_dir .. "/build.sh" }, { cwd = vsd_dir }, function(res)
				if res.code == 0 then
					vim.schedule(function()
						vim.notify("vscode-diff.nvim built successfully", vim.log.levels.INFO)
					end)
				else
					vim.schedule(function()
						vim.notify("vscode-diff build failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
					end)
				end
			end)
		end
	end

	-- nvim-treesitter: install all parsers (async, shows progress in status line)
	local ok_ts = pcall(require, "nvim-treesitter")
	if ok_ts then
		vim.notify("Installing all treesitter parsers (this may take a while)...", vim.log.levels.INFO)
		vim.cmd("TSInstall all")
	else
		vim.notify("nvim-treesitter not loaded, skipping TSInstall", vim.log.levels.WARN)
	end
end, { desc = "Download/build all Neovim plugins that require native binaries + TSInstall all" })
