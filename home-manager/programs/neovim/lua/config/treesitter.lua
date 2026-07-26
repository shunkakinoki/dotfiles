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

-- Manages Treesitter parsers and queries using the supported nvim-treesitter
-- main API. Parser installation is asynchronous during normal startup; CI uses
-- install_configured_sync() below to turn failures into a non-zero exit.
-- From: https://github.com/nvim-treesitter/nvim-treesitter
local M = {}
local nvim_treesitter = require("nvim-treesitter")

M.configured_parsers = require("config.treesitter_parsers")

-- nvim-treesitter does not ship a separate dotenv parser. Neovim detects .env
-- files as the "env" filetype, whose syntax is compatible with the bash parser.
vim.treesitter.language.register("bash", "env")

local available_parsers = {}
for _, parser in ipairs(nvim_treesitter.get_available()) do
	available_parsers[parser] = true
end

local function notify_install_result(context, err, success)
	if not err and success then
		return
	end

	vim.schedule(function()
		local detail = err and tostring(err) or "one or more parsers failed"
		vim.notify(("Treesitter %s failed: %s"):format(context, detail), vim.log.levels.ERROR)
	end)
end

function M.install_configured(options)
	options = vim.tbl_extend("keep", options or {}, { max_jobs = 4 })
	return nvim_treesitter.install(M.configured_parsers, options)
end

function M.install_configured_sync(timeout_ms)
	M.install_configured({ summary = true }):wait(timeout_ms or 600000)

	local installed = {}
	for _, parser in ipairs(nvim_treesitter.get_installed()) do
		installed[parser] = true
	end

	local missing = {}
	for _, parser in ipairs(M.configured_parsers) do
		if not installed[parser] then
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

local installed_parsers = {}
for _, parser in ipairs(nvim_treesitter.get_installed()) do
	installed_parsers[parser] = true
end

local missing_parsers = {}
for _, parser in ipairs(M.configured_parsers) do
	if not installed_parsers[parser] then
		table.insert(missing_parsers, parser)
	end
end

if #missing_parsers > 0 then
	nvim_treesitter.install(missing_parsers, { max_jobs = 4 }):await(function(err, success)
		notify_install_result("startup installation", err, success)
	end)
end

local treesitter_group = vim.api.nvim_create_augroup("TreesitterAutoInstall", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
	group = treesitter_group,
	pattern = "*",
	desc = "Install available parsers and enable Treesitter highlighting",
	callback = function(args)
		local parser = vim.treesitter.language.get_lang(args.match) or args.match
		if not available_parsers[parser] then
			return
		end

		local function start_highlighting()
			return vim.api.nvim_buf_is_valid(args.buf) and pcall(vim.treesitter.start, args.buf, parser)
		end

		if start_highlighting() then
			return
		end

		nvim_treesitter.install({ parser }):await(function(err, success)
			notify_install_result(("installation for %s"):format(parser), err, success)
			if err or not success then
				return
			end

			vim.schedule(function()
				start_highlighting()
			end)
		end)
	end,
})

return M
