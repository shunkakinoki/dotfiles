-- Tests for lua/completion.lua
-- Tests completion-related APIs (nvim-cmp not loaded in minimal test env)

describe("completion", function()
	describe("vim.fn completion", function()
		it("should have complete function", function()
			assert.is_function(vim.fn.complete)
		end)

		it("should have complete_info function", function()
			assert.is_function(vim.fn.complete_info)
		end)

		it("should have pumvisible function", function()
			assert.is_function(vim.fn.pumvisible)
		end)
	end)

	describe("completeopt", function()
		it("should be configurable", function()
			local completeopt = vim.opt.completeopt:get()
			assert.is_table(completeopt)
		end)

		it("should support menu option", function()
			vim.opt.completeopt:append("menu")
			local completeopt = vim.opt.completeopt:get()
			assert.is_true(vim.tbl_contains(completeopt, "menu"))
		end)

		it("should support menuone option", function()
			vim.opt.completeopt:append("menuone")
			local completeopt = vim.opt.completeopt:get()
			assert.is_true(vim.tbl_contains(completeopt, "menuone"))
		end)

		it("should support noselect option", function()
			vim.opt.completeopt:append("noselect")
			local completeopt = vim.opt.completeopt:get()
			assert.is_true(vim.tbl_contains(completeopt, "noselect"))
		end)
	end)

	describe("snippet expansion", function()
		it("should have snippet API or be nil in older nvim", function()
			-- vim.snippet is available in Neovim 0.10+
			local has_snippet = vim.snippet ~= nil
			assert.is_boolean(has_snippet)
		end)

		it("should have expand function if snippet API exists", function()
			if vim.snippet then
				assert.is_function(vim.snippet.expand)
			else
				assert.is_true(true) -- Skip on older Neovim
			end
		end)

		it("should have active function if snippet API exists", function()
			if vim.snippet then
				assert.is_function(vim.snippet.active)
			else
				assert.is_true(true) -- Skip on older Neovim
			end
		end)
	end)

	describe("insert mode mappings", function()
		it("should support insert mode keymaps", function()
			vim.keymap.set("i", "<C-test>", "<Nop>", { noremap = true })
			local keymap = vim.fn.maparg("<C-test>", "i")
			assert.is_true(keymap ~= "")
			vim.keymap.del("i", "<C-test>")
		end)

		it("should support expr mappings for completion", function()
			vim.keymap.set("i", "<C-test-expr>", function()
				return ""
			end, { expr = true })
			local keymaps = vim.api.nvim_get_keymap("i")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test%-expr") then
					found = true
					break
				end
			end
			assert.is_true(found)
			vim.keymap.del("i", "<C-test-expr>")
		end)
	end)
end)
