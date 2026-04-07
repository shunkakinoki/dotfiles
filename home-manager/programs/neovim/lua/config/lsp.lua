-- Keymaps for LSP actions in on_attach
local on_attach = function(client, bufnr)
	local o = { buffer = bufnr, noremap = true, silent = true }
	-- @keymap K: Show hover information
	vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", o, { desc = "Hover information" }))
	-- @keymap gd: Go to definition
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", o, { desc = "Go to definition" }))
	-- @keymap gD: Go to declaration
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", o, { desc = "Go to declaration" }))
	-- @keymap gi: Go to implementation
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", o, { desc = "Go to implementation" }))
	-- @keymap gr: Find references
	vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", o, { desc = "Find references" }))
	-- @keymap <leader>D: Go to type definition
	vim.keymap.set(
		"n",
		"<leader>D",
		vim.lsp.buf.type_definition,
		vim.tbl_extend("force", o, { desc = "Type definition" })
	)
	-- @keymap ca: Show code actions
	vim.keymap.set("n", "ca", vim.lsp.buf.code_action, vim.tbl_extend("force", o, { desc = "Code actions" }))
	-- @keymap <leader>rn: Rename symbol
	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", o, { desc = "Rename symbol" }))
	-- @keymap <C-k>: Show signature help (normal mode)
	vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, vim.tbl_extend("force", o, { desc = "Signature help" }))
	-- @keymap <C-k>: Show signature help (insert mode)
	vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, vim.tbl_extend("force", o, { desc = "Signature help" }))
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
		perlpls = {},
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
