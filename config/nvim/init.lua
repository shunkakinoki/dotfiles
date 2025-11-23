vim.opt.compatible = false
vim.opt.termsync = true
vim.opt.hidden = true
vim.opt.updatetime = 250
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
vim.opt.backup = false
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
vim.opt.spellfile = vim.uv.os_homedir() .. "/.spell.add"
vim.opt.laststatus = 2
vim.opt.cursorline = true
vim.opt.grepprg = "rg --vimgrep --smart-case --follow"
vim.opt.background = "dark"
vim.opt.termguicolors = true
vim.opt.shortmess:append("c")
vim.opt.timeoutlen = 300
vim.opt.winborder = "none"

vim.hl.priorities.semantic_tokens = 10
vim.g.fugitive_legacy_commands = 0

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
	-- telescope
	{ src = "https://github.com/nvim-lua/plenary.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope-github.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope.nvim" },

	-- CODING
	{ src = "https://github.com/rgroli/other.nvim" },
	{ src = "https://github.com/danymat/neogen" },
	{ src = "https://github.com/neovim/nvim-lspconfig" },
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

	-- treesitter and friends
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

local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- quicklists
keymap("n", "<leader>co", ":copen<CR>", opts)
keymap("n", "<leader>cc", ":cclose<CR>", opts)

-- write, buffer killing
keymap("n", "<leader>q", ":Bdelete<CR>", opts)
keymap("n", "<leader>bad", ":%bwipeout!<cr>:intro<cr>", opts)
keymap("n", "<leader>w", ":write<CR>", opts)
keymap("n", "<leader>r", ":source $MYVIMRC<CR>", opts)

-- zz
keymap("n", "n", "nzzzv", opts)
keymap("n", "N", "Nzzzv", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-o>", "<C-o>zz", opts)
keymap("n", "<C-i>", "<C-i>zz", opts)

-- system clipboard integration
keymap({ "n", "v" }, "<leader>y", '"+y', opts)

-- copy the current file path
keymap("n", "<leader>py", ':let @" = expand("%:p")<CR>', opts)

-- delete to blackhole
keymap({ "n", "v" }, "<leader>d", '"_d', opts)

-- git
keymap("n", "<leader>gs", ":tab Git<cr>", opts)
keymap("n", "<F9>", ":tab Git mergetool<cr>", opts)
keymap("n", "<leader>gd", ":Gitsign preview_hunk_inline<cr>", opts)

-- indent
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- If I visually select words and paste from clipboard, don't replace my
-- clipboard with the selected word, instead keep my old word in the
-- clipboard
keymap("v", "p", '"_dP', opts)

-- Move text up and down
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)

-- in insert mode, adds new undo points after more some chars:
for _, lhs in ipairs({ "-", "_", ",", ".", ";", ":", "/", "!", "?" }) do
	keymap("i", lhs, lhs .. "<c-g>u", opts)
end

-- exit insert mode with jj
keymap("i", "jj", "<Esc>", opts)

---
--- UI
---

local bg0 = "#1b1b1b"
vim.cmd("colorscheme dracula")
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
		theme = "dracula",
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

-- setup diagnostics
vim.diagnostic.config({
	underline = true,
	update_in_insert = false,
	severity_sort = true,
})

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

require("other-nvim").setup({ mappings = { "golang" } })
keymap("n", "<leader>oo", ":Other<cr>", opts)
keymap("n", "<leader>ov", ":OtherVSplit<cr>", opts)
keymap("n", "<leader>os", ":OtherSplit<cr>", opts)

require("neogen").setup({ snippet_engine = "nvim" })
keymap("n", "gco", ":Neogen<cr>", opts)

require("conform").setup({
	formatters_by_ft = {
		css = { "prettier" },
		fish = { "fish_indent" },
		html = { "prettier" },
		javascript = { "prettier" },
		json = { "jq" },
		lua = { "stylua" },
		markdown = { "prettier" },
		sh = { "shfmt" },
		sql = { "pg_format", "sql_formatter" },
		templ = { "templ" },
		tf = { "terraform_fmt" },
		yaml = { "prettier" },
		["_"] = { "trim_whitespace", "trim_newlines" },
		-- let only the lsp take care of these.
		go = {},
		rust = {},
		zig = {},
	},
	format_after_save = {
		lsp_fallback = true,
	},
})

require("copilot").setup({
	suggestion = { enabled = false },
	panel = { enabled = false },
})

