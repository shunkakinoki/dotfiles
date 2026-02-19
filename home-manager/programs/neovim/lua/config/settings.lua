-- ====================================================================================
-- VIM OPTIONS
-- ====================================================================================
vim.opt.compatible = false
vim.opt.termsync = true
vim.opt.hidden = true
vim.opt.updatetime = 300
vim.opt.mouse = "a"

-- ====================================================================================
-- SSH / OSC52 CLIPBOARD HANDLING
-- From: https://github.com/dmtrKovalenko/dotfiles
-- Uses OSC 52 protocol for clipboard when running over SSH
-- ====================================================================================
local function is_ssh()
	return os.getenv("SSH_CLIENT") ~= nil or os.getenv("SSH_TTY") ~= nil
end

if is_ssh() then
	-- Use OSC 52 for clipboard when in SSH session
	vim.g.clipboard = {
		name = "OSC 52",
		copy = {
			["+"] = require("vim.ui.clipboard.osc52").copy("+"),
			["*"] = require("vim.ui.clipboard.osc52").copy("*"),
		},
		paste = {
			["+"] = require("vim.ui.clipboard.osc52").paste("+"),
			["*"] = require("vim.ui.clipboard.osc52").paste("*"),
		},
	}
end
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
vim.opt.backupdir = vim.fn.stdpath("data") .. "/backup//"
vim.fn.mkdir(vim.fn.stdpath("data") .. "/backup", "p")
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("data") .. "/undodir"
vim.fn.mkdir(vim.fn.stdpath("data") .. "/undodir", "p")
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

-- ====================================================================================
-- VISIBLE WHITESPACE
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
vim.opt.list = true
vim.opt.listchars = {
	tab = "→ ",
	trail = "·",
	extends = "»",
	precedes = "«",
	nbsp = "␣",
}

-- ====================================================================================
-- DIAGNOSTIC DISPLAY SETTINGS
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
vim.diagnostic.config({
	virtual_text = {
		prefix = "●",
		spacing = 2,
	},
	signs = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = {
		border = "rounded",
		source = true,
	},
})
vim.opt.shortmess:append("c")
vim.opt.timeoutlen = 300
vim.opt.winborder = "none"
vim.opt.fillchars:append({ vert = " " })
-- Suppress deprecation warnings (temporary until plugins update)
vim.deprecate = function() end
vim.hl.priorities.semantic_tokens = 10
vim.g.fugitive_legacy_commands = 0
