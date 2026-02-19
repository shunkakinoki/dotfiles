-- Keymaps for LSP actions in on_attach
local on_attach = function(client, bufnr)
	local opts = { buffer = bufnr, noremap = true, silent = true }
	-- @keymap K: Show hover information
	vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	-- @keymap gd: Go to definition
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	-- @keymap gD: Go to declaration
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
	-- @keymap gi: Go to implementation
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
	-- @keymap gr: Find references
	vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
	-- @keymap <leader>D: Go to type definition
	vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)
	-- @keymap ca: Show code actions
	vim.keymap.set("n", "ca", vim.lsp.buf.code_action, opts)
	-- @keymap <leader>rn: Rename symbol
	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
	-- @keymap <C-k>: Show signature help (normal mode)
	vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
	-- @keymap <C-k>: Show signature help (insert mode)
	vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts)
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

-- Consolidated diagnostic configuration with virtual text, float, and signs
vim.diagnostic.config({
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	virtual_text = {
		spacing = 4,
		prefix = "●",
	},
	float = {
		border = "rounded",
		source = true,
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "",
			[vim.diagnostic.severity.WARN] = "",
			[vim.diagnostic.severity.INFO] = "",
			[vim.diagnostic.severity.HINT] = "󰌶",
		},
	},
})
