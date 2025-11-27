require("dressing").setup({ input = { insert_only = true } })

local notify = require("notify")
notify.setup({
	render = "compact",
	stages = "static",
})
vim.notify = notify

local section_b = { "branch", "diff", { "diagnostics", sources = { "nvim_workspace_diagnostic" } } }
local section_c = { "%=", { "filename", file_status = false, path = 1 } }
local lualine_config = {
	options = {
		theme = function()
			-- Dynamically determine theme based on background
			return vim.o.background == "dark" and "dracula" or "auto"
		end,
		component_separators = "",
		section_separators = "",
	},
	sections = {
		lualine_b = section_b,
		lualine_c = section_c,
	},
	inactive_sections = {
		lualine_c = section_c,
		lualine_x = { "location" },
	},
}
require("lualine").setup(lualine_config)

-- Auto theme switching based on system appearance
require("auto-dark-mode").setup({
	update_interval = 1000, -- Check for theme changes every second
	set_dark_mode = function()
		vim.api.nvim_set_option_value("background", "dark", {})
		vim.cmd("colorscheme dracula")
		-- Refresh lualine to update theme
		if package.loaded["lualine"] then
			require("lualine").setup(lualine_config)
		end
	end,
	set_light_mode = function()
		vim.api.nvim_set_option_value("background", "light", {})
		vim.cmd("colorscheme default")
		-- Refresh lualine to update theme
		if package.loaded["lualine"] then
			require("lualine").setup(lualine_config)
		end
	end,
})

require("nvim-tree").setup({
	view = {
		width = 30,
	},
	actions = {
		open_file = {
			quit_on_open = false,
		},
	},
	on_attach = function(bufnr)
		local api = require("nvim-tree.api")

		local function opts(desc)
			return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
		end

		-- @keymap l: Open file/folder (nvim-tree)
		vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
		-- @keymap <CR>: Open file/folder (nvim-tree)
		vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
		-- @keymap o: Open file/folder (nvim-tree)
		vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
		-- @keymap h: Close folder (nvim-tree)
		vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
		-- @keymap v: Open in vertical split (nvim-tree)
		vim.keymap.set("n", "v", api.node.open.vertical, opts("Open: Vertical Split"))
		-- @keymap s: Open in horizontal split (nvim-tree)
		vim.keymap.set("n", "s", api.node.open.horizontal, opts("Open: Horizontal Split"))
		-- @keymap t: Open in new tab (nvim-tree)
		vim.keymap.set("n", "t", api.node.open.tab, opts("Open: New Tab"))
		-- @keymap i: Open in horizontal split (nvim-tree)
		vim.keymap.set("n", "i", api.node.open.horizontal, opts("Open: Horizontal Split"))
		-- @keymap a: Add file/folder (nvim-tree)
		vim.keymap.set("n", "a", api.fs.create, opts("Create"))
		-- @keymap d: Delete file/folder (nvim-tree)
		vim.keymap.set("n", "d", api.fs.remove, opts("Delete"))
		-- @keymap r: Rename file/folder (nvim-tree)
		vim.keymap.set("n", "r", api.fs.rename, opts("Rename"))
		-- @keymap y: Copy absolute path (nvim-tree)
		vim.keymap.set("n", "y", api.fs.copy.absolute_path, opts("Copy Absolute Path"))
		-- @keymap Y: Copy relative path (nvim-tree)
		vim.keymap.set("n", "Y", api.fs.copy.relative_path, opts("Copy Relative Path"))
		-- @keymap c: Change directory (nvim-tree)
		vim.keymap.set("n", "c", api.tree.change_root_to_node, opts("CD"))
		-- @keymap u: Go to parent directory (nvim-tree)
		vim.keymap.set("n", "u", api.tree.change_root_to_parent, opts("Up"))
		-- @keymap q: Close tree (nvim-tree)
		vim.keymap.set("n", "q", api.tree.close, opts("Close"))
		-- @keymap R: Refresh tree (nvim-tree)
		vim.keymap.set("n", "R", api.tree.reload, opts("Refresh"))
		-- @keymap ?: Toggle help (nvim-tree)
		vim.keymap.set("n", "?", api.tree.toggle_help, opts("Help"))
		-- @keymap .: Run file command (nvim-tree)
		vim.keymap.set("n", ".", api.node.run.cmd, opts("Run Command"))
		-- @keymap <C-r>: Rename file/folder (nvim-tree)
		vim.keymap.set("n", "<C-r>", api.fs.rename_basename, opts("Rename: Basename"))
		-- @keymap <C-x>: Cut file/folder (nvim-tree)
		vim.keymap.set("n", "<C-x>", api.fs.cut, opts("Cut"))
		-- @keymap <C-c>: Copy file/folder (nvim-tree)
		vim.keymap.set("n", "<C-c>", api.fs.copy.node, opts("Copy"))
		-- @keymap <C-v>: Paste file/folder (nvim-tree)
		vim.keymap.set("n", "<C-v>", api.fs.paste, opts("Paste"))
		-- @keymap [c: Navigate to previous sibling (nvim-tree)
		vim.keymap.set("n", "[c", api.node.navigate.sibling.prev, opts("Prev Sibling"))
		-- @keymap ]c: Navigate to next sibling (nvim-tree)
		vim.keymap.set("n", "]c", api.node.navigate.sibling.next, opts("Next Sibling"))
		-- @keymap p: Preview file (nvim-tree)
		vim.keymap.set("n", "p", api.node.open.preview, opts("Open Preview"))
		-- @keymap <BS>: Close folder (nvim-tree)
		vim.keymap.set("n", "<BS>", api.node.navigate.parent_close, opts("Close Directory"))
		-- @keymap <Tab>: Open preview and keep focus (nvim-tree)
		vim.keymap.set("n", "<Tab>", api.node.open.preview, opts("Open Preview"))
		-- @keymap H: Toggle dotfiles (nvim-tree)
		vim.keymap.set("n", "H", api.tree.toggle_gitignore_filter, opts("Toggle Git Ignore"))
		-- @keymap I: Toggle dotfiles (nvim-tree)
		vim.keymap.set("n", "I", api.tree.toggle_hidden_filter, opts("Toggle Dotfiles"))
	end,
})

require("which-key").setup({})
require("fidget").setup({})
require("oil").setup({})
require("trouble").setup({})
require("sidekick").setup({})