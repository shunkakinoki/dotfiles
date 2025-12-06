-- Tests for window operations
-- Tests common window manipulation patterns used throughout config

describe("window", function()
	describe("creation and deletion", function()
		it("should create new window with split", function()
			local original_win = vim.api.nvim_get_current_win()
			vim.cmd("split")
			local new_win = vim.api.nvim_get_current_win()

			assert.is_not.equals(original_win, new_win)
			assert.is_true(vim.api.nvim_win_is_valid(new_win))

			vim.api.nvim_win_close(new_win, true)
		end)

		it("should create new window with vsplit", function()
			local original_win = vim.api.nvim_get_current_win()
			vim.cmd("vsplit")
			local new_win = vim.api.nvim_get_current_win()

			assert.is_not.equals(original_win, new_win)
			assert.is_true(vim.api.nvim_win_is_valid(new_win))

			vim.api.nvim_win_close(new_win, true)
		end)

		it("should close window", function()
			vim.cmd("split")
			local win_to_close = vim.api.nvim_get_current_win()
			vim.api.nvim_win_close(win_to_close, true)

			assert.is_false(vim.api.nvim_win_is_valid(win_to_close))
		end)
	end)

	describe("window listing", function()
		it("should list all windows", function()
			local wins = vim.api.nvim_list_wins()
			assert.is_table(wins)
			assert.is_true(#wins >= 1)
		end)

		it("should list windows in current tabpage", function()
			local wins = vim.api.nvim_tabpage_list_wins(0)
			assert.is_table(wins)
			assert.is_true(#wins >= 1)
		end)
	end)

	describe("window buffer", function()
		it("should get buffer in window", function()
			local win = vim.api.nvim_get_current_win()
			local buf = vim.api.nvim_win_get_buf(win)
			assert.is_number(buf)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
		end)

		it("should set buffer in window", function()
			local win = vim.api.nvim_get_current_win()
			local new_buf = vim.api.nvim_create_buf(false, true)
			local original_buf = vim.api.nvim_win_get_buf(win)

			vim.api.nvim_win_set_buf(win, new_buf)
			assert.equals(new_buf, vim.api.nvim_win_get_buf(win))

			vim.api.nvim_win_set_buf(win, original_buf)
			vim.api.nvim_buf_delete(new_buf, { force = true })
		end)
	end)

	describe("window options", function()
		it("should set window-local options", function()
			local win = vim.api.nvim_get_current_win()
			local original_number = vim.wo[win].number

			vim.wo[win].number = not original_number
			assert.equals(not original_number, vim.wo[win].number)

			vim.wo[win].number = original_number
		end)

		it("should set cursorline option", function()
			local win = vim.api.nvim_get_current_win()
			vim.wo[win].cursorline = true
			assert.is_true(vim.wo[win].cursorline)
		end)
	end)

	describe("window dimensions", function()
		it("should get window height", function()
			local win = vim.api.nvim_get_current_win()
			local height = vim.api.nvim_win_get_height(win)
			assert.is_number(height)
			assert.is_true(height > 0)
		end)

		it("should get window width", function()
			local win = vim.api.nvim_get_current_win()
			local width = vim.api.nvim_win_get_width(win)
			assert.is_number(width)
			assert.is_true(width > 0)
		end)

		it("should set window height", function()
			vim.cmd("split")
			local win = vim.api.nvim_get_current_win()
			local target_height = 10

			vim.api.nvim_win_set_height(win, target_height)
			assert.equals(target_height, vim.api.nvim_win_get_height(win))

			vim.api.nvim_win_close(win, true)
		end)
	end)

	describe("window cursor", function()
		it("should get cursor position", function()
			local win = vim.api.nvim_get_current_win()
			local pos = vim.api.nvim_win_get_cursor(win)
			assert.is_table(pos)
			assert.equals(2, #pos)
			assert.is_number(pos[1])
			assert.is_number(pos[2])
		end)

		it("should set cursor position", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
			vim.api.nvim_set_current_buf(buf)

			local win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_cursor(win, { 2, 3 })

			local pos = vim.api.nvim_win_get_cursor(win)
			assert.equals(2, pos[1])
			assert.equals(3, pos[2])

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)
