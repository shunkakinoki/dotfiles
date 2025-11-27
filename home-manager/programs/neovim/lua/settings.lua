-- ====================================================================================
-- VIM OPTIONS
-- ====================================================================================
vim.opt.compatible = false
vim.opt.termsync = true
vim.opt.hidden = true
vim.opt.updatetime = 300
vim.opt.mouse = ""
vim.opt.inccommand = "nosplit"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.wrap = true
vim.opt.textwidth = 0
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.tabstop = 2
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 10
vim.opt.sidescrolloff = 10
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.smoothscroll = true
vim.opt.swapfile = false
vim.opt.backup = true
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("data") .. "undodir"
vim.opt.hlsearch = false
vim.opt.ignorecase = true
vim.opt.incsearch = true
vim.opt.ruler = true
vim.opt.wildmenu = true
vim.opt.autoread = true
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.colorcolumn = "80"
vim.opt.backspace = { "indent", "eol", "start" }
vim.opt.spelllang = { "en_us" }
vim.opt.laststatus = 2
vim.opt.cursorline = true
vim.opt.grepprg = "rg --vimgrep --smart-case --follow"
-- Background will be set automatically based on system theme
vim.opt.termguicolors = true
vim.opt.shortmess:append("c")
vim.opt.timeoutlen = 300
vim.opt.winborder = "none"

vim.hl.priorities.semantic_tokens = 10
vim.g.fugitive_legacy_commands = 0
