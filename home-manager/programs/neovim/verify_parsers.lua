local ok, err = xpcall(function()
	local treesitter = require("config.treesitter")
	treesitter.install_configured_sync(600000)
	treesitter.verify_configured()
end, debug.traceback)

if not ok then
	vim.api.nvim_err_writeln("Treesitter parser verification failed:\n" .. err)
	vim.cmd("cquit 1")
end

print("All configured Treesitter parsers installed and loaded successfully")
vim.cmd("qall!")
