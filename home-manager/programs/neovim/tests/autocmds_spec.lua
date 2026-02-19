-- Tests for lua/autocmds.lua
-- Verifies that autocommands are correctly configured

describe("autocmds", function()
	before_each(function()
		package.loaded["config.autocmds"] = nil
		require("config.autocmds")
	end)

	describe("augroup creation", function()
		local function augroup_exists(name)
			local ok, id = pcall(vim.api.nvim_get_autocmds, { group = name })
			return ok and id ~= nil
		end

		it("should create HighlightYank augroup", function()
			assert.is_true(augroup_exists("HighlightYank"))
		end)

		it("should create ResizeSplits augroup", function()
			assert.is_true(augroup_exists("ResizeSplits"))
		end)

		it("should create CheckTime augroup", function()
			assert.is_true(augroup_exists("CheckTime"))
		end)

		it("should create GitCommit augroup", function()
			assert.is_true(augroup_exists("GitCommit"))
		end)

		it("should create NewFile augroup", function()
			assert.is_true(augroup_exists("NewFile"))
		end)

		it("should create Help augroup", function()
			assert.is_true(augroup_exists("Help"))
		end)

		it("should create Git augroup", function()
			assert.is_true(augroup_exists("Git"))
		end)

		it("should create Fugitive augroup", function()
			assert.is_true(augroup_exists("Fugitive"))
		end)

		it("should create QuickfixHelp augroup", function()
			assert.is_true(augroup_exists("QuickfixHelp"))
		end)

		it("should create Markdown augroup", function()
			assert.is_true(augroup_exists("Markdown"))
		end)

		it("should create Terminal augroup", function()
			assert.is_true(augroup_exists("Terminal"))
		end)
	end)

	describe("autocmd events", function()
		local function has_autocmd_for_event(group, event)
			local autocmds = vim.api.nvim_get_autocmds({ group = group })
			for _, autocmd in ipairs(autocmds) do
				if autocmd.event == event then
					return true
				end
			end
			return false
		end

		it("should have TextYankPost autocmd for highlighting", function()
			assert.is_true(has_autocmd_for_event("HighlightYank", "TextYankPost"))
		end)

		it("should have VimResized autocmd for resize handling", function()
			assert.is_true(has_autocmd_for_event("ResizeSplits", "VimResized"))
		end)

		it("should have BufEnter autocmd for checktime", function()
			assert.is_true(has_autocmd_for_event("CheckTime", "BufEnter"))
		end)

		it("should have FileType autocmd for gitcommit", function()
			assert.is_true(has_autocmd_for_event("GitCommit", "FileType"))
		end)

		it("should have BufNewFile autocmd for parent dir creation", function()
			assert.is_true(has_autocmd_for_event("NewFile", "BufNewFile"))
		end)

		it("should have FileType autocmd for markdown", function()
			assert.is_true(has_autocmd_for_event("Markdown", "FileType"))
		end)

		it("should have TermOpen autocmd for terminal", function()
			assert.is_true(has_autocmd_for_event("Terminal", "TermOpen"))
		end)
	end)

	describe("highlight on yank", function()
		it("should trigger highlight.on_yank without error", function()
			assert.has_no.errors(function()
				vim.highlight.on_yank({ timeout = 1 })
			end)
		end)
	end)

	describe("nvim_create_autocmd API", function()
		it("should be able to create autocmds", function()
			local called = false
			local test_group = vim.api.nvim_create_augroup("TestAutocmd", { clear = true })
			vim.api.nvim_create_autocmd("BufEnter", {
				group = test_group,
				pattern = "*",
				callback = function()
					called = true
				end,
			})

			local autocmds = vim.api.nvim_get_autocmds({ group = test_group })
			assert.is_true(#autocmds > 0)

			vim.api.nvim_del_augroup_by_id(test_group)
		end)

		it("should be able to delete augroups", function()
			local test_group = vim.api.nvim_create_augroup("TestDelete", { clear = true })
			vim.api.nvim_del_augroup_by_id(test_group)

			local ok = pcall(vim.api.nvim_get_autocmds, { group = "TestDelete" })
			assert.is_false(ok)
		end)
	end)

	describe("filetype-specific settings", function()
		it("should set markdown options correctly when filetype is set", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.bo[buf].filetype = "markdown"

			vim.api.nvim_exec_autocmds("FileType", { pattern = "markdown" })

			assert.is_true(vim.opt_local.spell:get())
			assert.equals(80, vim.opt_local.textwidth:get())

			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should set gitcommit options correctly", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.bo[buf].filetype = "gitcommit"

			vim.api.nvim_exec_autocmds("FileType", { pattern = "gitcommit" })

			assert.is_true(vim.opt_local.spell:get())
			assert.equals(72, vim.opt_local.textwidth:get())

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)
