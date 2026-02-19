-- AI integration for Neovim
-- Includes sidekick.nvim and opencode.nvim (opencode AI assistant integration)

-- ====================================================================================
-- SIDEKICK (AI workspace with chat, prompts, and actions)
-- From: https://github.com/folke/sidekick.nvim
-- ====================================================================================
require("sidekick").setup({})

-- ====================================================================================
-- SNACKS (Required for opencode.nvim)
-- From: https://github.com/folke/snacks.nvim
-- ====================================================================================
require("snacks").setup({
	input = {},
	picker = {},
	terminal = {},
})

-- ====================================================================================
-- OPENCODE.NVIM (opencode AI assistant integration)
-- From: https://github.com/NickvanDyke/opencode.nvim
-- ====================================================================================

-- Configuration options
---@type opencode.Opts
vim.g.opencode_opts = {
	-- Use default configuration
}

-- Required for opts.events.reload
vim.o.autoread = true

-- Keymaps for opencode
-- <C-a> - Ask opencode about current context
vim.keymap.set({ "n", "x" }, "<C-a>", function()
	require("opencode").ask("@this: ", { submit = true })
end, { desc = "Ask opencode" })

-- <C-x> - Execute opencode action from selection menu
vim.keymap.set({ "n", "x" }, "<C-x>", function()
	require("opencode").select()
end, { desc = "Execute opencode action…" })

-- <C-.> - Toggle opencode terminal
vim.keymap.set({ "n", "t" }, "<C-.>", function()
	require("opencode").toggle()
end, { desc = "Toggle opencode" })

-- Operator mode: add range to opencode prompt
vim.keymap.set({ "n", "x" }, "go", function()
	return require("opencode").operator("@this ")
end, { expr = true, desc = "Add range to opencode" })

vim.keymap.set("n", "goo", function()
	return require("opencode").operator("@this ") .. "_"
end, { expr = true, desc = "Add line to opencode" })

-- Scroll keymaps for opencode session
vim.keymap.set("n", "<S-C-u>", function()
	require("opencode").command("session.half.page.up")
end, { desc = "opencode half page up" })

vim.keymap.set("n", "<S-C-d>", function()
	require("opencode").command("session.half.page.down")
end, { desc = "opencode half page down" })

-- Remap increment/decrement since we use <C-a> and <C-x> for opencode
vim.keymap.set("n", "+", "<C-a>", { desc = "Increment", noremap = true })
vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement", noremap = true })
