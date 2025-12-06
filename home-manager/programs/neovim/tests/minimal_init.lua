-- Minimal init.lua for Neovim testing
-- This provides a clean environment isolated from the full config

-- Set leader key (required by some tests)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Get the directory of this init file
local init_path = debug.getinfo(1, "S").source:sub(2)
local tests_dir = vim.fn.fnamemodify(init_path, ":h")
local nvim_dir = vim.fn.fnamemodify(tests_dir, ":h")

-- Add lua module paths
package.path = package.path .. ";" .. nvim_dir .. "/lua/?.lua"
package.path = package.path .. ";" .. nvim_dir .. "/lua/?/init.lua"

-- Set up runtimepath to include plenary
vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(nvim_dir)

-- Add plenary to runtimepath if installed via vim.pack or available
local plenary_paths = {
	vim.fn.stdpath("data") .. "/site/pack/plugins/start/plenary.nvim",
	vim.fn.stdpath("data") .. "/site/pack/plugins/opt/plenary.nvim",
	vim.fn.expand("~/.local/share/nvim/site/pack/plugins/start/plenary.nvim"),
	vim.fn.expand("~/.local/share/nvim/site/pack/plugins/opt/plenary.nvim"),
	-- CI/test environment paths
	"/tmp/plenary.nvim",
	tests_dir .. "/plenary.nvim",
}

for _, path in ipairs(plenary_paths) do
	if vim.fn.isdirectory(path) == 1 then
		vim.opt.runtimepath:append(path)
		break
	end
end

-- Basic settings for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = false

-- Disable shada (shared data) to avoid file conflicts in parallel tests
vim.opt.shadafile = "NONE"

-- Set a reasonable timeout for async operations
vim.opt.updatetime = 100
