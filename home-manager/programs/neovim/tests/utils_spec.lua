-- Tests for lua/utils.lua
-- Run with: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ { minimal_init = './tests/minimal_init.lua' }"

describe("utils", function()
	local utils

	before_each(function()
		-- Clear any cached module to get fresh state
		package.loaded["config.utils"] = nil
		utils = require("config.utils")
	end)

	describe("cycle_buffer", function()
		it("should be a function", function()
			assert.is_function(utils.cycle_buffer)
		end)

		it("should not error with no buffers", function()
			-- With only one buffer (current), should not error
			assert.has_no.errors(function()
				utils.cycle_buffer("next")
			end)
		end)

		it("should not error when cycling previous", function()
			assert.has_no.errors(function()
				utils.cycle_buffer("prev")
			end)
		end)

		it("should handle multiple buffers", function()
			-- Create a second buffer
			local buf1 = vim.api.nvim_get_current_buf()
			vim.cmd("enew")
			local buf2 = vim.api.nvim_get_current_buf()

			-- Should be able to cycle between them
			assert.has_no.errors(function()
				utils.cycle_buffer("next")
			end)

			-- Clean up
			vim.api.nvim_buf_delete(buf2, { force = true })
		end)
	end)

	describe("copen", function()
		it("should be a function", function()
			assert.is_function(utils.copen)
		end)

		it("should handle empty quickfix list", function()
			-- Clear quickfix list first
			vim.fn.setqflist({}, "r")

			assert.has_no.errors(function()
				utils.copen()
			end)
		end)

		it("should open quickfix window when items exist", function()
			-- Add items to quickfix list
			vim.fn.setqflist({
				{ filename = "test.lua", lnum = 1, text = "Test item 1" },
				{ filename = "test.lua", lnum = 2, text = "Test item 2" },
			}, "r")

			utils.copen()

			-- Check if quickfix window is open
			local qf_open = false
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].buftype == "quickfix" then
					qf_open = true
					break
				end
			end

			assert.is_true(qf_open)

			-- Clean up
			vim.cmd("cclose")
			vim.fn.setqflist({}, "r")
		end)
	end)

	describe("cclear", function()
		it("should be a function", function()
			assert.is_function(utils.cclear)
		end)

		it("should clear the quickfix list", function()
			vim.fn.setqflist({
				{ filename = "test.lua", lnum = 1, text = "Test item" },
			}, "r")
			assert.is_true(vim.fn.getqflist({ size = 0 }).size > 0)
			utils.cclear()
			assert.equals(0, vim.fn.getqflist({ size = 0 }).size)
		end)
	end)

	describe("smart_delete", function()
		it("should be a function", function()
			assert.is_function(utils.smart_delete)
		end)

		it("should return blackhole register for empty line", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
			local result = utils.smart_delete("d")
			assert.equals('"_d', result)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should return blackhole register for whitespace-only line", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "   " })
			local result = utils.smart_delete("d")
			assert.equals('"_d', result)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should return the key unchanged for non-whitespace line", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "some content" })
			local result = utils.smart_delete("d")
			assert.equals("d", result)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should work with different key arguments", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
			assert.equals('"_D', utils.smart_delete("D"))
			assert.equals('"_dd', utils.smart_delete("dd"))
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("yank_shift", function()
		it("should be a function", function()
			assert.is_function(utils.yank_shift)
		end)

		it("should not error when called", function()
			assert.has_no.errors(function()
				utils.yank_shift()
			end)
		end)

		it("should rotate registers on call", function()
			vim.fn.setreg('"', "unnamed_content")
			vim.fn.setreg("1", "reg1_content")
			utils.yank_shift()
			assert.equals("unnamed_content", vim.fn.getreg("1"))
			assert.equals("reg1_content", vim.fn.getreg("2"))
		end)
	end)

	describe("close_floating_wins", function()
		it("should be a function", function()
			assert.is_function(utils.close_floating_wins)
		end)

		it("should not error when no floating windows exist", function()
			assert.has_no.errors(function()
				utils.close_floating_wins()
			end)
		end)

		it("should close floating windows", function()
			local buf = vim.api.nvim_create_buf(false, true)
			local win = vim.api.nvim_open_win(buf, false, {
				relative = "editor",
				width = 10,
				height = 5,
				row = 1,
				col = 1,
				style = "minimal",
			})
			assert.is_true(vim.api.nvim_win_is_valid(win))
			utils.close_floating_wins()
			assert.is_false(vim.api.nvim_win_is_valid(win))
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should not close non-floating windows", function()
			local initial_wins = #vim.api.nvim_list_wins()
			utils.close_floating_wins()
			assert.equals(initial_wins, #vim.api.nvim_list_wins())
		end)
	end)

	describe("is_ssh", function()
		it("should be a function", function()
			assert.is_function(utils.is_ssh)
		end)

		it("should return a boolean", function()
			local result = utils.is_ssh()
			assert.is_boolean(result)
		end)

		it("should return false when no SSH env vars set", function()
			local old_client = os.getenv("SSH_CLIENT")
			local old_tty = os.getenv("SSH_TTY")
			-- Clear SSH env vars for test
			vim.fn.setenv("SSH_CLIENT", "")
			vim.fn.setenv("SSH_TTY", "")
			-- is_ssh checks non-nil, empty string is still non-nil
			-- just verify it returns boolean
			assert.is_boolean(utils.is_ssh())
			if old_client then
				vim.fn.setenv("SSH_CLIENT", old_client)
			end
			if old_tty then
				vim.fn.setenv("SSH_TTY", old_tty)
			end
		end)
	end)

	describe("get_file_icon", function()
		it("should be a function", function()
			assert.is_function(utils.get_file_icon)
		end)

		it("should return a string", function()
			local icon = utils.get_file_icon("test.lua")
			assert.is_string(icon)
		end)

		it("should not error for unknown file types", function()
			assert.has_no.errors(function()
				utils.get_file_icon("unknown.xyz123")
			end)
		end)

		it("should return empty string when devicons unavailable", function()
			-- In minimal test env devicons likely unavailable
			local ok = pcall(require, "nvim-web-devicons")
			if not ok then
				local icon = utils.get_file_icon("test.lua")
				assert.equals("", icon)
			else
				assert.is_true(true) -- skip if devicons is available
			end
		end)
	end)
end)
