-- Keymaps for LSP actions in on_attach
local on_attach = function(client, bufnr)
	local opts = { buffer = bufnr, noremap = true, silent = true }
	vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
	vim.keymap.set("n", "ca", vim.lsp.buf.code_action, opts)
	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
end

-- Set up capabilities for nvim-cmp
-- Bridges the cmp completion capabilities to the Neovim LSP client.
-- From: https://github.com/hrsh7th/cmp-nvim-lsp
local capabilities = require("cmp_nvim_lsp").default_capabilities()

local function configure_servers()
	local servers = {
		gopls = {},
		vtsls = {},
		lua_ls = {
			settings = {
				Lua = {
					diagnostics = {
						globals = { "vim" },
					},
				},
			},
		},
		jsonls = {},
		bashls = {},
		dockerls = {},
		yamlls = {},
	}

	for name, config in pairs(servers) do
		config.on_attach = on_attach
		config.capabilities = capabilities
		vim.lsp.config(name, config)
	end
	vim.lsp.enable(vim.tbl_keys(servers))
end

configure_servers()

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
