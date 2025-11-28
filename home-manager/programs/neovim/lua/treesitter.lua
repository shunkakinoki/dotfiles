-- Renders indent guides with optional scopes and excludes help buffers.
-- From: https://github.com/lukas-reineke/indent-blankline.nvim
require("ibl").setup({
	indent = { char = "│" },
	exclude = { filetypes = { "help" } },
	scope = { enabled = false },
})

-- Automatically inserts and removes paired characters while typing.
-- From: https://github.com/windwp/nvim-autopairs
require("nvim-autopairs").setup()

-- Autocloses and renames HTML/XML tags via Treesitter context.
-- From: https://github.com/windwp/nvim-ts-autotag
require("nvim-ts-autotag").setup()

-- Modern surround manipulation for parentheses, brackets, tags, etc.
-- From: https://github.com/kylechui/nvim-surround
require("nvim-surround").setup()

-- Highlights and lists TODO/FIXME/NOTE-style comments across projects.
-- From: https://github.com/folke/todo-comments.nvim
require("todo-comments").setup()

-- Shows the current function or class context at the top of the buffer.
-- From: https://github.com/nvim-treesitter/nvim-treesitter-context
require("treesitter-context").setup()

-- Configures Treesitter language parsers, highlighting, and textobjects.
-- From: https://github.com/nvim-treesitter/nvim-treesitter
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
