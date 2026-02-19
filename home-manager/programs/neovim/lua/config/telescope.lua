-- Fuzzy finder with extensible pickers for files, buffers, and more.
-- From: https://github.com/nvim-telescope/telescope.nvim
local telescope = require("telescope")
-- Theme helpers used by the dropdown/ivy pickers.
-- From: https://github.com/nvim-telescope/telescope.nvim
local telescope_themes = require("telescope.themes")
telescope.setup({
	defaults = {
		prompt_prefix = "   ",
		selection_caret = " ❯ ",
		entry_prefix = "   ",
		multi_icon = "+ ",
		path_display = { "filename_first" },
		vimgrep_arguments = {
			"rg",
			"--color=never",
			"--no-heading",
			"--with-filename",
			"--line-number",
			"--column",
			"--smart-case",
			"--sort=path",
		},
	},
	pickers = {
		find_files = {
			theme = "ivy",
		},
	},
	extensions = {
		fzf = {
			fuzzy = true,
			override_generic_sorter = true,
			override_file_sorter = true,
			case_mode = "smart_case",
		},
		["ui-select"] = {
			telescope_themes.get_dropdown(),
		},
	},
})
telescope.load_extension("gh")
telescope.load_extension("fzf")
telescope.load_extension("ui-select")

local function ivy(iopts)
	return telescope_themes.get_ivy(iopts)
end

-- Telescope builtin pickers used in the keymaps below.
-- From: https://github.com/nvim-telescope/telescope.nvim
local builtin = require("telescope.builtin")
local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

-- @keymap <C-p>: Find files (Telescope)
keymap("n", "<C-p>", function()
	builtin.find_files(ivy({
		find_command = {
			"fd",
			"--type",
			"f",
			"--strip-cwd-prefix",
			"--hidden",
		},
	}))
end, opts)

-- @keymap <leader>of: Open old files (Telescope)
keymap("n", "<leader>of", function()
	builtin.oldfiles(ivy({
		only_cwd = true,
	}))
end, opts)

-- @keymap <leader>lg: Live grep (Telescope)
keymap("n", "<leader>lg", function()
	builtin.live_grep(ivy())
end, opts)

-- @keymap <leader>fb: Find buffers (Telescope)
keymap("n", "<leader>fb", function()
	builtin.buffers(ivy())
end, opts)

-- @keymap <leader>fh: Find help tags (Telescope)
keymap("n", "<leader>fh", function()
	builtin.help_tags(ivy())
end, opts)

-- @keymap <leader>fc: Find commands (Telescope)
keymap("n", "<leader>fc", function()
	builtin.commands(ivy())
end, opts)

-- @keymap <leader>fr: Resume last Telescope search
keymap("n", "<leader>fr", function()
	builtin.resume(ivy())
end, opts)

-- @keymap <leader>fq: Find in quickfix (Telescope)
keymap("n", "<leader>fq", function()
	builtin.quickfix(ivy())
end, opts)

-- @keymap <leader>/: Fuzzy find in current buffer (Telescope)
keymap("n", "<leader>/", function()
	builtin.current_buffer_fuzzy_find(ivy())
end, opts)

-- @keymap <leader>ghi: Find GitHub issues (Telescope)
keymap("n", "<leader>ghi", function()
	telescope.extensions.gh.issues(ivy())
end, opts)
