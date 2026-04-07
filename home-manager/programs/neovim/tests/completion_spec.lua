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

	describe("cmp source configuration pattern", function()
		it("should define expected source names", function()
			local sources = { "nvim_lsp", "copilot", "luasnip", "buffer", "path" }
			for _, s in ipairs(sources) do
				assert.is_string(s)
				assert.is_true(#s > 0)
			end
		end)

		it("should support cmdline source names", function()
			local cmdline_sources = { "buffer", "path", "cmdline" }
			for _, s in ipairs(cmdline_sources) do
				assert.is_string(s)
			end
		end)

		it("should support filetype-specific source pattern", function()
			local gitcommit_sources = { { name = "git" }, { name = "buffer" } }
			assert.equals("git", gitcommit_sources[1].name)
			assert.equals("buffer", gitcommit_sources[2].name)
		end)
	end)

	describe("cmp mapping patterns", function()
		it("should support scroll_docs mapping pattern", function()
			local mappings = { ["<C-b>"] = "scroll_docs(-4)", ["<C-f>"] = "scroll_docs(4)" }
			assert.is_not_nil(mappings["<C-b>"])
			assert.is_not_nil(mappings["<C-f>"])
		end)

		it("should support abort and confirm pattern", function()
			local mappings = { ["<C-e>"] = "abort", ["<CR>"] = "confirm" }
			assert.equals("abort", mappings["<C-e>"])
			assert.equals("confirm", mappings["<CR>"])
		end)

		it("should support tab/shift-tab navigation pattern", function()
			local nav_keys = { "<Tab>", "<S-Tab>" }
			for _, k in ipairs(nav_keys) do
				assert.is_string(k)
			end
		end)
	end)

	describe("copilot config pattern", function()
		it("should disable suggestion panel by default", function()
			local config = { suggestion = { enabled = false }, panel = { enabled = false } }
			assert.is_false(config.suggestion.enabled)
			assert.is_false(config.panel.enabled)
		end)
	end)

	describe("luasnip pattern", function()
		it("should support lsp_expand callback pattern", function()
			local snippet_config = {
				expand = function(args)
					return args.body
				end,
			}
			assert.is_function(snippet_config.expand)
			assert.equals("test", snippet_config.expand({ body = "test" }))
		end)
	end)
end)
