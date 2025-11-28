-- Manage Neovim-hosted terminals with floating/split layouts.
-- From: https://github.com/akinsho/toggleterm.nvim
local toggleterm = require("toggleterm")
-- Expose the toggleterm terminal constructor for custom instances.
-- From: https://github.com/akinsho/toggleterm.nvim
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

local function create_term(count)
	return Terminal:new({
		direction = "horizontal",
		count = count,
		hidden = true,
		on_open = function()
			vim.cmd("startinsert!")
		end,
	})
end

local term_sequence = { 1, 2 }
local terms = {
	[1] = create_term(1),
	[2] = create_term(2),
}
local current_index = 1

local function index_of(count)
	for idx, value in ipairs(term_sequence) do
		if value == count then
			return idx
		end
	end
	return 1
end

local function toggle_term(count)
	for other_count, term in pairs(terms) do
		if other_count ~= count and term:is_open() then
			term:close()
		end
	end

	local term = terms[count]
	term:toggle()
	if term:is_open() then
		current_index = index_of(count)
	end
end

function TogglePrimaryTerm()
	toggle_term(1)
end

function ToggleSecondaryTerm()
	toggle_term(2)
end

local function cycle(step)
	local len = #term_sequence
	current_index = ((current_index - 1 + step) % len) + 1
	local next_count = term_sequence[current_index]
	local term = terms[next_count]
	if not term:is_open() then
		toggle_term(next_count)
	else
		for _, t in pairs(terms) do
			if t ~= term and t:is_open() then
				t:close()
			end
		end
		term:close()
		term:open()
	end
end

function CycleNextTerm()
	cycle(1)
end

function CyclePreviousTerm()
	cycle(-1)
end
