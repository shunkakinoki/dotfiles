vim.pack.add({
	-- UI
	{ src = "https://github.com/nvim-tree/nvim-web-devicons" },
	{ src = "https://github.com/Mofiqul/dracula.nvim" },
	{
		src = "https://github.com/f-person/auto-dark-mode.nvim",
		priority = 1000,
	},
	-- { src = "https://github.com/folke/sidekick.nvim" }, -- Moved to AI category
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
	{ src = "https://github.com/folke/which-key.nvim" },
	{ src = "https://github.com/folke/trouble.nvim" },
	{ src = "https://github.com/j-hui/fidget.nvim" },
	{ src = "https://github.com/stevearc/oil.nvim" },
	{ src = "https://github.com/folke/flash.nvim" },

	-- FILE PICKER
	{
		src = "https://github.com/dmtrKovalenko/fff.nvim",
		build = function()
			require("fff.download").download_or_build_binary()
		end,
	},

	-- TELESCOPE
	{ src = "https://github.com/nvim-lua/plenary.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope-github.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope.nvim" },
	{ src = "https://github.com/nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	{ src = "https://github.com/nvim-telescope/telescope-ui-select.nvim" },

	-- CODING
	{ src = "https://github.com/rgroli/other.nvim" },
	{ src = "https://github.com/danymat/neogen" },
	{ src = "https://github.com/stevearc/conform.nvim" },
	{ src = "https://github.com/zbirenbaum/copilot.lua" },
	{ src = "https://github.com/rafamadriz/friendly-snippets" },
	{ src = "https://github.com/mfussenegger/nvim-lint" },
	{ src = "https://github.com/MagicDuck/grug-far.nvim" },

	-- COMPLETION (nvim-cmp)
	{ src = "https://github.com/hrsh7th/nvim-cmp" },
	{ src = "https://github.com/hrsh7th/cmp-nvim-lsp" },
	{ src = "https://github.com/hrsh7th/cmp-buffer" },
	{ src = "https://github.com/hrsh7th/cmp-path" },
	{ src = "https://github.com/hrsh7th/cmp-cmdline" },
	{ src = "https://github.com/L3MON4D3/LuaSnip" },
	{ src = "https://github.com/saadparwaiz1/cmp_luasnip" },
	{ src = "https://github.com/zbirenbaum/copilot-cmp" },

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

	-- LSP
	{ src = "https://github.com/neovim/nvim-lspconfig" },
	{ src = "https://github.com/RRethy/vim-illuminate" },
	{ src = "https://github.com/yioneko/nvim-vtsls" },

	-- AI
	{ src = "https://github.com/folke/snacks.nvim" }, -- Required for opencode.nvim
	{ src = "https://github.com/folke/sidekick.nvim" },
	{ src = "https://github.com/NickvanDyke/opencode.nvim" },

	-- TERMINAL
	{ src = "https://github.com/akinsho/toggleterm.nvim" },

	-- GIT
	{ src = "https://github.com/kdheepak/lazygit.nvim" },
	{ src = "https://github.com/esmuellert/vscode-diff.nvim" },
})

require("other-nvim").setup({ mappings = { "golang" } })
require("neogen").setup()
require("gitsigns").setup({})
require("git-conflict").setup({})
require("auto-hlsearch").setup({})
require("grug-far").setup({})
require("flash").setup({})
require("illuminate").configure({})

-- fff.nvim setup - fast fuzzy file finder with Rust backend
require("fff").setup({
	max_results = 100,
	lazy_sync = true,
})

require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "black" },
		javascript = { "biome" },
		typescript = { "biome" },
		javascriptreact = { "biome" },
		typescriptreact = { "biome" },
		json = { "biome" },
		yaml = { "biome" },
		markdown = { "biome" },
		html = { "biome" },
		css = { "biome" },
		go = { "gofmt", "goimports" },
		nix = { "nixfmt" },
	},
	format_on_save = {
		timeout_ms = 500,
		lsp_fallback = true,
	},
})

-- Highlights color codes inline with their actual color
require("colorizer").setup()

local lint = require("lint")
lint.linters_by_ft = {
	python = { "pylint" },
	javascript = { "eslint" },
	typescript = { "eslint" },
}

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
	callback = function()
		lint.try_lint()
	end,
})
