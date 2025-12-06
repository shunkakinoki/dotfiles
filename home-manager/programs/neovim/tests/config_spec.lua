-- Tests for Neovim configuration loading
-- Verifies that the config modules can be loaded without errors

describe("config", function()
	describe("settings", function()
		it("should load without errors", function()
			assert.has_no.errors(function()
				package.loaded["settings"] = nil
				require("settings")
			end)
		end)
	end)

	describe("keymaps", function()
		it("should define leader key", function()
			assert.equals(" ", vim.g.mapleader)
		end)
	end)

	describe("nvim API", function()
		it("should have working buffer API", function()
			local buf = vim.api.nvim_get_current_buf()
			assert.is_number(buf)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
		end)

		it("should have working window API", function()
			local win = vim.api.nvim_get_current_win()
			assert.is_number(win)
			assert.is_true(vim.api.nvim_win_is_valid(win))
		end)

		it("should be able to create and manipulate buffers", function()
			-- Create a new buffer
			local buf = vim.api.nvim_create_buf(false, true)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))

			-- Set lines
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello", "world" })
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same({ "hello", "world" }, lines)

			-- Clean up
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should handle feedkeys for keymap testing", function()
			-- Create a scratch buffer for testing
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)

			-- Enter insert mode and type
			vim.api.nvim_feedkeys("itest", "x", false)
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

			local line = vim.api.nvim_get_current_line()
			assert.equals("test", line)

			-- Clean up
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)