---@module 'blink.cmp'
---@type blink.cmp.Config
local cmp = require("blink.cmp")
cmp.setup({
	keymap = { preset = "default" },
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
	signature = { enabled = true },
	cmdline = {
		enabled = true,
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
		trigger = {
			show_on_insert_on_trigger_character = true,
			show_on_trigger_character = true,
			show_on_keyword = true,
		},
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 250,
			treesitter_highlighting = false,
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

-- Opens the directory of the current file in Finder/file explorer.
vim.api.nvim_create_user_command("Finder", "!open %:h", {})

vim.api.nvim_create_autocmd({
	"BufEnter",
	"CursorHold",
	"CursorHoldI",
	"FocusGained",
}, {
	pattern = "*",
	command = "if mode() != 'c' | checktime | endif",
})

-- resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
	callback = function()
		vim.cmd("tabdo wincmd =")
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "gitcommit",
	command = "startinsert",
})

-- ensure the parent folder exists, so it gets properly added to the lsp
-- context and everything just works.
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

-- Highlight on yank
-- See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	pattern = "*",
	callback = function()
		vim.hl.on_yank()
	end,
})

-- Open help window in a vertical split to the right.
vim.api.nvim_create_autocmd("BufWinEnter", {
	pattern = { "*.txt" },
	callback = function()
		if vim.o.filetype == "help" then
			vim.cmd.wincmd("L")
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "git",
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		local buf_opts = { noremap = true, silent = true, buffer = bufnr }
		keymap("n", "gq", ":silent! close<cr>", buf_opts)
	end,
})

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
		keymap("n", "gp", function()
			async_git({ "push", "--quiet" }, "Pushed!", "Push failed!")
			vim.cmd("silent! close")
		end, buf_opts)

		keymap("n", "gP", function()
			async_git({ "pull", "--rebase" }, "Pulled!", "Pull failed!")
			vim.cmd("silent! close")
		end, buf_opts)

		keymap("n", "go", function()
			async_git({ "ppr" }, "Pushed and opened PR URL!", "Failed to push or open PR")
			vim.cmd("silent! close")
		end, buf_opts)

		keymap("n", "cc", ":silent! Git commit -s<cr>", buf_opts)
		keymap("n", "gq", ":silent! close<cr>", buf_opts)
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "gitcommit",
	callback = function()
		vim.opt_local.spell = true
		vim.opt_local.textwidth = 72
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "qf", "help" },
	callback = function()
		keymap("n", "<leader>q", ":bdelete<CR>", {
			buffer = vim.api.nvim_get_current_buf(),
			noremap = true,
			silent = true,
		})
	end,
})

local get_gopls = function(bufnr)
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	for _, c in ipairs(clients) do
		if c.name == "gopls" then
			return c
		end
	end
	return nil
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()

		vim.opt_local.formatoptions:append("jo")
		vim.opt_local.makeprg = "go build ./..."
		vim.opt_local.errorformat = "%A%f:%l:%c: %m,%-G%.%#"

		vim.api.nvim_buf_create_user_command(bufnr, "GoModTidy", function()
			local gopls = get_gopls(bufnr)
			if gopls == nil then
				return
			end

			vim.cmd([[ noautocmd wall ]])

			local uri = vim.uri_from_bufnr(bufnr)
			local arguments = { { URIs = { uri } } }

			local err = gopls:request_sync("workspace/executeCommand", {
				command = "gopls.tidy",
				arguments = arguments,
			}, 30000, bufnr)

			if err ~= nil and type(err[1]) == "table" then
				vim.notify("go mod tidy: " .. vim.inspect(err), vim.log.levels.ERROR)
				return
			end
		end, { desc = "go mod tidy" })

		local buf_opts = { noremap = true, silent = true, buffer = bufnr }
		keymap("n", "<F6>", vim.cmd.GoModTidy, buf_opts)
		keymap("n", "<F7>", function()
			cclear()
			vim.fn.jobstart("golangci-lint run --max-issues-per-linter=0 --max-same-issues=0 --new", {
				stdout_buffered = true,
				on_stdout = function(_, data)
					if data and #data > 1 then
						vim.schedule(function()
							vim.fn.setqflist({}, " ", { lines = data })
							copen()
						end)
					end
				end,
			})
		end, buf_opts)
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		vim.opt_local.spell = true
		vim.opt_local.textwidth = 80
		vim.opt_local.formatoptions:remove("ct")
	end,
})

-- syntax, indentation, treesitter, etc.
require("ibl").setup({
	indent = { char = "│" },
	exclude = { filetypes = { "help" } },
	scope = { enabled = false },
})

require("nvim-autopairs").setup({
	check_ts = true,
})

require("nvim-ts-autotag").setup()
require("nvim-surround").setup()
require("todo-comments").setup()

