-- ====================================================================================
-- LEADER KEY
-- ====================================================================================
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ====================================================================================
-- Set path to modules
-- ====================================================================================
local function append_package_path(path)
  if not string.find(package.path, path, 1, true) then
    package.path = package.path .. ";" .. path
  end
end

local config_lua_path = vim.fn.stdpath("config") .. "/lua/?.lua"
append_package_path(config_lua_path)
append_package_path(vim.fn.stdpath("config") .. "/lua/?/init.lua")

local init_source = debug.getinfo(1, "S").source
if init_source:sub(1, 1) == "@" then
  init_source = init_source:sub(2)
end
local init_path = vim.loop.fs_realpath(init_source) or init_source
local init_dir = vim.fn.fnamemodify(init_path, ":h")
append_package_path(init_dir .. "/lua/?.lua")
append_package_path(init_dir .. "/lua/?/init.lua")

-- ====================================================================================
-- MODULES
-- ====================================================================================
require("plugins")
require("settings")
require("autocmds")
require("keymaps")
require("lsp")
require("telescope")
require("treesitter")
require("completion")
require("ai")
require("terminal")
require("ui")
require("utils")
