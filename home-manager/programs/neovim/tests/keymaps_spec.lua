-- Tests for keymap functionality
-- Note: keymaps.lua requires plugins, so we test keymap API behavior instead

describe("keymaps", function()
	describe("leader key", function()
		it("should set leader key to space", function()
			assert.equals(" ", vim.g.mapleader)
		end)
	end)

	describe("vim.keymap API", function()
		it("should be able to set keymaps", function()
			local test_called = false
			vim.keymap.set("n", "<leader>test_km1", function()
				test_called = true
			end, { noremap = true, silent = true })

			local keymap_info = vim.fn.maparg("<leader>test_km1", "n")
			assert.is_true(keymap_info ~= "")

			vim.keymap.del("n", "<leader>test_km1")
		end)

		it("should be able to delete keymaps", function()
			vim.keymap.set("n", "<leader>test_km2", ":echo 'test'<CR>", { noremap = true })
			vim.keymap.del("n", "<leader>test_km2")

			local keymap_info = vim.fn.maparg("<leader>test_km2", "n")
			assert.equals("", keymap_info)
		end)

		it("should support silent option", function()
			vim.keymap.set("n", "<leader>test_km3", ":echo 'test'<CR>", { silent = true })

			local keymaps = vim.api.nvim_get_keymap("n")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test_km3") then
					found = true
					assert.equals(1, km.silent)
					break
				end
			end
			assert.is_true(found)

			vim.keymap.del("n", "<leader>test_km3")
		end)

		it("should support noremap option", function()
			vim.keymap.set("n", "<leader>test_km4", ":echo 'test'<CR>", { noremap = true })

			local keymaps = vim.api.nvim_get_keymap("n")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test_km4") then
					found = true
					assert.equals(1, km.noremap)
					break
				end
			end
			assert.is_true(found)

			vim.keymap.del("n", "<leader>test_km4")
		end)

		it("should be able to create buffer-local keymaps", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)

			vim.keymap.set("n", "<leader>test_buf_km", ":echo 'test'<CR>", {
				buffer = buf,
				noremap = true,
			})

			local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test_buf_km") then
					found = true
					break
				end
			end

			assert.is_true(found)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should support function callbacks", function()
			local callback_executed = false
			vim.keymap.set("n", "<leader>test_fn", function()
				callback_executed = true
			end, { noremap = true })

			local keymaps = vim.api.nvim_get_keymap("n")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test_fn") then
					found = true
					assert.is_function(km.callback)
					break
				end
			end
			assert.is_true(found)

			vim.keymap.del("n", "<leader>test_fn")
		end)

		it("should support multiple modes", function()
			vim.keymap.set({ "n", "v" }, "<leader>test_multi", ":echo 'test'<CR>", { noremap = true })

			local n_keymap = vim.fn.maparg("<leader>test_multi", "n")
			local v_keymap = vim.fn.maparg("<leader>test_multi", "v")

			assert.is_true(n_keymap ~= "")
			assert.is_true(v_keymap ~= "")

			vim.keymap.del({ "n", "v" }, "<leader>test_multi")
		end)
	end)

	describe("keymap execution", function()
		it("should execute keymap action via feedkeys", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)

			vim.keymap.set("n", "<leader>test_exec", function()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "executed" })
			end, { buffer = buf })

			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>test_exec", true, false, true), "x", false)

			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same({ "executed" }, lines)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)
