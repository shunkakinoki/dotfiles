local lspconfig = require("lspconfig")

-- Keymaps for LSP actions in on_attach
local on_attach = function(client, bufnr)
	local opts = { buffer = bufnr, noremap = true, silent = true }
	vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
	vim.keymap.set("n", "ca", vim.lsp.buf.code_action, opts)
	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
end

-- Setup servers
lspconfig.gopls.setup({ on_attach = on_attach })
lspconfig.tsserver.setup({ on_attach = on_attach })
lspconfig.lua_ls.setup({
	on_attach = on_attach,
	settings = {
		Lua = {
			diagnostics = {
				globals = { "vim" },
			},
		},
	},
})
lspconfig.jsonls.setup({ on_attach = on_attach })
lspconfig.bashls.setup({ on_attach = on_attach })
lspconfig.dockerls.setup({ on_attach = on_attach })
lspconfig.yamlls.setup({ on_attach = on_attach })

-- setup diagnostics
vim.diagnostic.config({
	underline = true,
	update_in_insert = false,
	severity_sort = true,
})

-- set up diagnostic signs
local severity = vim.diagnostic.severity
local signs = {
	[severity.ERROR] = "",
	[severity.WARN] = "",
	[severity.INFO] = "",
	[severity.HINT] = "󰌶",
}
vim.diagnostic.config({
	signs = {
		text = signs,
	},
})
