require("toggleterm").setup({
	direction = "horizontal",
	size = function(term)
		if term.direction == "horizontal" then
			return math.floor(vim.o.lines * 0.3)
		end
		return 20
	end,
	start_in_insert = true,
	shade_terminals = true,
	persist_size = true,
})
