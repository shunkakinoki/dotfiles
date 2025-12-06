-- Tests for lua/utils.lua
-- Run with: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ { minimal_init = './tests/minimal_init.lua' }"

describe("utils", function()
	local utils

	before_each(function()
		-- Clear any cached module to get fresh state
		package.loaded["utils"] = nil
		utils = require("utils")
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
			-- Add items to quickfix list
			vim.fn.setqflist({
				{ filename = "test.lua", lnum = 1, text = "Test item" },
			}, "r")

			-- Verify it's not empty
			assert.is_true(vim.fn.getqflist({ size = 0 }).size > 0)

			-- Clear it
			utils.cclear()

			-- Verify it's empty
			assert.equals(0, vim.fn.getqflist({ size = 0 }).size)
		end)
	end)
end)
