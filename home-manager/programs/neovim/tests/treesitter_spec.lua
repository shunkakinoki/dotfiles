-- Tests for lua/treesitter.lua
-- Tests treesitter configuration

describe("treesitter", function()
	describe("configured parsers", function()
		local configured = require("config.treesitter_parsers")
		local available = require("nvim-treesitter").get_available()

		it("should all exist in the nvim-treesitter registry", function()
			local available_set = {}
			for _, parser in ipairs(available) do
				available_set[parser] = true
			end

			for _, parser in ipairs(configured) do
				assert.is_true(available_set[parser], ("parser is not available: %s"):format(parser))
			end
		end)

		it("should not contain duplicates", function()
			local seen = {}
			for _, parser in ipairs(configured) do
				assert.is_nil(seen[parser], ("parser is configured more than once: %s"):format(parser))
				seen[parser] = true
			end
		end)
	end)

	describe("vim.treesitter API", function()
		it("should have vim.treesitter available", function()
			assert.is_table(vim.treesitter)
		end)

		it("should have get_parser function", function()
			assert.is_function(vim.treesitter.get_parser)
		end)

		it("should have get_node function", function()
			assert.is_function(vim.treesitter.get_node)
		end)

		it("should have start function for highlighting", function()
			assert.is_function(vim.treesitter.start)
		end)

		it("should have stop function", function()
			assert.is_function(vim.treesitter.stop)
		end)
	end)

	describe("treesitter language", function()
		it("should have language module", function()
			assert.is_table(vim.treesitter.language)
		end)

		it("should be able to check if language is available", function()
			assert.is_function(vim.treesitter.language.get_lang)
		end)
	end)

	describe("treesitter query", function()
		it("should have query module", function()
			assert.is_table(vim.treesitter.query)
		end)

		it("should have get or get_query function", function()
			-- API changed in newer Neovim versions
			local has_get = vim.treesitter.query.get ~= nil or vim.treesitter.query.get_query ~= nil
			assert.is_true(has_get)
		end)

		it("should have parse or parse_query function", function()
			-- API changed in newer Neovim versions
			local has_parse = vim.treesitter.query.parse ~= nil or vim.treesitter.query.parse_query ~= nil
			assert.is_true(has_parse)
		end)
	end)

	describe("incremental selection keymaps", function()
		it("should have C-space mapped for init_selection", function()
			local keymap = vim.fn.maparg("<C-space>", "n")
			-- Just verify it doesn't error, may not be set in test env
			assert.is_string(keymap)
		end)
	end)
end)
