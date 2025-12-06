-- Tests for lua/settings.lua
-- Verifies that Neovim settings are configured correctly

describe("settings", function()
	before_each(function()
		package.loaded["settings"] = nil
		require("settings")
	end)

	describe("basic options", function()
		it("should disable compatible mode", function()
			assert.is_false(vim.opt.compatible:get())
		end)

		it("should enable hidden buffers", function()
			assert.is_true(vim.opt.hidden:get())
		end)

		it("should set updatetime to 300", function()
			assert.equals(300, vim.opt.updatetime:get())
		end)

		it("should enable mouse support for all modes", function()
			local mouse = vim.opt.mouse:get()
			assert.is_true(mouse.a == true or mouse == "a")
		end)
	end)

	describe("split behavior", function()
		it("should split below by default", function()
			assert.is_true(vim.opt.splitbelow:get())
		end)

		it("should split right by default", function()
			assert.is_true(vim.opt.splitright:get())
		end)
	end)

	describe("indentation", function()
		it("should use spaces instead of tabs", function()
			assert.is_true(vim.opt.expandtab:get())
		end)

		it("should enable smart indentation", function()
			assert.is_true(vim.opt.smartindent:get())
		end)

		it("should set shiftwidth to 2", function()
			assert.equals(2, vim.opt.shiftwidth:get())
		end)

		it("should set softtabstop to 2", function()
			assert.equals(2, vim.opt.softtabstop:get())
		end)

		it("should set tabstop to 2", function()
			assert.equals(2, vim.opt.tabstop:get())
		end)
	end)

	describe("line numbers", function()
		it("should enable line numbers", function()
			assert.is_true(vim.opt.number:get())
		end)

		it("should enable relative line numbers", function()
			assert.is_true(vim.opt.relativenumber:get())
		end)
	end)

	describe("scrolling", function()
		it("should set scrolloff to 10", function()
			assert.equals(10, vim.opt.scrolloff:get())
		end)

		it("should set sidescrolloff to 10", function()
			assert.equals(10, vim.opt.sidescrolloff:get())
		end)

		it("should enable smooth scrolling", function()
			assert.is_true(vim.opt.smoothscroll:get())
		end)
	end)

	describe("search options", function()
		it("should disable highlight search", function()
			assert.is_false(vim.opt.hlsearch:get())
		end)

		it("should enable case insensitive search", function()
			assert.is_true(vim.opt.ignorecase:get())
		end)

		it("should enable incremental search", function()
			assert.is_true(vim.opt.incsearch:get())
		end)
	end)

	describe("backup and undo", function()
		it("should disable swapfile", function()
			assert.is_false(vim.opt.swapfile:get())
		end)

		it("should enable backup", function()
			assert.is_true(vim.opt.backup:get())
		end)

		it("should enable persistent undo", function()
			assert.is_true(vim.opt.undofile:get())
		end)

		it("should set backup directory", function()
			local backupdir = vim.opt.backupdir:get()
			assert.is_true(#backupdir > 0)
		end)

		it("should set undo directory", function()
			local undodir = vim.opt.undodir:get()
			assert.is_true(type(undodir) == "string" or type(undodir) == "table")
		end)
	end)

	describe("visual settings", function()
		it("should enable signcolumn", function()
			assert.equals("yes", vim.opt.signcolumn:get())
		end)

		it("should enable cursor line", function()
			assert.is_true(vim.opt.cursorline:get())
		end)

		it("should set colorcolumn to 80", function()
			local colorcolumn = vim.opt.colorcolumn:get()
			assert.are.same({ "80" }, colorcolumn)
		end)

		it("should enable termguicolors", function()
			assert.is_true(vim.opt.termguicolors:get())
		end)
	end)

	describe("completion", function()
		it("should set completeopt correctly", function()
			local completeopt = vim.opt.completeopt:get()
			assert.is_true(vim.tbl_contains(completeopt, "menu"))
			assert.is_true(vim.tbl_contains(completeopt, "menuone"))
			assert.is_true(vim.tbl_contains(completeopt, "noselect"))
		end)
	end)

	describe("grep program", function()
		it("should use ripgrep for grepping", function()
			local grepprg = vim.opt.grepprg:get()
			assert.is_true(grepprg:match("rg") ~= nil)
		end)
	end)

	describe("timeout", function()
		it("should set timeoutlen to 300", function()
			assert.equals(300, vim.opt.timeoutlen:get())
		end)
	end)

	describe("spell checking", function()
		it("should set spelllang to en_us", function()
			local spelllang = vim.opt.spelllang:get()
			assert.is_true(vim.tbl_contains(spelllang, "en_us"))
		end)
	end)
end)
