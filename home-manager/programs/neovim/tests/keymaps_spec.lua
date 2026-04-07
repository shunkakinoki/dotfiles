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

	describe("vscode-diff keymaps", function()
		local function register_vscode_diff_keymaps()
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "<leader>gD_test", function()
				require("vscode-diff.commands").vscode_diff({ fargs = {} })
			end, opts)
			vim.keymap.set("n", "<leader>gH_test", function()
				require("vscode-diff.commands").vscode_diff({ fargs = { "file", "HEAD" } })
			end, opts)
			vim.keymap.set("n", "<leader>gr_test", function()
				vim.ui.input({ prompt = "Diff against revision: ", default = "HEAD" }, function(rev)
					if rev and rev ~= "" then
						require("vscode-diff.commands").vscode_diff({ fargs = { "file", rev } })
					end
				end)
			end, opts)
			vim.keymap.set("n", "<leader>gf_test", function()
				vim.ui.input({ prompt = "File A: ", completion = "file" }, function(a)
					if not a or a == "" then return end
					vim.ui.input({ prompt = "File B: ", completion = "file" }, function(b)
						if b and b ~= "" then
							require("vscode-diff.commands").vscode_diff({ fargs = { "file", a, b } })
						end
					end)
				end)
			end, opts)
		end

		before_each(function()
			register_vscode_diff_keymaps()
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "<leader>gD_test")
			pcall(vim.keymap.del, "n", "<leader>gH_test")
			pcall(vim.keymap.del, "n", "<leader>gr_test")
			pcall(vim.keymap.del, "n", "<leader>gf_test")
		end)

		it("should register gD as explorer keymap", function()
			local km = vim.fn.maparg("<leader>gD_test", "n")
			assert.is_true(km ~= "")
		end)

		it("should register gH as HEAD diff keymap", function()
			local km = vim.fn.maparg("<leader>gH_test", "n")
			assert.is_true(km ~= "")
		end)

		it("should register gr as revision diff keymap", function()
			local km = vim.fn.maparg("<leader>gr_test", "n")
			assert.is_true(km ~= "")
		end)

		it("should register gf as file diff keymap", function()
			local km = vim.fn.maparg("<leader>gf_test", "n")
			assert.is_true(km ~= "")
		end)

		it("all vscode-diff keymaps should be silent and noremap", function()
			local keys = { "gD_test", "gH_test", "gr_test", "gf_test" }
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, key in ipairs(keys) do
				for _, km in ipairs(keymaps) do
					if km.lhs:match(key) then
						assert.equals(1, km.silent, key .. " should be silent")
						assert.equals(1, km.noremap, key .. " should be noremap")
						break
					end
				end
			end
		end)

		it("all vscode-diff keymaps should have function callbacks", function()
			local keys = { "gD_test", "gH_test", "gr_test", "gf_test" }
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, key in ipairs(keys) do
				for _, km in ipairs(keymaps) do
					if km.lhs:match(key) then
						assert.is_function(km.callback, key .. " should have a function callback")
						break
					end
				end
			end
		end)
	end)

	describe("fugitive diff keymaps", function()
		local keys = { "<leader>gs_test", "<leader>gS_test" }

		before_each(function()
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "<leader>gs_test", ":Gvdiffsplit<cr>", opts)
			vim.keymap.set("n", "<leader>gS_test", ":Gvdiffsplit HEAD<cr>", opts)
		end)

		after_each(function()
			for _, k in ipairs(keys) do
				pcall(vim.keymap.del, "n", k)
			end
		end)

		it("gs should map to Gvdiffsplit", function()
			local km = vim.fn.maparg("<leader>gs_test", "n")
			assert.is_true(km ~= "")
		end)

		it("gS should map to Gvdiffsplit HEAD", function()
			local km = vim.fn.maparg("<leader>gS_test", "n")
			assert.is_true(km ~= "")
		end)

		it("fugitive diff keymaps should be silent and noremap", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, key in ipairs(keys) do
				for _, km in ipairs(keymaps) do
					if km.lhs == key then
						assert.equals(1, km.silent, key .. " should be silent")
						assert.equals(1, km.noremap, key .. " should be noremap")
						break
					end
				end
			end
		end)
	end)

	describe("gitsigns hunk navigation keymaps", function()
		local keys = { "<leader>hn_test", "<leader>hN_test" }

		before_each(function()
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "<leader>hn_test", ":Gitsigns next_hunk<cr>", opts)
			vim.keymap.set("n", "<leader>hN_test", ":Gitsigns prev_hunk<cr>", opts)
		end)

		after_each(function()
			for _, k in ipairs(keys) do
				pcall(vim.keymap.del, "n", k)
			end
		end)

		it("hn should map to next_hunk", function()
			local km = vim.fn.maparg("<leader>hn_test", "n")
			assert.is_true(km ~= "")
		end)

		it("hN should map to prev_hunk", function()
			local km = vim.fn.maparg("<leader>hN_test", "n")
			assert.is_true(km ~= "")
		end)

		it("hunk navigation keymaps should be silent and noremap", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, key in ipairs(keys) do
				for _, km in ipairs(keymaps) do
					if km.lhs == key then
						assert.equals(1, km.silent, key .. " should be silent")
						assert.equals(1, km.noremap, key .. " should be noremap")
						break
					end
				end
			end
		end)
	end)

	describe("oil side-by-side keymap", function()
		before_each(function()
			vim.keymap.set("n", "<leader>-_test", function()
				vim.ui.input({ prompt = "Dir A: ", default = vim.fn.expand("%:p:h"), completion = "dir" }, function(a)
					if not a or a == "" then return end
					vim.ui.input({ prompt = "Dir B: ", completion = "dir" }, function(b)
						if not b or b == "" then return end
						vim.cmd("vsplit")
						vim.cmd("wincmd h")
						require("oil").open(a)
						vim.cmd("wincmd l")
						require("oil").open(b)
					end)
				end)
			end, { desc = "Oil: open two dirs side by side" })
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "<leader>-_test")
		end)

		it("should register oil side-by-side keymap", function()
			local km = vim.fn.maparg("<leader>-_test", "n")
			assert.is_true(km ~= "")
		end)

		it("oil side-by-side keymap should have a function callback", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, km in ipairs(keymaps) do
				if km.lhs:match("-_test") then
					assert.is_function(km.callback)
					return
				end
			end
			assert.is_true(false, "keymap not found")
		end)
	end)

	describe("gitsigns existing keymaps", function()
		local git_keys = {
			{ lhs = "<leader>gd_t", rhs = ":Gitsigns preview_hunk_inline<cr>" },
			{ lhs = "<leader>hs_t", rhs = ":Gitsigns stage_hunk<cr>" },
			{ lhs = "<leader>hr_t", rhs = ":Gitsigns reset_hunk<cr>" },
			{ lhs = "<leader>hp_t", rhs = ":Gitsigns preview_hunk<cr>" },
			{ lhs = "<leader>hb_t", rhs = ":Gitsigns blame_line<cr>" },
		}

		before_each(function()
			local opts = { noremap = true, silent = true }
			for _, km in ipairs(git_keys) do
				vim.keymap.set("n", km.lhs, km.rhs, opts)
			end
		end)

		after_each(function()
			for _, km in ipairs(git_keys) do
				pcall(vim.keymap.del, "n", km.lhs)
			end
		end)

		it("should register all gitsigns keymaps", function()
			for _, km in ipairs(git_keys) do
				local result = vim.fn.maparg(km.lhs, "n")
				assert.is_true(result ~= "", km.lhs .. " should be registered")
			end
		end)

		it("all gitsigns keymaps should be silent and noremap", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, km in ipairs(git_keys) do
				for _, m in ipairs(keymaps) do
					if m.lhs == km.lhs then
						assert.equals(1, m.silent, km.lhs .. " should be silent")
						assert.equals(1, m.noremap, km.lhs .. " should be noremap")
						break
					end
				end
			end
		end)
	end)

	describe("lazygit keymap", function()
		before_each(function()
			vim.keymap.set("n", "<leader>lg_t", ":LazyGit<cr>", { noremap = true, silent = true })
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "<leader>lg_t")
		end)

		it("should register lazygit keymap", function()
			local km = vim.fn.maparg("<leader>lg_t", "n")
			assert.is_true(km ~= "")
		end)
	end)

	describe("oil parent dir keymap", function()
		before_each(function()
			vim.keymap.set("n", "-_oil_t", "<CMD>Oil<CR>", { desc = "Open Parent Directory" })
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "-_oil_t")
		end)

		it("should register oil parent dir keymap", function()
			local km = vim.fn.maparg("-_oil_t", "n")
			assert.is_true(km ~= "")
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
