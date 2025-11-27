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
require("ai")
require("autocmds")
require("completion")
require("keymaps")
require("lsp")
require("plugins")
require("settings")
require("telescope")
require("terminal")
require("treesitter")
require("ui")
require("utils")