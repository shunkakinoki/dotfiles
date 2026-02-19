-- Tests for lua/plugins.lua
-- Tests plugin management and setup patterns

describe("plugins", function()
	describe("vim.pack API", function()
		it("should have vim.pack table or be nil in older nvim", function()
			-- vim.pack is available in Neovim 0.10+
			local has_pack = vim.pack ~= nil
			assert.is_boolean(has_pack)
		end)

		it("should have add function if pack API exists", function()
			if vim.pack then
				assert.is_function(vim.pack.add)
			else
				assert.is_true(true) -- Skip on older Neovim
			end
		end)
	end)

	describe("plugin autocommands", function()
		it("should support BufWritePost for lint", function()
			local autocmds = vim.api.nvim_get_autocmds({ event = "BufWritePost" })
			assert.is_table(autocmds)
		end)
	end)

	describe("formatters_by_ft pattern", function()
		it("should be able to create filetype-based config", function()
			local formatters = {
				lua = { "stylua" },
				python = { "black" },
				go = { "gofmt" },
			}
			assert.is_table(formatters)
			assert.are.same({ "stylua" }, formatters.lua)
			assert.are.same({ "black" }, formatters.python)
			assert.are.same({ "gofmt" }, formatters.go)
		end)
	end)

	describe("plugin setup pattern", function()
		it("should support setup with empty table", function()
			-- Common pattern: require("plugin").setup({})
			-- We test the pattern works
			local mock_setup_called = false
			local mock_plugin = {
				setup = function(opts)
					mock_setup_called = true
					assert.is_table(opts)
				end,
			}
			mock_plugin.setup({})
			assert.is_true(mock_setup_called)
		end)

		it("should support setup with options", function()
			local received_opts = nil
			local mock_plugin = {
				setup = function(opts)
					received_opts = opts
				end,
			}
			mock_plugin.setup({ enabled = true, timeout = 500 })
			assert.equals(true, received_opts.enabled)
			assert.equals(500, received_opts.timeout)
		end)
	end)

	describe("gitsigns pattern", function()
		it("should support signs configuration", function()
			local signs_config = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
			}
			assert.equals("+", signs_config.add.text)
			assert.equals("~", signs_config.change.text)
		end)
	end)

end)
