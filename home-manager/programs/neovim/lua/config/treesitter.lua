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

-- Highlights and lists TODO/FIXME/NOTE-style comments across projects.
-- From: https://github.com/folke/todo-comments.nvim
require("todo-comments").setup()

-- Shows the current function or class context at the top of the buffer.
-- From: https://github.com/nvim-treesitter/nvim-treesitter-context
require("treesitter-context").setup({
	multiwindow = true,
})

-- Manages Treesitter parsers via tree-sitter-manager.nvim.
-- From: https://github.com/romus204/tree-sitter-manager.nvim
local M = {}
local tsm_util = require("tree-sitter-manager.util")
local tsm_installer = require("tree-sitter-manager.installer")
M.configured_parsers = require("config.treesitter_parsers")

vim.treesitter.language.register("bash", "env")

require("tree-sitter-manager").setup({
	ensure_installed = M.configured_parsers,
	auto_install = true,
	highlight = true,
})

function M.install_configured()
	local remaining = #M.configured_parsers
	local all_ok = true
	local promise = {}

	function promise:await(callback)
		callback = callback or function() end
		tsm_installer.install(M.configured_parsers, function(out)
			remaining = remaining - 1
			if not out.ok then
				all_ok = false
			end
			if remaining <= 0 then
				callback(not all_ok and "some parsers failed" or nil, all_ok)
			end
		end)
	end

	function promise:wait(timeout_ms)
		local done = false
		self:await(function()
			done = true
		end)
		vim.wait(timeout_ms or 600000, function()
			return done
		end, 100)
	end

	return promise
end

function M.install_configured_sync(timeout_ms)
	M.install_configured():wait(timeout_ms or 600000)

	local missing = {}
	for _, parser in ipairs(M.configured_parsers) do
		if not tsm_util.is_installed(parser) then
			table.insert(missing, parser)
		end
	end

	if #missing > 0 then
		error("configured Treesitter parsers missing after installation: " .. table.concat(missing, " "))
	end
end

function M.verify_configured()
	local failures = {}
	for _, parser in ipairs(M.configured_parsers) do
		local ok, err = pcall(vim.treesitter.language.add, parser)
		if not ok then
			table.insert(failures, ("%s: %s"):format(parser, err))
		end
	end

	if #failures > 0 then
		error("configured Treesitter parsers failed to load:\n" .. table.concat(failures, "\n"))
	end
end

return M
