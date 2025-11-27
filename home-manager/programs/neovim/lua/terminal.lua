require("toggleterm").setup({
	direction = "float",
	open_mapping = [[<c-\>]],
	on_open = function(term)
		vim.cmd("startinsert!")
	end,
})
