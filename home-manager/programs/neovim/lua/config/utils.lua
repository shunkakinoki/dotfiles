local M = {}

-- ====================================================================================
-- SMART DELETE FUNCTION
-- Avoids polluting registers with whitespace-only lines
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
function M.smart_delete(key)
	local line = vim.api.nvim_get_current_line()
	-- If the line is empty or contains only whitespace, delete to blackhole register
	if line:match("^%s*$") then
		return '"_' .. key
	end
	return key
end

-- ====================================================================================
-- YANK REGISTER ROTATION
-- Rotates registers 1-9 when yanking to preserve yank history
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
function M.yank_shift()
	-- Rotate registers 9 <- 8 <- ... <- 2 <- 1 <- "
	for i = 9, 2, -1 do
		local prev_content = vim.fn.getreg(tostring(i - 1))
		local prev_type = vim.fn.getregtype(tostring(i - 1))
		vim.fn.setreg(tostring(i), prev_content, prev_type)
	end
	-- Move unnamed register to register 1
	local unnamed_content = vim.fn.getreg('"')
	local unnamed_type = vim.fn.getregtype('"')
	vim.fn.setreg("1", unnamed_content, unnamed_type)
end

-- ====================================================================================
-- CLOSE FLOATING WINDOWS
-- Utility to close all floating windows
-- From: https://github.com/dmtrKovalenko/dotfiles
-- ====================================================================================
function M.close_floating_wins()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local config = vim.api.nvim_win_get_config(win)
			if config.relative ~= "" then
				vim.api.nvim_win_close(win, false)
			end
		end
	end
end

-- ====================================================================================
-- SSH DETECTION
-- Detect if running in SSH session for clipboard handling
-- ====================================================================================
function M.is_ssh()
	return os.getenv("SSH_CLIENT") ~= nil or os.getenv("SSH_TTY") ~= nil
end

-- ====================================================================================
-- FILE ICON RETRIEVAL
-- Get file icon using nvim-web-devicons if available
-- ====================================================================================
function M.get_file_icon(filename)
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if ok then
		local icon, _ = devicons.get_icon(filename, vim.fn.fnamemodify(filename, ":e"), { default = true })
		return icon or ""
	end
	return ""
end

-- ====================================================================================
-- BUFFER CYCLING
-- ====================================================================================
function M.cycle_buffer(direction)
	local current_buf = vim.api.nvim_get_current_buf()

	-- Get all loaded buffers (this includes buffers in windows and loaded but not visible)
	local buffer_set = {}
	local buffers = {}

	-- First, get buffers from windows (includes nvim-tree)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and not buffer_set[buf] then
			buffer_set[buf] = true
			table.insert(buffers, buf)
		end
	end

	-- Then add all other loaded buffers (files that aren't in windows)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and not buffer_set[buf] then
			buffer_set[buf] = true
			table.insert(buffers, buf)
		end
	end

	-- Ensure current buffer is in the list
	if not buffer_set[current_buf] then
		table.insert(buffers, current_buf)
		buffer_set[current_buf] = true
	end

	-- Need at least 2 buffers to cycle
	if #buffers < 2 then
		return
	end

	-- Find current buffer index
	local current_idx = nil
	for i, buf in ipairs(buffers) do
		if buf == current_buf then
			current_idx = i
			break
		end
	end

	-- This should never happen now, but safety check
	if not current_idx then
		current_idx = 1
	end

	-- Calculate next/previous index with wrapping
	local next_idx
	if direction == "next" then
		next_idx = current_idx + 1
		if next_idx > #buffers then
			next_idx = 1
		end
	else -- prev
		next_idx = current_idx - 1
		if next_idx < 1 then
			next_idx = #buffers
		end
	end

	-- Get target buffer
	local target_buf = buffers[next_idx]

	-- Safety check
	if not vim.api.nvim_buf_is_valid(target_buf) then
		return
	end

	-- Find window containing target buffer
	local target_win = nil
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target_buf then
			target_win = win
			break
		end
	end

	if target_win then
		-- Buffer is in a window, switch to that window
		vim.api.nvim_set_current_win(target_win)
	else
		-- Buffer not in any window, switch to it in current window
		vim.api.nvim_set_current_buf(target_buf)
	end
end

function M.copen()
	if vim.fn.getqflist({ size = 0 }).size > 1 then
		vim.cmd("copen")
	else
		vim.cmd("cclose")
	end
end

function M.cclear()
	vim.fn.setqflist({}, "r")
end

return M
