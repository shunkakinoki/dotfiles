---Set workspace-specific helpers and defaults.
---@return nil
local M = {}

local function setup()
	-- Ensure projects default to 2-space indents.
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "*",
		callback = function()
			vim.opt_local.shiftwidth = 2
			vim.opt_local.tabstop = 2
		end,
	})

	vim.api.nvim_create_user_command("WorkspaceRoot", function()
		local root = vim.fn.getcwd()
		vim.notify("Workspace root: " .. root, vim.log.levels.INFO)
	end, { desc = "Show active workspace root directory" })
end

setup()

return M
