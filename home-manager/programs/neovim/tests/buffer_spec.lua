-- Tests for buffer operations
-- Tests common buffer manipulation patterns used throughout config

describe("buffer", function()
	describe("creation and deletion", function()
		it("should create scratch buffer", function()
			local buf = vim.api.nvim_create_buf(false, true)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
			assert.is_true(vim.bo[buf].buftype == "nofile" or vim.bo[buf].buftype == "")
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should create listed buffer", function()
			local buf = vim.api.nvim_create_buf(true, false)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
			assert.is_true(vim.bo[buf].buflisted)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should delete buffer with force", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "modified content" })
			vim.api.nvim_buf_delete(buf, { force = true })
			assert.is_false(vim.api.nvim_buf_is_valid(buf))
		end)
	end)

	describe("content manipulation", function()
		it("should set and get buffer lines", function()
			local buf = vim.api.nvim_create_buf(false, true)
			local lines = { "line 1", "line 2", "line 3" }
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

			local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same(lines, result)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should append lines to buffer", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "first" })
			vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "second" })

			local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same({ "first", "second" }, result)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should replace specific lines", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c" })
			vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "replaced" })

			local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same({ "a", "replaced", "c" }, result)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("buffer options", function()
		it("should set buffer-local options", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.bo[buf].filetype = "lua"
			assert.equals("lua", vim.bo[buf].filetype)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should set modifiable option", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.bo[buf].modifiable = false
			assert.is_false(vim.bo[buf].modifiable)
			vim.bo[buf].modifiable = true
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should set readonly option", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.bo[buf].readonly = true
			assert.is_true(vim.bo[buf].readonly)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("buffer listing", function()
		it("should list all buffers", function()
			local bufs = vim.api.nvim_list_bufs()
			assert.is_table(bufs)
			assert.is_true(#bufs >= 1)
		end)

		it("should check if buffer is loaded", function()
			local buf = vim.api.nvim_create_buf(false, true)
			assert.is_true(vim.api.nvim_buf_is_loaded(buf))
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("buffer name", function()
		it("should set and get buffer name", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf, "test_buffer_name")
			local name = vim.api.nvim_buf_get_name(buf)
			assert.is_true(name:match("test_buffer_name") ~= nil)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("current buffer", function()
		it("should get current buffer", function()
			local buf = vim.api.nvim_get_current_buf()
			assert.is_number(buf)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
		end)

		it("should set current buffer", function()
			local new_buf = vim.api.nvim_create_buf(false, true)
			local original_buf = vim.api.nvim_get_current_buf()

			vim.api.nvim_set_current_buf(new_buf)
			assert.equals(new_buf, vim.api.nvim_get_current_buf())

			vim.api.nvim_set_current_buf(original_buf)
			vim.api.nvim_buf_delete(new_buf, { force = true })
		end)
	end)
end)
