-- ====================================================================================
-- VIM OPTIONS
-- ====================================================================================
vim.opt.compatible = false
vim.opt.termsync = true
vim.opt.hidden = true
vim.opt.updatetime = 300
vim.opt.mouse = ""
vim.opt.inccommand = "nosplit"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.wrap = true
vim.opt.textwidth = 0
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.tabstop = 2
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 10
vim.opt.sidescrolloff = 10
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.smoothscroll = true
vim.opt.swapfile = false
vim.opt.backup = true
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("data") .. "undodir"
vim.opt.hlsearch = false
vim.opt.ignorecase = true
vim.opt.incsearch = true
vim.opt.ruler = true
vim.opt.wildmenu = true
vim.opt.autoread = true
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.colorcolumn = "80"
vim.opt.backspace = { "indent", "eol", "start" }
vim.opt.spelllang = { "en_us" }
vim.opt.laststatus = 2
vim.opt.cursorline = true
vim.opt.grepprg = "rg --vimgrep --smart-case --follow"
-- Background will be set automatically based on system theme
vim.opt.termguicolors = true
vim.opt.shortmess:append("c")
vim.opt.timeoutlen = 300
vim.opt.winborder = "none"

vim.hl.priorities.semantic_tokens = 10
vim.g.fugitive_legacy_commands = 0

-- ====================================================================================
-- PLUGIN INSTALLATION
-- ====================================================================================
vim.pack.add({
	-- UI
	{ src = "https://github.com/nvim-tree/nvim-web-devicons" },
	{ src = "https://github.com/Mofiqul/dracula.nvim" },
	{ src = "https://github.com/folke/sidekick.nvim" },
	{ src = "https://github.com/nvim-tree/nvim-tree.lua" },
	{ src = "https://github.com/nvim-lualine/lualine.nvim" },
	{ src = "https://github.com/stevearc/dressing.nvim" },
	{ src = "https://github.com/rcarriga/nvim-notify" },
	{ src = "https://github.com/christoomey/vim-tmux-navigator" },
	{ src = "https://github.com/asiryk/auto-hlsearch.nvim" },
	{ src = "https://github.com/famiu/bufdelete.nvim" },
	{ src = "https://github.com/norcalli/nvim-colorizer.lua" },
	{ src = "https://github.com/lewis6991/gitsigns.nvim" },
	{ src = "https://github.com/akinsho/git-conflict.nvim" },

	-- TELESCOPE
	{ src = "https://github.com/nvim-lua/plenary.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope-github.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope.nvim" },

	-- CODING
	{ src = "https://github.com/rgroli/other.nvim" },
	{ src = "https://github.com/danymat/neogen" },
	{ src = "https://github.com/stevearc/conform.nvim" },
	{ src = "https://github.com/zbirenbaum/copilot.lua" },
	{ src = "https://github.com/rafamadriz/friendly-snippets" },
	{ src = "https://github.com/giuxtaposition/blink-cmp-copilot" },
	{
		src = "https://github.com/saghen/blink.cmp",
		version = vim.version.range("1.*"),
	},

	-- TPOPE
	{ src = "https://github.com/tpope/vim-fugitive" },
	{ src = "https://github.com/tpope/vim-rhubarb" },
	{ src = "https://github.com/tpope/vim-abolish" },
	{ src = "https://github.com/tpope/vim-repeat" },
	{ src = "https://github.com/tpope/vim-eunuch" },
	{ src = "https://github.com/tpope/vim-sleuth" },
	{ src = "https://github.com/tpope/vim-speeddating" },

	-- TREESITTER
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter" },
	{ src = "https://github.com/lukas-reineke/indent-blankline.nvim" },
	{ src = "https://github.com/wansmer/treesj" },
	{ src = "https://github.com/windwp/nvim-autopairs" },
	{ src = "https://github.com/windwp/nvim-ts-autotag" },
	{ src = "https://github.com/kylechui/nvim-surround" },
	{ src = "https://github.com/folke/todo-comments.nvim" },
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter-context" },
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
	{ src = "https://github.com/RRethy/nvim-treesitter-endwise" },
})

-- ====================================================================================
-- KEYMAPS
-- ====================================================================================
local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set

