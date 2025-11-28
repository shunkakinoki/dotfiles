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

local term_counter = 0
local term_sequence = {}
local terms = {}
local current_index = 0

local function create_term()
	term_counter = term_counter + 1
	local count = term_counter
	local term = Terminal:new({
		direction = "horizontal",
		count = count,
		hidden = true,
		on_open = function()
			vim.cmd("startinsert!")
		end,
	})
	terms[count] = term
	table.insert(term_sequence, count)
	return count
end

local function index_of(count)
	for idx, value in ipairs(term_sequence) do
		if value == count then
			return idx
		end
	end
	return nil
end

local function close_other_terms(except_id)
	for id, term in pairs(terms) do
		if id ~= except_id and term:is_open() then
			term:close()
		end
	end
end

local function show_term(id)
	local term = terms[id]
	if not term then
		return
	end
	close_other_terms(id)
	if not term:is_open() then
		term:open()
	end
	current_index = index_of(id) or 0
end

local function ensure_current_term_id()
	if current_index == 0 then
		if #term_sequence == 0 then
			local first = create_term()
			current_index = index_of(first)
			return first
		end
		current_index = 1
	end
	return term_sequence[current_index]
end

function SpawnTerminal()
	local id = create_term()
	show_term(id)
end

function KillCurrentTerminal()
	if #term_sequence == 0 or current_index == 0 then
		return
	end

	local id = term_sequence[current_index]
	local term = terms[id]
	if term and term:is_open() then
		term:close()
	end
	terms[id] = nil

	local was_index = current_index
	table.remove(term_sequence, was_index)
	if #term_sequence == 0 then
		current_index = 0
		return
	end

	local next_index = was_index
	if next_index > #term_sequence then
		next_index = #term_sequence
	end
	current_index = next_index
	show_term(term_sequence[current_index])
end

local function cycle(step)
	local len = #term_sequence
	if len == 0 then
		local first = create_term()
		show_term(first)
		return
	end

	if current_index == 0 then
		current_index = 1
	else
		current_index = ((current_index - 1 + step) % len) + 1
	end
	show_term(term_sequence[current_index])
end

function CycleNextTerm()
	cycle(1)
end

function CyclePreviousTerm()
	cycle(-1)
end

function ToggleTerminal()
	local id = ensure_current_term_id()
	local term = terms[id]
	if term and term:is_open() then
		term:close()
		current_index = 0
		return
	end
	show_term(id)
end
