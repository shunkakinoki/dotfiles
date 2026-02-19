local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local utils = require("config.utils")

-- ====================================================================================
-- HIGHLIGHT ON YANK WITH REGISTER ROTATION
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
local highlight_yank_group = augroup("HighlightYank", { clear = true })
autocmd("TextYankPost", {
	group = highlight_yank_group,
	pattern = "*",
	callback = function()
		vim.highlight.on_yank()
		-- Rotate registers on yank to preserve yank history
		if vim.v.event.operator == "y" then
			utils.yank_shift()
		end
	end,
})

-- ====================================================================================
-- AUTO-SAVE ON BUFFER LEAVE / FOCUS LOSS
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
local autosave_group = augroup("AutoSave", { clear = true })
autocmd({ "BufLeave", "FocusLost" }, {
	group = autosave_group,
	pattern = "*",
	callback = function()
		-- Only save if buffer is modified and has a filename
		if vim.bo.modified and vim.fn.expand("%") ~= "" and vim.bo.buftype == "" then
			vim.cmd("silent! update")
		end
	end,
})

-- ====================================================================================
-- CUSTOM TERMINAL TITLE WITH FILE ICONS
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
local title_group = augroup("TerminalTitle", { clear = true })
autocmd({ "BufEnter", "BufFilePost" }, {
	group = title_group,
	pattern = "*",
	callback = function()
		local filename = vim.fn.expand("%:t")
		local dir = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
		local icon = utils.get_file_icon(filename)
		if filename ~= "" then
			vim.opt.titlestring = icon .. " " .. filename .. " - " .. dir
		else
			vim.opt.titlestring = dir
		end
	end,
})
vim.opt.title = true

-- ====================================================================================
-- FILETYPE-SPECIFIC KEYWORD EXTENSIONS
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
local keyword_group = augroup("KeywordExtensions", { clear = true })
autocmd("FileType", {
	group = keyword_group,
	pattern = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
	callback = function()
		-- Add @ and - to keyword characters for better word navigation
		vim.opt_local.iskeyword:append("@-@")
		vim.opt_local.iskeyword:append("-")
	end,
})
autocmd("FileType", {
	group = keyword_group,
	pattern = { "css", "scss", "sass", "less" },
	callback = function()
		vim.opt_local.iskeyword:append("-")
		vim.opt_local.iskeyword:append("#")
	end,
})
autocmd("FileType", {
	group = keyword_group,
	pattern = { "html", "xml", "vue", "svelte" },
	callback = function()
		vim.opt_local.iskeyword:append("-")
		vim.opt_local.iskeyword:append(":")
	end,
})
autocmd("FileType", {
	group = keyword_group,
	pattern = { "json", "jsonc" },
	callback = function()
		vim.opt_local.iskeyword:append("-")
		vim.opt_local.iskeyword:append("$")
	end,
})
autocmd("FileType", {
	group = keyword_group,
	pattern = { "yaml", "toml" },
	callback = function()
		vim.opt_local.iskeyword:append("-")
		vim.opt_local.iskeyword:append(".")
	end,
})
autocmd("FileType", {
	group = keyword_group,
	pattern = "markdown",
	callback = function()
		vim.opt_local.iskeyword:append("-")
		vim.opt_local.iskeyword:append("#")
	end,
})

-- Resize splits on window resize
local resize_group = augroup("ResizeSplits", { clear = true })
autocmd("VimResized", {
	group = resize_group,
	pattern = "*",
	command = "tabdo wincmd =",
})

-- Check for file changes
local checktime_group = augroup("CheckTime", { clear = true })
autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
	group = checktime_group,
	pattern = "*",
	command = "if mode() != 'c' | checktime | endif",
})

-- Git commit messages
local gitcommit_group = augroup("GitCommit", { clear = true })
autocmd("FileType", {
	group = gitcommit_group,
	pattern = "gitcommit",
	command = "startinsert",
})
autocmd("FileType", {
	group = gitcommit_group,
	pattern = "gitcommit",
	callback = function()
		vim.opt_local.spell = true
		vim.opt_local.textwidth = 72
	end,
})

-- Ensure parent folder exists
local newfile_group = augroup("NewFile", { clear = true })
autocmd("BufNewFile", {
	group = newfile_group,
	pattern = "*",
	callback = function()
		local dir = vim.fn.expand("<afile>:p:h")
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, "p")
			vim.cmd([[ :e % ]])
		end
	end,
})

-- Help window position
local help_group = augroup("Help", { clear = true })
autocmd("BufWinEnter", {
	group = help_group,
	pattern = { "*.txt" },
	callback = function()
		if vim.o.filetype == "help" then
			vim.cmd.wincmd("L")
		end
	end,
})

-- Git filetype buffers
local git_group = augroup("Git", { clear = true })
autocmd("FileType", {
	group = git_group,
	pattern = "git",
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		local buf_opts = { noremap = true, silent = true, buffer = bufnr }
		vim.keymap.set("n", "gq", ":silent! close<cr>", buf_opts)
	end,
})

-- Fugitive buffers
local fugitive_group = augroup("Fugitive", { clear = true })
autocmd("FileType", {
	group = fugitive_group,
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
		vim.keymap.set("n", "gp", function()
			async_git({ "push", "--quiet" }, "Pushed!", "Push failed!")
			vim.cmd("silent! close")
		end, buf_opts)

		vim.keymap.set("n", "gP", function()
			async_git({ "pull", "--rebase" }, "Pulled!", "Pull failed!")
			vim.cmd("silent! close")
		end, buf_opts)

		vim.keymap.set("n", "go", function()
			async_git({ "ppr" }, "Pushed and opened PR URL!", "Failed to push or open PR")
			vim.cmd("silent! close")
		end, buf_opts)

		vim.keymap.set("n", "cc", ":silent! Git commit -s<cr>", buf_opts)
		vim.keymap.set("n", "gq", ":silent! close<cr>", buf_opts)
	end,
})

-- Quickfix and help buffers
local qf_help_group = augroup("QuickfixHelp", { clear = true })
autocmd("FileType", {
	group = qf_help_group,
	pattern = { "qf", "help" },
	callback = function()
		vim.keymap.set("n", "<leader>q", ":bdelete<CR>", {
			buffer = vim.api.nvim_get_current_buf(),
			noremap = true,
			silent = true,
		})
	end,
})

-- Markdown files
local markdown_group = augroup("Markdown", { clear = true })
autocmd("FileType", {
	group = markdown_group,
	pattern = "markdown",
	callback = function()
		vim.opt_local.spell = true
		vim.opt_local.textwidth = 80
		vim.opt_local.formatoptions:remove("ct")
	end,
})

-- Terminal
local terminal_group = augroup("Terminal", { clear = true })
autocmd("TermOpen", {
	group = terminal_group,
	callback = function()
		-- You can add terminal specific settings here if needed
	end,
})
