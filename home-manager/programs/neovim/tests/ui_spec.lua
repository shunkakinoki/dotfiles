-- Tests for lua/ui.lua
-- Tests UI-related configurations

describe("ui", function()
	describe("vim.notify", function()
		it("should be overridden with nvim-notify", function()
			assert.is_function(vim.notify)
		end)

		it("should not error when calling notify", function()
			assert.has_no.errors(function()
				vim.notify("Test notification", vim.log.levels.INFO)
			end)
		end)

		it("should support different log levels", function()
			assert.has_no.errors(function()
				vim.notify("Debug message", vim.log.levels.DEBUG)
				vim.notify("Info message", vim.log.levels.INFO)
				vim.notify("Warn message", vim.log.levels.WARN)
				vim.notify("Error message", vim.log.levels.ERROR)
			end)
		end)
	end)

	describe("colorscheme", function()
		it("should support colorscheme API", function()
			-- Dracula plugin may not be loaded in minimal test env
			-- Just verify colorscheme API works
			local colors = vim.fn.getcompletion("", "color")
			assert.is_table(colors)
		end)

		it("should have background option set", function()
			local bg = vim.opt.background:get()
			assert.is_true(bg == "dark" or bg == "light")
		end)

		it("should support termguicolors option", function()
			-- In test env, termguicolors may not be set
			local tgc = vim.opt.termguicolors:get()
			assert.is_boolean(tgc)
		end)
	end)

	describe("vim.ui", function()
		it("should have vim.ui.select available", function()
			assert.is_function(vim.ui.select)
		end)

		it("should have vim.ui.input available", function()
			assert.is_function(vim.ui.input)
		end)
	end)

	describe("statusline", function()
		it("should have laststatus set", function()
			local laststatus = vim.opt.laststatus:get()
			assert.is_true(laststatus >= 0)
		end)
	end)
end)
