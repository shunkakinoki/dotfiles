-- Tests for lua/lsp.lua
-- Tests LSP configuration and diagnostics

describe("lsp", function()
	describe("vim.lsp API", function()
		it("should have vim.lsp.buf available", function()
			assert.is_table(vim.lsp.buf)
		end)

		it("should have hover function", function()
			assert.is_function(vim.lsp.buf.hover)
		end)

		it("should have definition function", function()
			assert.is_function(vim.lsp.buf.definition)
		end)

		it("should have declaration function", function()
			assert.is_function(vim.lsp.buf.declaration)
		end)

		it("should have implementation function", function()
			assert.is_function(vim.lsp.buf.implementation)
		end)

		it("should have references function", function()
			assert.is_function(vim.lsp.buf.references)
		end)

		it("should have type_definition function", function()
			assert.is_function(vim.lsp.buf.type_definition)
		end)

		it("should have code_action function", function()
			assert.is_function(vim.lsp.buf.code_action)
		end)

		it("should have rename function", function()
			assert.is_function(vim.lsp.buf.rename)
		end)

		it("should have signature_help function", function()
			assert.is_function(vim.lsp.buf.signature_help)
		end)
	end)

	describe("diagnostics", function()
		it("should have vim.diagnostic available", function()
			assert.is_table(vim.diagnostic)
		end)

		it("should have goto_next function", function()
			assert.is_function(vim.diagnostic.goto_next)
		end)

		it("should have goto_prev function", function()
			assert.is_function(vim.diagnostic.goto_prev)
		end)

		it("should have open_float function", function()
			assert.is_function(vim.diagnostic.open_float)
		end)

		it("should have get function", function()
			assert.is_function(vim.diagnostic.get)
		end)

		it("should have set function", function()
			assert.is_function(vim.diagnostic.set)
		end)

		it("should be able to get diagnostics for current buffer", function()
			local diags = vim.diagnostic.get(0)
			assert.is_table(diags)
		end)

		it("should have config function", function()
			assert.is_function(vim.diagnostic.config)
		end)

		it("should have diagnostic config set", function()
			local config = vim.diagnostic.config()
			assert.is_table(config)
		end)
	end)

	describe("diagnostic severity", function()
		it("should have ERROR severity", function()
			assert.is_number(vim.diagnostic.severity.ERROR)
		end)

		it("should have WARN severity", function()
			assert.is_number(vim.diagnostic.severity.WARN)
		end)

		it("should have INFO severity", function()
			assert.is_number(vim.diagnostic.severity.INFO)
		end)

		it("should have HINT severity", function()
			assert.is_number(vim.diagnostic.severity.HINT)
		end)
	end)
end)
