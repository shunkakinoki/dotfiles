-- Tests for terminal functionality
-- Tests terminal API basics (plugins not loaded in minimal test env)

describe("terminal", function()
	describe("terminal API basics", function()
		it("should have termopen function available", function()
			assert.is_function(vim.fn.termopen)
		end)

		it("should be able to create terminal buffers", function()
			local buf = vim.api.nvim_create_buf(false, true)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should have TermOpen event", function()
			local autocmds = vim.api.nvim_get_autocmds({ event = "TermOpen" })
			assert.is_table(autocmds)
		end)

		it("should recognize terminal buftype", function()
			-- buftype=terminal can only be set by termopen, but we can check the option exists
			local buf = vim.api.nvim_create_buf(false, true)
			local buftype = vim.bo[buf].buftype
			assert.is_string(buftype)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("terminal window options", function()
		it("should be able to create floating window", function()
			local buf = vim.api.nvim_create_buf(false, true)
			local win = vim.api.nvim_open_win(buf, true, {
				relative = "editor",
				width = 80,
				height = 20,
				row = 5,
				col = 5,
				style = "minimal",
			})
			assert.is_true(vim.api.nvim_win_is_valid(win))
			vim.api.nvim_win_close(win, true)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)
