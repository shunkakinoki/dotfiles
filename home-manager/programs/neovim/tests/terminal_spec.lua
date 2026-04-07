-- Tests for terminal functionality
-- Tests terminal API basics (plugins not loaded in minimal test env)

describe("terminal", function()
	describe("terminal API basics", function()
		it("should have termopen function available", function()
			assert.is_function(vim.fn.termopen)
		end)

		it("should be able to create terminal buffers", function()
			local buf = vim.api.nvim_create_buf(false, true)
			assert.is_true(vim.api.nvim_buf_is_valid(buf))
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should have TermOpen event", function()
			local autocmds = vim.api.nvim_get_autocmds({ event = "TermOpen" })
			assert.is_table(autocmds)
		end)

		it("should recognize terminal buftype", function()
			-- buftype=terminal can only be set by termopen, but we can check the option exists
			local buf = vim.api.nvim_create_buf(false, true)
			local buftype = vim.bo[buf].buftype
			assert.is_string(buftype)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("terminal window options", function()
		it("should be able to create floating window", function()
			local buf = vim.api.nvim_create_buf(false, true)
			local win = vim.api.nvim_open_win(buf, true, {
				relative = "editor",
				width = 80,
				height = 20,
				row = 5,
				col = 5,
				style = "minimal",
			})
			assert.is_true(vim.api.nvim_win_is_valid(win))
			vim.api.nvim_win_close(win, true)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)

-- Tests for terminal.lua global functions
-- Simulates the module logic without requiring toggleterm
describe("terminal globals pattern", function()
	-- Replicate terminal.lua's internal state and logic for unit testing
	local term_counter, term_sequence, terms, current_index

	local function reset_state()
		term_counter = 0
		term_sequence = {}
		terms = {}
		current_index = 0
	end

	local function make_term(id)
		return {
			count = id,
			_open = false,
			is_open = function(self) return self._open end,
			open = function(self) self._open = true end,
			close = function(self) self._open = false end,
		}
	end

	local function create_term()
		term_counter = term_counter + 1
		local id = term_counter
		terms[id] = make_term(id)
		table.insert(term_sequence, id)
		return id
	end

	local function index_of(count)
		for idx, value in ipairs(term_sequence) do
			if value == count then return idx end
		end
	end

	local function close_other_terms(except_id)
		for id, term in pairs(terms) do
			if id ~= except_id and term:is_open() then term:close() end
		end
	end

	local function show_term(id)
		local term = terms[id]
		if not term then return end
		close_other_terms(id)
		if not term:is_open() then term:open() end
		current_index = index_of(id) or 0
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

	before_each(reset_state)

	describe("create_term", function()
		it("should increment counter on each call", function()
			create_term()
			create_term()
			assert.equals(2, term_counter)
		end)

		it("should add to term_sequence", function()
			create_term()
			create_term()
			assert.equals(2, #term_sequence)
		end)

		it("should store term in terms table", function()
			local id = create_term()
			assert.is_not_nil(terms[id])
		end)
	end)

	describe("show_term", function()
		it("should open the specified terminal", function()
			local id = create_term()
			show_term(id)
			assert.is_true(terms[id]:is_open())
		end)

		it("should close other open terminals", function()
			local id1 = create_term()
			local id2 = create_term()
			show_term(id1)
			assert.is_true(terms[id1]:is_open())
			show_term(id2)
			assert.is_false(terms[id1]:is_open())
			assert.is_true(terms[id2]:is_open())
		end)

		it("should update current_index", function()
			local id1 = create_term()
			local id2 = create_term()
			show_term(id2)
			assert.equals(2, current_index)
		end)
	end)

	describe("cycle next", function()
		it("should create first term when none exist", function()
			cycle(1)
			assert.equals(1, #term_sequence)
		end)

		it("should move to next terminal", function()
			local id1 = create_term()
			local id2 = create_term()
			show_term(id1)
			cycle(1)
			assert.is_true(terms[id2]:is_open())
		end)

		it("should wrap around from last to first", function()
			create_term()
			local id2 = create_term()
			show_term(id2)
			cycle(1)
			assert.equals(1, current_index)
		end)
	end)

	describe("cycle prev", function()
		it("should move to previous terminal", function()
			local id1 = create_term()
			local id2 = create_term()
			show_term(id2)
			cycle(-1)
			assert.is_true(terms[id1]:is_open())
		end)

		it("should wrap around from first to last", function()
			local id1 = create_term()
			create_term()
			show_term(id1)
			cycle(-1)
			assert.equals(2, current_index)
		end)
	end)

	describe("kill current terminal logic", function()
		it("should remove terminal from sequence", function()
			create_term()
			create_term()
			show_term(term_sequence[1])
			-- Simulate kill
			local id = term_sequence[current_index]
			terms[id]:close()
			terms[id] = nil
			local was_index = current_index
			table.remove(term_sequence, was_index)
			assert.equals(1, #term_sequence)
		end)

		it("should handle killing last terminal", function()
			local id = create_term()
			show_term(id)
			terms[id]:close()
			terms[id] = nil
			table.remove(term_sequence, current_index)
			current_index = 0
			assert.equals(0, #term_sequence)
			assert.equals(0, current_index)
		end)
	end)
end)