-- @keymap <Space>: Set as leader key
--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

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
-- @keymap <leader>q: Close current buffer
keymap("n", "<leader>q", ":Bdelete<CR>", opts)
-- @keymap <leader>bad: Wipe all buffers
keymap("n", "<leader>bad", ":%bwipeout!<cr>:intro<cr>", opts)
-- @keymap <leader>w: Write file
keymap("n", "<leader>w", ":write<CR>", opts)
-- @keymap <leader>r: Reload Neovim configuration
keymap("n", "<leader>r", function()
	vim.cmd("source $MYVIMRC")
	set_theme() -- Refresh theme on reload
end, opts)
-- @keymap <leader>h: Show help (all keymaps and commands)
keymap("n", "<leader>h", ":Help<CR>", opts)
-- @keymap ZZ: Save all buffers and quit
keymap("n", "ZZ", ":wa<CR>:q<CR>", opts)

-- ====================================================================================
-- TERMINAL
-- ====================================================================================
-- @keymap <leader>j: Open terminal in split
-- terminal
keymap("n", "<leader>j", ":10split | terminal<CR>", opts)

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
-- system clipboard integration
keymap({ "n", "v" }, "<leader>y", '"+y', opts)

-- @keymap <leader>py: Copy current file path to clipboard
-- copy the current file path
keymap("n", "<leader>py", ':let @" = expand("%:p")<CR>', opts)

-- @keymap <leader>d: Delete to blackhole register
-- delete to blackhole
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
-- If I visually select words and paste from clipboard, don't replace my
-- clipboard with the selected word, instead keep my old word in the
-- clipboard
keymap("v", "p", '"_dP', opts)

-- @keymap K: Move selected text up (visual mode)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
-- @keymap J: Move selected text down (visual mode)
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)

-- ====================================================================================
-- INSERT MODE OPERATIONS
-- ====================================================================================
-- @keymap -/_/,/./;/:/!/?: Add undo breakpoints after punctuation
-- in insert mode, adds new undo points after more some chars:
for _, lhs in ipairs({ "-", "_", ",", ".", ";", ":", "/", "!", "?" }) do
	keymap("i", lhs, lhs .. "<c-g>u", opts)
end

-- @keymap jj: Exit insert mode
-- exit insert mode with jj
keymap("i", "jj", "<Esc>", opts)

-- ====================================================================================
-- UI CONFIGURATION
-- ====================================================================================

-- Detect system theme and set colorscheme accordingly
local function detect_system_theme()
	local is_dark = false
	if vim.fn.has("mac") == 1 then
		-- macOS: Check AppleInterfaceStyle
		local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
		if handle then
			local result = handle:read("*a")
			handle:close()
			is_dark = result:match("Dark") ~= nil
		else
			-- Default to dark if detection fails
			is_dark = true
		end
	elseif vim.fn.has("unix") == 1 then
		-- Linux: Check gsettings or environment variable
		local handle = io.popen("gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | grep -q dark || echo ''")
		if handle then
			local result = handle:read("*a")
			handle:close()
			is_dark = result:match("dark") ~= nil
		else
			-- Fallback: Check GTK_THEME or default to dark
			local gtk_theme = os.getenv("GTK_THEME") or ""
			is_dark = gtk_theme:match("dark") ~= nil or true
		end
	else
		-- Default to dark for other systems
		is_dark = true
	end
	return is_dark
end

local function set_theme()
	local is_dark = detect_system_theme()
	if is_dark then
		vim.opt.background = "dark"
		vim.cmd("colorscheme dracula")
	else
		vim.opt.background = "light"
		-- Use a light theme - you can change this to your preferred light theme
		vim.cmd("colorscheme default")
	end
	-- Refresh lualine theme if it's already loaded
	if package.loaded["lualine"] then
		require("lualine").setup({
			options = {
				theme = vim.o.background == "dark" and "dracula" or "auto",
				component_separators = "",
				section_separators = "",
			},
			sections = {
				lualine_b = section_b,
				lualine_c = section_c,
			},
			inactive_sections = {
				lualine_c = section_c,
				lualine_x = { "location" },
			},
		})
	end
end

-- Set initial theme
set_theme()

vim.api.nvim_set_hl(0, "StatusLine", { reverse = false })
vim.api.nvim_set_hl(0, "StatusLineNC", { reverse = false })

require("dressing").setup({ input = { insert_only = true } })

local notify = require("notify")
notify.setup({
	render = "compact",
	stages = "static",
})
vim.notify = notify

