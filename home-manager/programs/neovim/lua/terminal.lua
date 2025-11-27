local toggleterm = require("toggleterm")
local Terminal = require("toggleterm.terminal").Terminal

toggleterm.setup({
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

local secondary_term = Terminal:new({
	direction = "tab",
	count = 2,
	hidden = true,
	on_open = function(term)
		vim.cmd("startinsert!")
	end,
})

function ToggleSecondaryTerm()
	secondary_term:toggle()
end