require("treesitter-context").setup({
	multiline_threshold = 1,
})

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
				["<leader>a"] = "@parameter.inner",
			},
			swap_previous = {
				["<leader>A"] = "@parameter.inner",
			},
		},
		move = {
			enable = true,
			set_jumps = true,
			goto_next_start = {
				["]f"] = "@function.inner",
				["]c"] = "@class.inner",
				["]a"] = "@parameter.inner",
			},
			goto_next_end = {
				["]F"] = "@function.inner",
				["]C"] = "@class.inner",
				["]A"] = "@parameter.inner",
			},
			goto_previous_start = {
				["[f"] = "@function.inner",
				["[c"] = "@class.inner",
				["[a"] = "@parameter.inner",
			},
			goto_previous_end = {
				["[F"] = "@function.inner",
				["[C"] = "@class.inner",
				["[A"] = "@parameter.inner",
			},
		},
		select = {
			enable = true,
			keymaps = {
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

local treesj = require("treesj")
treesj.setup({ use_default_keymaps = false })
keymap("n", "<leader>st", treesj.toggle, opts)

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

keymap("n", "<leader>of", function()
	builtin.oldfiles(ivy({
		only_cwd = true,
	}))
end, opts)

keymap("n", "<leader>lg", function()
	builtin.live_grep(ivy())
end, opts)

keymap("n", "<leader>fb", function()
	builtin.buffers(ivy())
end, opts)

keymap("n", "<leader>fh", function()
	builtin.help_tags(ivy())
end, opts)

keymap("n", "<leader>fc", function()
	builtin.commands(ivy())
end, opts)

keymap("n", "<leader>fr", function()
	builtin.resume(ivy())
end, opts)

keymap("n", "<leader>fq", function()
	builtin.quickfix(ivy())
end, opts)

keymap("n", "<leader>/", function()
	builtin.current_buffer_fuzzy_find(ivy())
end, opts)

keymap("n", "<leader>ghi", function()
	telescope.extensions.gh.issues(ivy())
end, opts)

-- LSP/autocommands inline replica of caarlos0's modules.
local function setup_lsp_autocommands()
	local ms = require("vim.lsp.protocol").Methods
	local group = vim.api.nvim_create_augroup("LSP", { clear = true })

	---@async
	---@param client vim.lsp.Client
	---@param bufnr number
	local function organize_imports(client, bufnr)
		---@type lsp.Handler
		---@diagnostic disable-next-line: unused-local
		local handler = function(err, result, context, config)
			if err then
				return
			end
			for _, r in pairs(result or {}) do
				if r.edit then
					local enc = client.offset_encoding or "utf-16"
					vim.lsp.util.apply_workspace_edit(r.edit, enc)
				elseif r.command and r.command.command then
					client:exec_cmd(r.command, { bufnr = bufnr })
				end
			end
			vim.cmd([[noautocmd write]])
		end

		local win = vim.api.nvim_get_current_win()
		local params = vim.lsp.util.make_range_params(win, client.offset_encoding or "utf-16")
		params.context = { only = { "source.organizeImports" } }
		client:request(ms.textDocument_codeAction, params, handler, bufnr)
	end

	local function has_clients_with_method(bufnr, method)
		local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
		return #clients > 0
	end

	local function on_clients(bufnr, method, apply, filter)
		local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
		local predicate = filter or function()
			return true
		end
		for _, client in ipairs(clients) do
			if predicate(client) then
				apply(client, bufnr)
			end
		end
	end

	vim.api.nvim_create_autocmd("LspAttach", {
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client == nil then
				return
			end
			if client:supports_method(ms.textDocument_codeLens, vim.api.nvim_get_current_buf()) then
				vim.lsp.inlay_hint.enable(true)
			end
		end,
	})
	vim.api.nvim_create_autocmd("LspDetach", {
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client == nil then
				return
			end
			if client:supports_method(ms.textDocument_codeLens, vim.api.nvim_get_current_buf()) then
				vim.lsp.codelens.clear(client.id)
			end
		end,
		group = group,
	})

	vim.api.nvim_create_autocmd({ "BufWritePre" }, {
		callback = function()
			local format = function(client, bufnr)
				if client.server_capabilities.documentFormattingProvider then
					vim.lsp.buf.format({
						bufnr = bufnr,
						timeout_ms = 5000,
						id = client.id,
					})
				end
			end
			on_clients(vim.api.nvim_get_current_buf(), ms.textDocument_codeAction, format)
		end,
		group = group,
	})

	vim.api.nvim_create_autocmd({ "BufWritePost" }, {
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			local filter = function(client)
				return client.name ~= "lua_ls"
			end
			on_clients(bufnr, ms.textDocument_codeAction, organize_imports, filter)
		end,
		group = group,
	})

	vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
		callback = function()
			if has_clients_with_method(0, ms.textDocument_codeLens) then
				vim.lsp.codelens.refresh({ bufnr = 0 })
			end
		end,
		group = group,
	})

	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		callback = function()
			if has_clients_with_method(0, ms.textDocument_documentHighlight) then
				vim.lsp.buf.document_highlight()
			end
		end,
		group = group,
	})

	vim.api.nvim_create_autocmd({ "CursorMoved" }, {
		callback = function()
			if has_clients_with_method(0, ms.textDocument_documentHighlight) then
				vim.lsp.buf.clear_references()
			end
		end,
		group = group,
	})
