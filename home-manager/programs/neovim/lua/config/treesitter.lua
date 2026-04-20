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
require("nvim-treesitter").setup({
	ensure_installed = {
		"arduino",
		"awk",
		"bash",
		"cpp",
		"css",
		"csv",
		"diff",
		"dockerfile",
		"dotenv",
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
		"ini",
		"javascript",
		"jq",
		"json",
		"lua",
		"make",
		"markdown",
		"markdown_inline",
		"mermaid",
		"nix",
		"perl",
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
		"tsx",
		"typescript",
		"vhs",
		"vim",
		"vimdoc",
		"yaml",
		"zig",
	},
	auto_install = true,
})