local section_b = { "branch", "diff", { "diagnostics", sources = { "nvim_workspace_diagnostic" } } }
local section_c = { "%=", { "filename", file_status = false, path = 1 } }
require("lualine").setup({
	options = {
		theme = vim.o.background == "dark" and "dracula" or "auto",
		component_separators = "",
		section_separators = "",
	},
	sections = {
		lualine_b = section_b,
		lualine_c = section_c,
	},
	inactive_sections = {
		lualine_c = section_c,
		lualine_x = { "location" },
	},
})

require("auto-hlsearch").setup({})
require("gitsigns").setup({})
require("git-conflict").setup({})

-- ====================================================================================
-- DIAGNOSTICS
-- ====================================================================================
-- setup diagnostics
vim.diagnostic.config({
	underline = true,
	update_in_insert = false,
	severity_sort = true,
})

-- @keymap <leader>xx: Open diagnostics in quickfix
keymap("n", "<leader>xx", vim.diagnostic.setqflist, opts)

-- set up diagnostic signs
local severity = vim.diagnostic.severity
local signs = {
	[severity.ERROR] = "",
	[severity.WARN] = "",
	[severity.INFO] = "",
	[severity.HINT] = "󰌶",
}
vim.diagnostic.config({
	signs = {
		text = signs,
	},
})

-- ====================================================================================
-- CODE NAVIGATION
-- ====================================================================================
require("other-nvim").setup({ mappings = { "golang" } })
-- @keymap <leader>oo: Navigate to related file (other.nvim)
keymap("n", "<leader>oo", ":Other<cr>", opts)
-- @keymap <leader>ov: Navigate to related file in vertical split
keymap("n", "<leader>ov", ":OtherVSplit<cr>", opts)
-- @keymap <leader>os: Navigate to related file in horizontal split
keymap("n", "<leader>os", ":OtherSplit<cr>", opts)

-- @keymap gco: Generate code annotation (neogen)
require("neogen").setup()
keymap("n", "gco", ":Neogen<cr>", opts)

-- ====================================================================================
-- COMPLETION AND COPILOT
-- ====================================================================================
require("copilot").setup({
	suggestion = { enabled = false },
	panel = { enabled = false },
})

---@module 'blink.cmp'
---@type blink.cmp.Config
local cmp = require("blink.cmp")
cmp.setup({
	appearance = {
		nerd_font_variant = "mono",
		kind_icons = {
			Array = "",
			Boolean = "",
			Class = "",
			Color = "",
			Constant = "",
			Constructor = "",
			Copilot = "",
			Enum = "",
			EnumMember = "",
			Event = "",
			Field = "",
			File = "",
			Folder = "󰉋",
			Function = "",
			Interface = "",
			Key = "",
			Keyword = "",
			Method = "",
			Module = "",
			Namespace = "",
			Null = "󰟢",
			Number = "",
			Object = "",
			Operator = "",
			Package = "",
			Property = "",
			Reference = "",
			Snippet = "",
			String = "",
			Struct = "",
			Text = "",
			TypeParameter = "",
			Unit = "",
			Value = "",
			Variable = "",
		},
	},
	cmdline = {
		sources = function()
			local type = vim.fn.getcmdtype()
			if type == "/" or type == "?" then
				return { "buffer" }
			end
			if type == ":" then
				return { "cmdline" }
			end
			return {}
		end,
		completion = {
			menu = {
				draw = {
					columns = {
						{ "kind_icon", "label", gap = 1 },
						{ "kind" },
					},
				},
			},
		},
	},
	sources = {
		default = { "lsp", "path", "snippets", "buffer", "copilot" },
		providers = {
			lsp = {
				min_keyword_length = 0,
				score_offset = 0,
			},
			path = {
				min_keyword_length = 0,
			},
			snippets = {
				min_keyword_length = 2,
			},
			buffer = {
				min_keyword_length = 5,
				max_items = 5,
			},
			copilot = {
				name = "copilot",
				module = "blink-cmp-copilot",
				score_offset = 1000,
				min_keyword_length = 0,
				async = true,
				override = {
					-- copilot complete on space, new line, etc as well...
					get_trigger_characters = function(self)
						local trigger_characters = self:get_trigger_characters()
						vim.list_extend(trigger_characters, { "\n", "\t", " " })
						return trigger_characters
					end,
				},
				transform_items = function(_, items)
					local CompletionItemKind = require("blink.cmp.types").CompletionItemKind
					local kind_idx = #CompletionItemKind + 1
					CompletionItemKind[kind_idx] = "Copilot"
					for _, item in ipairs(items) do
						item.kind = kind_idx
					end
					return items
				end,
			},
		},
	},
	completion = {
		accept = { auto_brackets = { enabled = true } },
		keyword = {
			range = "full",
		},
		menu = {
			draw = {
				columns = {
					{ "kind_icon", "label", gap = 1 },
					{ "kind" },
				},
			},
		},
	},
})