end

setup_lsp_autocommands()

local capabilities = require("blink.cmp").get_lsp_capabilities({
	workspace = {
		didChangeWatchedFiles = {
			dynamicRegistration = true,
			relativePatternSupport = true,
		},
	},
}, true)

---@param client vim.lsp.Client
---@param bufnr number
local on_attach = function(client, bufnr)
	local keymap_lsp = function(lhs, rhs)
		vim.keymap.set("n", lhs, rhs, {
			noremap = true,
			silent = true,
			buffer = bufnr,
		})
	end

	local telescope_wrap = function(action)
		return function()
			local ivy_theme = require("telescope.themes").get_ivy()
			require("telescope.builtin")["lsp_" .. action](ivy_theme)
		end
	end

	keymap_lsp("gd", telescope_wrap("definitions"))
	keymap_lsp("grr", telescope_wrap("references"))
	keymap_lsp("gO", telescope_wrap("document_symbols"))
	keymap_lsp("gri", telescope_wrap("implementations"))
	keymap_lsp("gD", vim.lsp.buf.declaration)
	keymap_lsp("K", vim.lsp.buf.hover)
	keymap_lsp("<leader>D", telescope_wrap("type_definitions"))
	keymap_lsp("grl", vim.lsp.codelens.run)
	keymap_lsp("gl", vim.diagnostic.open_float)
	keymap_lsp("[d", function()
		vim.diagnostic.jump({ count = -1 })
		vim.cmd("norm zz")
	end)
	keymap_lsp("]d", function()
		vim.diagnostic.jump({ count = 1 })
		vim.cmd("norm zz")
	end)

	keymap_lsp("<leader>v", function()
		vim.cmd("vsplit | lua vim.lsp.buf.definition()")
		vim.cmd("norm zz")
	end)
end

local lspconfig = require("lspconfig")
require("lspconfig.ui.windows").default_options.border = "none"
lspconfig.gopls.setup({
	capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		gopls = {
			gofumpt = true,
			codelenses = {
				gc_details = true,
				generate = true,
				run_govulncheck = true,
				test = true,
				tidy = true,
				upgrade_dependency = true,
			},
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
			analyses = {
				nilness = true,
				unusedparams = true,
				unusedvariable = true,
				unusedwrite = true,
				useany = true,
			},
			staticcheck = true,
			directoryFilters = { "-.git", "-node_modules" },
			semanticTokens = true,
		},
	},
	flags = {
		debounce_text_changes = 150,
	},
})

lspconfig.ts_ls.setup({
	capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		javascript = {
			inlayHints = {
				includeInlayEnumMemberValueHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayFunctionParameterTypeHints = true,
				includeInlayParameterNameHints = "all",
				includeInlayParameterNameHintsWhenArgumentMatchesName = true,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayVariableTypeHints = true,
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
				includeInlayVariableTypeHints = true,
			},
		},
	},
})

for _, lsp in ipairs({
	"bashls",
	"clangd",
	"cssls",
	"jsonls",
	"pylsp",
	"rust_analyzer",
	"taplo",
	"templ",
	"terraformls",
	"tflint",
	"zls",
}) do
	lspconfig[lsp].setup({
		on_attach = on_attach,
		capabilities = capabilities,
	})
end

for _, lsp in ipairs({ "html", "htmx" }) do
	lspconfig[lsp].setup({
		capabilities = capabilities,
		on_attach = on_attach,
		filetypes = { "html", "templ" },
	})
end

lspconfig.tailwindcss.setup({
	on_attach = on_attach,
	capabilities = capabilities,
	filetypes = { "html", "templ", "javascript" },
	settings = {
		tailwindCSS = {
			includeLanguages = {
				templ = "html",
			},
		},
	},
})

lspconfig.yamlls.setup({
	capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		yaml = {
			schemaStore = {
				url = "https://www.schemastore.org/api/json/catalog.json",
				enable = true,
			},
		},
	},
})

require("nvim-tree").setup({
  view = {
    width = 30,
  },
})
keymap("n", "<leader>b", ":NvimTreeToggle<CR>", opts)
