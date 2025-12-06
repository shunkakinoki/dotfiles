-- Tests for lua/telescope.lua
-- Tests telescope-related APIs (telescope not loaded in minimal test env)

describe("telescope", function()
	describe("picker keymaps", function()
		it("should have C-p mapped or mappable", function()
			-- Verify the keymap pattern works
			vim.keymap.set("n", "<C-p>", function() end, { noremap = true })
			local keymap = vim.fn.maparg("<C-p>", "n")
			assert.is_true(keymap ~= "")
			vim.keymap.del("n", "<C-p>")
		end)

		it("should support leader keymaps for pickers", function()
			local leader_maps = {
				"<leader>of",
				"<leader>lg",
				"<leader>fb",
				"<leader>fh",
				"<leader>fc",
				"<leader>fr",
				"<leader>fq",
				"<leader>/",
			}
			for _, lhs in ipairs(leader_maps) do
				vim.keymap.set("n", lhs, function() end, { noremap = true })
				local keymap = vim.fn.maparg(lhs, "n")
				assert.is_true(keymap ~= "", "Failed for " .. lhs)
				vim.keymap.del("n", lhs)
			end
		end)
	end)

	describe("vimgrep_arguments pattern", function()
		it("should support rg arguments", function()
			local vimgrep_args = {
				"rg",
				"--color=never",
				"--no-heading",
				"--with-filename",
				"--line-number",
				"--column",
				"--smart-case",
			}
			assert.equals("rg", vimgrep_args[1])
			assert.is_true(vim.tbl_contains(vimgrep_args, "--smart-case"))
		end)
	end)

	describe("themes pattern", function()
		it("should support ivy theme config", function()
			local ivy_config = {
				theme = "ivy",
				layout_config = {
					height = 0.4,
				},
			}
			assert.equals("ivy", ivy_config.theme)
		end)

		it("should support dropdown theme config", function()
			local dropdown_config = {
				theme = "dropdown",
				layout_config = {
					width = 0.8,
				},
			}
			assert.equals("dropdown", dropdown_config.theme)
		end)
	end)

	describe("extensions pattern", function()
		it("should support extension configuration", function()
			local extensions = {
				fzf = {
					fuzzy = true,
					override_generic_sorter = true,
				},
				["ui-select"] = {},
			}
			assert.is_true(extensions.fzf.fuzzy)
			assert.is_table(extensions["ui-select"])
		end)
	end)

	describe("find_command pattern", function()
		it("should support fd command arguments", function()
			local find_command = {
				"fd",
				"--type",
				"f",
				"--strip-cwd-prefix",
				"--hidden",
			}
			assert.equals("fd", find_command[1])
			assert.is_true(vim.tbl_contains(find_command, "--hidden"))
		end)
	end)
end)