-- @keymap <Tab>: Accept copilot/completion (selects first if none selected)
-- Use Tab to accept copilot/completions
keymap("i", "<Tab>", function()
	-- Check if completion menu is visible (works for blink.cmp and built-in)
	if vim.fn.pumvisible() == 1 then
		-- Since noselect is enabled, first select the first item, then accept
		-- This ensures we accept the top suggestion (or navigate to copilot if needed)
		local current_selection = vim.fn.complete_info({ "selected" }).selected
		if current_selection == -1 then
			-- Nothing selected, select first item
			return vim.api.nvim_replace_termcodes("<C-n><C-y>", true, false, true)
		else
			-- Something is selected, just accept it
			return vim.api.nvim_replace_termcodes("<C-y>", true, false, true)
		end
	end
	-- No completion menu visible, insert tab normally
	return vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
end, { expr = true, noremap = true, silent = true })

-- ====================================================================================
-- UTILITY FUNCTIONS
-- ====================================================================================
local function copen()
	if vim.fn.getqflist({ size = 0 }).size > 1 then
		vim.cmd("copen")
	else
		vim.cmd("cclose")
	end
end

local function cclear()
	vim.fn.setqflist({}, "r")
end

-- @command Finder: Open current file directory in Finder/file explorer
-- Opens the directory of the current file in Finder/file explorer.
vim.api.nvim_create_user_command("Finder", "!open %:h", {})

-- @command ThemeRefresh: Refresh theme based on system appearance
-- Refreshes the colorscheme based on current system theme (dark/light).
vim.api.nvim_create_user_command("ThemeRefresh", set_theme, { desc = "Refresh theme based on system appearance" })

-- ====================================================================================
-- AUTOCMDS
-- ====================================================================================
-- Check for file changes on BufEnter, CursorHold, CursorHoldI, and FocusGained
vim.api.nvim_create_autocmd({
	"BufEnter",
	"CursorHold",
	"CursorHoldI",
	"FocusGained",
}, {
	pattern = "*",
	command = "if mode() != 'c' | checktime | endif",
})

-- Resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
	callback = function()
		vim.cmd("tabdo wincmd =")
	end,
})

-- Start in insert mode when opening git commit messages
vim.api.nvim_create_autocmd("FileType", {
	pattern = "gitcommit",
	command = "startinsert",
})

-- Ensure the parent folder exists when creating new files (for LSP context)
vim.api.nvim_create_autocmd("BufNewFile", {
	pattern = "*",
	callback = function()
		local dir = vim.fn.expand("<afile>:p:h")
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, "p")
			vim.cmd([[ :e % ]])
		end
	end,
})

-- Highlight on yank (briefly highlight yanked text)
-- See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	pattern = "*",
	callback = function()
		vim.hl.on_yank()
	end,
})

-- Open help window in a vertical split to the right
vim.api.nvim_create_autocmd("BufWinEnter", {
	pattern = { "*.txt" },
	callback = function()
		if vim.o.filetype == "help" then
			vim.cmd.wincmd("L")
		end
	end,
})

-- Add keymaps for git filetype buffers
vim.api.nvim_create_autocmd("FileType", {
	pattern = "git",
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		local buf_opts = { noremap = true, silent = true, buffer = bufnr }
		-- @keymap gq: Close git buffer
		keymap("n", "gq", ":silent! close<cr>", buf_opts)
	end,
})

