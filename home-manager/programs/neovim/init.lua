-- ====================================================================================
-- LEADER KEY
-- ====================================================================================
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ====================================================================================
-- Set path to modules
-- ====================================================================================
package.path = package.path .. ";" .. vim.fn.stdpath("config") .. "/lua/?.lua"

-- ====================================================================================
-- MODULES
-- ====================================================================================
require("settings")
require("plugins")
require("ui")
require("keymaps")
require("autocmds")
require("lsp")
require("completion")
require("telescope")
require("treesitter")
require("terminal")
require("utils")