-- Completion engine that aggregates LSP, buffer, path, and snippet sources.
-- From: https://github.com/hrsh7th/nvim-cmp
local cmp = require("cmp")
-- Surfaces Copilot suggestions through the nvim-cmp menu.
-- From: https://github.com/zbirenbaum/copilot-cmp
require("copilot_cmp").setup()

cmp.setup({
	snippet = {
		expand = function(args)
			-- LuaSnip powers snippet expansion used by cmp.
			-- From: https://github.com/L3MON4D3/LuaSnip
			require("luasnip").lsp_expand(args.body)
		end,
	},
	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			else
				fallback()
			end
		end, { "i", "s" }),
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "copilot" },
		{ name = "luasnip" },
		{ name = "buffer" },
		{ name = "path" },
	}),
})

-- Set configuration for specific filetype.
cmp.setup.filetype("gitcommit", {
	sources = cmp.config.sources({
		{ name = "git" }, -- You can specify the `git` source if you have it configured
	}, {
		{ name = "buffer" },
	}),
})

-- Use buffer source for `/` and `?` (search)
cmp.setup.cmdline({ "/", "?" }, {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = "buffer" },
	},
})

-- Use cmdline source for `:` (command)
cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{ name = "cmdline" },
	}),
})

-- GitHub Copilot helper with inline suggestions disabled by default.
-- From: https://github.com/zbirenbaum/copilot.lua
require("copilot").setup({
	suggestion = { enabled = false },
	panel = { enabled = false },
})

-- Load VSCode-style snippets from friendly-snippets
-- From: https://github.com/rafamadriz/friendly-snippets
require("luasnip.loaders.from_vscode").lazy_load()