-- Configure fugitive buffers with git keymaps (push, pull, commit, etc.)
vim.api.nvim_create_autocmd("FileType", {
	pattern = "fugitive",
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()

		local function async_git(args, success_msg, error_msg)
			vim.system({ "git", unpack(args) }, {}, function(obj)
				vim.schedule(function()
					if obj.code == 0 then
						vim.notify(success_msg, vim.log.levels.INFO)
					else
						vim.notify(error_msg, vim.log.levels.ERROR)
					end
				end)
			end)
		end

		vim.cmd("normal )k=")

		local buf_opts = { noremap = true, silent = true, buffer = bufnr }
		-- @keymap gp: Git push (fugitive buffer)
		keymap("n", "gp", function()
			async_git({ "push", "--quiet" }, "Pushed!", "Push failed!")
			vim.cmd("silent! close")
		end, buf_opts)

		-- @keymap gP: Git pull with rebase (fugitive buffer)
		keymap("n", "gP", function()
			async_git({ "pull", "--rebase" }, "Pulled!", "Pull failed!")
			vim.cmd("silent! close")
		end, buf_opts)

		-- @keymap go: Git push and open PR (fugitive buffer)
		keymap("n", "go", function()
			async_git({ "ppr" }, "Pushed and opened PR URL!", "Failed to push or open PR")
			vim.cmd("silent! close")
		end, buf_opts)

		-- @keymap cc: Git commit with sign-off (fugitive buffer)
		-- @keymap gq: Close fugitive buffer
		keymap("n", "cc", ":silent! Git commit -s<cr>", buf_opts)
		keymap("n", "gq", ":silent! close<cr>", buf_opts)
	end,
})

-- Enable spell check and set textwidth for git commit messages
vim.api.nvim_create_autocmd("FileType", {
	pattern = "gitcommit",
	callback = function()
		vim.opt_local.spell = true
		vim.opt_local.textwidth = 72
	end,
})

-- Add <leader>q keymap to close quickfix and help buffers
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "qf", "help" },
	callback = function()
		-- @keymap <leader>q: Close quickfix/help buffer
		keymap("n", "<leader>q", ":bdelete<CR>", {
			buffer = vim.api.nvim_get_current_buf(),
			noremap = true,
			silent = true,
		})
	end,
})

-- Add keymap to exit terminal mode and switch to previous window
vim.api.nvim_create_autocmd("TermOpen", {
	callback = function()
		-- @keymap <leader>j: Exit terminal and switch to previous window
		keymap("t", "<leader>j", [[<C-\><C-n><C-w>p]], {
			buffer = vim.api.nvim_get_current_buf(),
			noremap = true,
			silent = true,
		})
	end,
})

-- Enable spell check and set textwidth for markdown files
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		vim.opt_local.spell = true
		vim.opt_local.textwidth = 80
		vim.opt_local.formatoptions:remove("ct")
	end,
})

-- ====================================================================================
-- TREESITTER AND SYNTAX
-- ====================================================================================
-- syntax, indentation, treesitter, etc.
require("ibl").setup({
	indent = { char = "│" },
	exclude = { filetypes = { "help" } },
	scope = { enabled = false },
})

require("nvim-autopairs").setup()

require("nvim-ts-autotag").setup()
require("nvim-surround").setup()
require("todo-comments").setup()

require("treesitter-context").setup()

