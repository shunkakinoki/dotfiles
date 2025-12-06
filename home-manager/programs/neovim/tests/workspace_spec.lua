-- Tests for lua/workspace.lua
-- Tests workspace-specific settings and commands

describe("workspace", function()
	before_each(function()
		package.loaded["workspace"] = nil
		require("workspace")
	end)

	describe("user commands", function()
		it("should define WorkspaceRoot command", function()
			local commands = vim.api.nvim_get_commands({})
			assert.is_not_nil(commands.WorkspaceRoot)
		end)

		it("WorkspaceRoot command should not error", function()
			assert.has_no.errors(function()
				vim.cmd("WorkspaceRoot")
			end)
		end)
	end)

	describe("indentation autocmd", function()
		it("should set shiftwidth to 2 for new buffers", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.bo[buf].filetype = "lua"

			vim.api.nvim_exec_autocmds("FileType", { pattern = "lua" })

			assert.equals(2, vim.opt_local.shiftwidth:get())

			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should set tabstop to 2 for new buffers", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)
			vim.bo[buf].filetype = "javascript"

			vim.api.nvim_exec_autocmds("FileType", { pattern = "javascript" })

			assert.equals(2, vim.opt_local.tabstop:get())

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("getcwd", function()
		it("should return current working directory", function()
			local cwd = vim.fn.getcwd()
			assert.is_string(cwd)
			assert.is_true(#cwd > 0)
		end)
	end)
end)