-- ====================================================================================
-- TREESITTER CONFIGURATION
-- ====================================================================================
---@diagnostic disable-next-line: missing-fields
require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"arduino",
		"awk",
		"bash",
		"cpp",
		"css",
		"csv",
		"diff",
		"dockerfile",
		"fish",
		"git_config",
		"git_rebase",
		"gitattributes",
		"gitcommit",
		"gitignore",
		"go",
		"gomod",
		"gosum",
		"gowork",
		"graphql",
		"hcl",
		"html",
		"http",
		"http",
		"ini",
		"javascript",
		"jq",
		"json",
		"lua",
		"make",
		"markdown",
		"markdown_inline",
		"mermaid",
		"python",
		"query",
		"regex",
		"ruby",
		"scss",
		"sql",
		"ssh_config",
		"templ",
		"terraform",
		"toml",
		"vhs",
		"vim",
		"vimdoc",
		"yaml",
		"zig",
	},
	highlight = {
		enable = true,
	},
	indent = {
		enable = true,
	},
	endwise = {
		enable = true,
	},
	autopairs = {
		enable = true,
	},
	context_commentstring = {
		enable = true,
		enable_autocmd = false,
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "<C-space>",
			node_incremental = "<C-space>",
			node_decremental = "<bs>",
			scope_incremental = "<noop>",
		},
	},
	auto_install = true,
	textobjects = {
		enable = true,
		lookahead = true,
		swap = {
			enable = true,
			swap_next = {
				-- @keymap <leader>a: Swap next parameter (treesitter)
				["<leader>a"] = "@parameter.inner",
			},
			swap_previous = {
				-- @keymap <leader>A: Swap previous parameter (treesitter)
				["<leader>A"] = "@parameter.inner",
			},
		},
		move = {
			enable = true,
			set_jumps = true,
			goto_next_start = {
				-- @keymap ]f: Go to next function start (treesitter)
				-- @keymap ]c: Go to next class start (treesitter)
				-- @keymap ]a: Go to next parameter start (treesitter)
				["]f"] = "@function.inner",
				["]c"] = "@class.inner",
				["]a"] = "@parameter.inner",
			},
			goto_next_end = {
				-- @keymap ]F: Go to next function end (treesitter)
				-- @keymap ]C: Go to next class end (treesitter)
				-- @keymap ]A: Go to next parameter end (treesitter)
				["]F"] = "@function.inner",
				["]C"] = "@class.inner",
				["]A"] = "@parameter.inner",
			},
			goto_previous_start = {
				-- @keymap [f: Go to previous function start (treesitter)
				-- @keymap [c: Go to previous class start (treesitter)
				-- @keymap [a: Go to previous parameter start (treesitter)
				["[f"] = "@function.inner",
				["[c"] = "@class.inner",
				["[a"] = "@parameter.inner",
			},
			goto_previous_end = {
				-- @keymap [F: Go to previous function end (treesitter)
				-- @keymap [C: Go to previous class end (treesitter)
				-- @keymap [A: Go to previous parameter end (treesitter)
				["[F"] = "@function.inner",
				["[C"] = "@class.inner",
				["[A"] = "@parameter.inner",
			},
		},
		select = {
			enable = true,
			keymaps = {
				-- @keymap af: Select function outer (treesitter)
				-- @keymap if: Select function inner (treesitter)
				-- @keymap ac: Select conditional outer (treesitter)
				-- @keymap ic: Select conditional inner (treesitter)
				-- @keymap aa: Select parameter outer (treesitter)
				-- @keymap ia: Select parameter inner (treesitter)
				-- @keymap av: Select variable outer (treesitter)
				-- @keymap iv: Select variable inner (treesitter)
				["af"] = "@function.outer",
				["if"] = "@function.inner",

				["ac"] = "@conditional.outer",
				["ic"] = "@conditional.inner",

				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",

				["av"] = "@variable.outer",
				["iv"] = "@variable.inner",
			},
		},
	},
})

-- @keymap <leader>st: Toggle treesitter split/join
local treesj = require("treesj")
treesj.setup({ use_default_keymaps = false })
keymap("n", "<leader>st", treesj.toggle, opts)

-- ====================================================================================
-- TELESCOPE CONFIGURATION
-- ====================================================================================
local telescope = require("telescope")
telescope.setup({
	defaults = {
		pickers = {
			find_files = {
				theme = "ivy",
			},
		},
		prompt_prefix = "   ",
		selection_caret = " ❯ ",
		entry_prefix = "   ",
		multi_icon = "+ ",
		path_display = { "filename_first" },
		vimgrep_arguments = {
			"rg",
			"--color=never",
			"--no-heading",
			"--with-filename",
			"--line-number",
			"--column",
			"--smart-case",
			"--sort=path",
		},
	},
})
telescope.load_extension("gh")

local function ivy(iopts)
	return require("telescope.themes").get_ivy(iopts)
end

local builtin = require("telescope.builtin")
-- @keymap <C-p>: Find files (Telescope)
vim.keymap.set("n", "<C-p>", function()
	builtin.find_files(ivy({
		find_command = {
			"fd",
			"--type",
			"f",
			"--strip-cwd-prefix",
			"--hidden",
		},
	}))
end, opts)

-- @keymap <leader>of: Open old files (Telescope)
keymap("n", "<leader>of", function()
	builtin.oldfiles(ivy({
		only_cwd = true,
	}))
end, opts)

-- @keymap <leader>lg: Live grep (Telescope)
keymap("n", "<leader>lg", function()
	builtin.live_grep(ivy())
end, opts)

-- @keymap <leader>fb: Find buffers (Telescope)
keymap("n", "<leader>fb", function()
	builtin.buffers(ivy())
end, opts)

-- @keymap <leader>fh: Find help tags (Telescope)
keymap("n", "<leader>fh", function()
	builtin.help_tags(ivy())
end, opts)

-- @keymap <leader>fc: Find commands (Telescope)
keymap("n", "<leader>fc", function()
	builtin.commands(ivy())
end, opts)

-- @keymap <leader>fr: Resume last Telescope search
keymap("n", "<leader>fr", function()
	builtin.resume(ivy())
end, opts)

-- @keymap <leader>fq: Find in quickfix (Telescope)
keymap("n", "<leader>fq", function()
	builtin.quickfix(ivy())
end, opts)

-- @keymap <leader>/: Fuzzy find in current buffer (Telescope)
keymap("n", "<leader>/", function()
	builtin.current_buffer_fuzzy_find(ivy())
end, opts)

-- @keymap <leader>ghi: Find GitHub issues (Telescope)
keymap("n", "<leader>ghi", function()
	telescope.extensions.gh.issues(ivy())
end, opts)

-- ====================================================================================
-- FILE TREE
-- ====================================================================================
-- @keymap <leader>b: Toggle file tree (nvim-tree)
require("nvim-tree").setup({
	view = {
		width = 30,
	},
})
keymap("n", "<leader>b", ":NvimTreeToggle<CR>", opts)

-- ====================================================================================
-- HELP COMMAND
-- ====================================================================================
-- @command Help: Show all keymaps and commands from init.lua
vim.api.nvim_create_user_command("Help", function()
	local config_file = vim.fn.stdpath("config") .. "/init.lua"
	local file = io.open(config_file, "r")
	if not file then
		vim.notify("Could not read config file: " .. config_file, vim.log.levels.ERROR)
		return
	end

	local keymaps = {}
	local commands = {}
	local plugins = {}
	local current_section = "General"

	for line in file:lines() do
		-- Parse @keymap comments
		local key, desc = line:match("^%s*%-%-%s*@keymap%s+(.+):%s*(.+)$")
		if key and desc then
			table.insert(keymaps, { key = key, desc = desc, section = current_section })
		end

		-- Parse @command comments
		local cmd, cmd_desc = line:match("^%s*%-%-%s*@command%s+(.+):%s*(.+)$")
		if cmd and cmd_desc then
			table.insert(commands, { cmd = cmd, desc = cmd_desc })
		end

		-- Parse @plugin comments
		local plugin, plugin_desc = line:match("^%s*%-%-%s*@plugin%s+(.+):%s*(.+)$")
		if plugin and plugin_desc then
			table.insert(plugins, { plugin = plugin, desc = plugin_desc })
		end

		-- Track sections
		if line:match("^%-%-%s*@section") or line:match("^%-%-%s*%-%-%-") then
			current_section = line:match("UI") and "UI"
				or line:match("CODING") and "Coding"
				or line:match("TPOPE") and "Plugins"
				or line:match("treesitter") and "Treesitter"
				or "General"
		end
	end

	file:close()

	-- Create help buffer
	local buf = vim.api.nvim_create_buf(false, true)
	local lines = {}

	table.insert(lines, "Neovim Configuration Help")
	table.insert(lines, "=" .. string.rep("=", 50))
	table.insert(lines, "")

	-- Keymaps section
	table.insert(lines, "KEYMAPS")
	table.insert(lines, string.rep("-", 50))
	table.insert(lines, "")
	for _, km in ipairs(keymaps) do
		local key = km.key:gsub("<leader>", "<Space>")
		table.insert(lines, string.format("  %-25s %s", key, km.desc))
	end
	table.insert(lines, "")

	-- Commands section
	if #commands > 0 then
		table.insert(lines, "COMMANDS")
		table.insert(lines, string.rep("-", 50))
		table.insert(lines, "")
		for _, cmd in ipairs(commands) do
			table.insert(lines, string.format("  :%-24s %s", cmd.cmd, cmd.desc))
		end
		table.insert(lines, "")
	end

	-- Plugins section
	if #plugins > 0 then
		table.insert(lines, "PLUGINS")
		table.insert(lines, string.rep("-", 50))
		table.insert(lines, "")
		for _, plugin in ipairs(plugins) do
			table.insert(lines, string.format("  %-25s %s", plugin.plugin, plugin.desc))
		end
		table.insert(lines, "")
	end

	table.insert(lines, "=" .. string.rep("=", 50))
	table.insert(lines, "Press 'q' to close")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "filetype", "help")
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_name(buf, "neovim-config-help")

	-- Open in split
	vim.cmd("split")
	vim.api.nvim_set_current_buf(buf)

	-- @keymap q: Close help buffer
	-- Map q to close
	vim.keymap.set("n", "q", ":close<CR>", { buffer = buf, silent = true })
end, { desc = "Show all keymaps and commands from init.lua" })
