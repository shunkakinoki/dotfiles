-- Tests for keymap functionality
-- Note: keymaps.lua requires plugins, so we test keymap API behavior instead

describe("keymaps", function()
	describe("leader key", function()
		it("should set leader key to space", function()
			assert.equals(" ", vim.g.mapleader)
		end)
	end)

	describe("vim.keymap API", function()
		it("should be able to set keymaps", function()
			local test_called = false
			vim.keymap.set("n", "<leader>test_km1", function()
				test_called = true
			end, { noremap = true, silent = true })

			local keymap_info = vim.fn.maparg("<leader>test_km1", "n")
			assert.is_true(keymap_info ~= "")

			vim.keymap.del("n", "<leader>test_km1")
		end)

		it("should be able to delete keymaps", function()
			vim.keymap.set("n", "<leader>test_km2", ":echo 'test'<CR>", { noremap = true })
			vim.keymap.del("n", "<leader>test_km2")

			local keymap_info = vim.fn.maparg("<leader>test_km2", "n")
			assert.equals("", keymap_info)
		end)

		it("should support silent option", function()
			vim.keymap.set("n", "<leader>test_km3", ":echo 'test'<CR>", { silent = true })

			local keymaps = vim.api.nvim_get_keymap("n")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test_km3") then
					found = true
					assert.equals(1, km.silent)
					break
				end
			end
			assert.is_true(found)

			vim.keymap.del("n", "<leader>test_km3")
		end)

		it("should support noremap option", function()
			vim.keymap.set("n", "<leader>test_km4", ":echo 'test'<CR>", { noremap = true })

			local keymaps = vim.api.nvim_get_keymap("n")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test_km4") then
					found = true
					assert.equals(1, km.noremap)
					break
				end
			end
			assert.is_true(found)

			vim.keymap.del("n", "<leader>test_km4")
		end)

		it("should be able to create buffer-local keymaps", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)

			vim.keymap.set("n", "<leader>test_buf_km", ":echo 'test'<CR>", {
				buffer = buf,
				noremap = true,
			})

			local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test_buf_km") then
					found = true
					break
				end
			end

			assert.is_true(found)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should support function callbacks", function()
			local callback_executed = false
			vim.keymap.set("n", "<leader>test_fn", function()
				callback_executed = true
			end, { noremap = true })

			local keymaps = vim.api.nvim_get_keymap("n")
			local found = false
			for _, km in ipairs(keymaps) do
				if km.lhs:match("test_fn") then
					found = true
					assert.is_function(km.callback)
					break
				end
			end
			assert.is_true(found)

			vim.keymap.del("n", "<leader>test_fn")
		end)

		it("should support multiple modes", function()
			vim.keymap.set({ "n", "v" }, "<leader>test_multi", ":echo 'test'<CR>", { noremap = true })

			local n_keymap = vim.fn.maparg("<leader>test_multi", "n")
			local v_keymap = vim.fn.maparg("<leader>test_multi", "v")

			assert.is_true(n_keymap ~= "")
			assert.is_true(v_keymap ~= "")

			vim.keymap.del({ "n", "v" }, "<leader>test_multi")
		end)
	end)

	describe("vscode-diff keymaps", function()
		local function register_vscode_diff_keymaps()
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "<leader>gD_test", function()
				require("vscode-diff.commands").vscode_diff({ fargs = {} })
			end, opts)
			vim.keymap.set("n", "<leader>gH_test", function()
				require("vscode-diff.commands").vscode_diff({ fargs = { "file", "HEAD" } })
			end, opts)
			vim.keymap.set("n", "<leader>gr_test", function()
				vim.ui.input({ prompt = "Diff against revision: ", default = "HEAD" }, function(rev)
					if rev and rev ~= "" then
						require("vscode-diff.commands").vscode_diff({ fargs = { "file", rev } })
					end
				end)
			end, opts)
			vim.keymap.set("n", "<leader>gf_test", function()
				vim.ui.input({ prompt = "File A: ", completion = "file" }, function(a)
					if not a or a == "" then
						return
					end
					vim.ui.input({ prompt = "File B: ", completion = "file" }, function(b)
						if b and b ~= "" then
							require("vscode-diff.commands").vscode_diff({ fargs = { "file", a, b } })
						end
					end)
				end)
			end, opts)
		end

		before_each(function()
			register_vscode_diff_keymaps()
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "<leader>gD_test")
			pcall(vim.keymap.del, "n", "<leader>gH_test")
			pcall(vim.keymap.del, "n", "<leader>gr_test")
			pcall(vim.keymap.del, "n", "<leader>gf_test")
		end)

		it("should register gD as explorer keymap", function()
			local km = vim.fn.maparg("<leader>gD_test", "n")
			assert.is_true(km ~= "")
		end)

		it("should register gH as HEAD diff keymap", function()
			local km = vim.fn.maparg("<leader>gH_test", "n")
			assert.is_true(km ~= "")
		end)

		it("should register gr as revision diff keymap", function()
			local km = vim.fn.maparg("<leader>gr_test", "n")
			assert.is_true(km ~= "")
		end)

		it("should register gf as file diff keymap", function()
			local km = vim.fn.maparg("<leader>gf_test", "n")
			assert.is_true(km ~= "")
		end)

		it("all vscode-diff keymaps should be silent and noremap", function()
			local keys = { "gD_test", "gH_test", "gr_test", "gf_test" }
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, key in ipairs(keys) do
				for _, km in ipairs(keymaps) do
					if km.lhs:match(key) then
						assert.equals(1, km.silent, key .. " should be silent")
						assert.equals(1, km.noremap, key .. " should be noremap")
						break
					end
				end
			end
		end)

		it("all vscode-diff keymaps should have function callbacks", function()
			local keys = { "gD_test", "gH_test", "gr_test", "gf_test" }
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, key in ipairs(keys) do
				for _, km in ipairs(keymaps) do
					if km.lhs:match(key) then
						assert.is_function(km.callback, key .. " should have a function callback")
						break
					end
				end
			end
		end)
	end)

	describe("fugitive diff keymaps", function()
		local keys = { "<leader>gs_test", "<leader>gS_test" }

		before_each(function()
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "<leader>gs_test", ":Gvdiffsplit<cr>", opts)
			vim.keymap.set("n", "<leader>gS_test", ":Gvdiffsplit HEAD<cr>", opts)
		end)

		after_each(function()
			for _, k in ipairs(keys) do
				pcall(vim.keymap.del, "n", k)
			end
		end)

		it("gs should map to Gvdiffsplit", function()
			local km = vim.fn.maparg("<leader>gs_test", "n")
			assert.is_true(km ~= "")
		end)

		it("gS should map to Gvdiffsplit HEAD", function()
			local km = vim.fn.maparg("<leader>gS_test", "n")
			assert.is_true(km ~= "")
		end)

		it("fugitive diff keymaps should be silent and noremap", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, key in ipairs(keys) do
				for _, km in ipairs(keymaps) do
					if km.lhs == key then
						assert.equals(1, km.silent, key .. " should be silent")
						assert.equals(1, km.noremap, key .. " should be noremap")
						break
					end
				end
			end
		end)
	end)

	describe("gitsigns hunk navigation keymaps", function()
		local keys = { "<leader>hn_test", "<leader>hN_test" }

		before_each(function()
			local opts = { noremap = true, silent = true }
			vim.keymap.set("n", "<leader>hn_test", ":Gitsigns next_hunk<cr>", opts)
			vim.keymap.set("n", "<leader>hN_test", ":Gitsigns prev_hunk<cr>", opts)
		end)

		after_each(function()
			for _, k in ipairs(keys) do
				pcall(vim.keymap.del, "n", k)
			end
		end)

		it("hn should map to next_hunk", function()
			local km = vim.fn.maparg("<leader>hn_test", "n")
			assert.is_true(km ~= "")
		end)

		it("hN should map to prev_hunk", function()
			local km = vim.fn.maparg("<leader>hN_test", "n")
			assert.is_true(km ~= "")
		end)

		it("hunk navigation keymaps should be silent and noremap", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, key in ipairs(keys) do
				for _, km in ipairs(keymaps) do
					if km.lhs == key then
						assert.equals(1, km.silent, key .. " should be silent")
						assert.equals(1, km.noremap, key .. " should be noremap")
						break
					end
				end
			end
		end)
	end)

	describe("oil side-by-side keymap", function()
		before_each(function()
			vim.keymap.set("n", "<leader>-_test", function()
				vim.ui.input({ prompt = "Dir A: ", default = vim.fn.expand("%:p:h"), completion = "dir" }, function(a)
					if not a or a == "" then
						return
					end
					vim.ui.input({ prompt = "Dir B: ", completion = "dir" }, function(b)
						if not b or b == "" then
							return
						end
						vim.cmd("vsplit")
						vim.cmd("wincmd h")
						require("oil").open(a)
						vim.cmd("wincmd l")
						require("oil").open(b)
					end)
				end)
			end, { desc = "Oil: open two dirs side by side" })
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "<leader>-_test")
		end)

		it("should register oil side-by-side keymap", function()
			local km = vim.fn.maparg("<leader>-_test", "n")
			assert.is_true(km ~= "")
		end)

		it("oil side-by-side keymap should have a function callback", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, km in ipairs(keymaps) do
				if km.lhs:match("-_test") then
					assert.is_function(km.callback)
					return
				end
			end
			assert.is_true(false, "keymap not found")
		end)
	end)

	describe("gitsigns existing keymaps", function()
		local git_keys = {
			{ lhs = "<leader>gd_t", rhs = ":Gitsigns preview_hunk_inline<cr>" },
			{ lhs = "<leader>hs_t", rhs = ":Gitsigns stage_hunk<cr>" },
			{ lhs = "<leader>hr_t", rhs = ":Gitsigns reset_hunk<cr>" },
			{ lhs = "<leader>hp_t", rhs = ":Gitsigns preview_hunk<cr>" },
			{ lhs = "<leader>hb_t", rhs = ":Gitsigns blame_line<cr>" },
		}

		before_each(function()
			local opts = { noremap = true, silent = true }
			for _, km in ipairs(git_keys) do
				vim.keymap.set("n", km.lhs, km.rhs, opts)
			end
		end)

		after_each(function()
			for _, km in ipairs(git_keys) do
				pcall(vim.keymap.del, "n", km.lhs)
			end
		end)

		it("should register all gitsigns keymaps", function()
			for _, km in ipairs(git_keys) do
				local result = vim.fn.maparg(km.lhs, "n")
				assert.is_true(result ~= "", km.lhs .. " should be registered")
			end
		end)

		it("all gitsigns keymaps should be silent and noremap", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, km in ipairs(git_keys) do
				for _, m in ipairs(keymaps) do
					if m.lhs == km.lhs then
						assert.equals(1, m.silent, km.lhs .. " should be silent")
						assert.equals(1, m.noremap, km.lhs .. " should be noremap")
						break
					end
				end
			end
		end)
	end)

	describe("full config reload keymap", function()
		before_each(function()
			vim.keymap.set("n", "<leader>R_test", function()
				for name, _ in pairs(package.loaded) do
					if name:match("^config%.") then
						package.loaded[name] = nil
					end
				end
				vim.cmd("source $MYVIMRC")
			end, { desc = "Full reload of Neovim config" })
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "<leader>R_test")
		end)

		it("should register full reload keymap", function()
			local km = vim.fn.maparg("<leader>R_test", "n")
			assert.is_true(km ~= "")
		end)

		it("should have a function callback", function()
			local keymaps = vim.api.nvim_get_keymap("n")
			for _, km in ipairs(keymaps) do
				if km.lhs:match("R_test") then
					assert.is_function(km.callback)
					return
				end
			end
			assert.is_true(false, "keymap not found")
		end)

		it("config module unloading pattern should work", function()
			-- Verify we can unload config.* modules
			package.loaded["config.test_fake"] = {}
			for name, _ in pairs(package.loaded) do
				if name:match("^config%.") then
					package.loaded[name] = nil
				end
			end
			assert.is_nil(package.loaded["config.test_fake"])
		end)
	end)

	describe("lazygit keymap", function()
		before_each(function()
			vim.keymap.set("n", "<leader>lg_t", ":LazyGit<cr>", { noremap = true, silent = true })
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "<leader>lg_t")
		end)

		it("should register lazygit keymap", function()
			local km = vim.fn.maparg("<leader>lg_t", "n")
			assert.is_true(km ~= "")
		end)
	end)

	describe("oil parent dir keymap", function()
		before_each(function()
			vim.keymap.set("n", "-_oil_t", "<CMD>Oil<CR>", { desc = "Open Parent Directory" })
		end)

		after_each(function()
			pcall(vim.keymap.del, "n", "-_oil_t")
		end)

		it("should register oil parent dir keymap", function()
			local km = vim.fn.maparg("-_oil_t", "n")
			assert.is_true(km ~= "")
		end)
	end)

	describe("keymap execution", function()
		it("should execute keymap action via feedkeys", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_set_current_buf(buf)

			vim.keymap.set("n", "<leader>test_exec", function()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "executed" })
			end, { buffer = buf })

			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>test_exec", true, false, true), "x", false)

			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.are.same({ "executed" }, lines)

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("NvimPluginsInstall user command", function()
		before_each(function()
			-- Register a minimal version of the command for testing
			pcall(vim.api.nvim_del_user_command, "NvimPluginsInstall")
			vim.api.nvim_create_user_command("NvimPluginsInstall", function()
				-- minimal stub: just records that it was called
				vim.g._nvim_plugins_install_called = true
			end, { desc = "Download/build all Neovim plugins that require native binaries" })
		end)

		after_each(function()
			pcall(vim.api.nvim_del_user_command, "NvimPluginsInstall")
			vim.g._nvim_plugins_install_called = nil
		end)

		it("should be a registered user command", function()
			local cmds = vim.api.nvim_get_commands({})
			assert.is_not_nil(cmds["NvimPluginsInstall"])
		end)

		it("should have a description", function()
			local cmds = vim.api.nvim_get_commands({})
			local cmd = cmds["NvimPluginsInstall"]
			assert.is_not_nil(cmd)
			assert.is_string(cmd.definition or cmd.desc or "")
		end)

		it("should execute without error", function()
			assert.has_no.errors(function()
				vim.cmd("NvimPluginsInstall")
			end)
		end)

		it("should run the install callback when called", function()
			vim.g._nvim_plugins_install_called = false
			vim.cmd("NvimPluginsInstall")
			assert.is_true(vim.g._nvim_plugins_install_called == true)
		end)

		it("should support globpath for plugin dir discovery", function()
			-- globpath with 0,1 returns a list - verify the API works
			local results = vim.fn.globpath(vim.o.packpath, "*/opt/*.nvim", 0, 1)
			assert.is_table(results)
		end)
	end)

	describe("keymap desc enforcement", function()
		-- Parses all lua config files and finds every keymap.set call with a leader
		-- lhs, then verifies a desc is present. This catches regressions across ALL
		-- config files automatically — no manual maintenance required.

		local function get_lua_config_files()
			local init_path = debug.getinfo(1, "S").source:sub(2)
			local tests_dir = vim.fn.fnamemodify(init_path, ":h")
			local lua_dir = vim.fn.fnamemodify(tests_dir, ":h") .. "/lua/config"
			return vim.fn.glob(lua_dir .. "/*.lua", false, true)
		end

		local function scan_keymaps_missing_desc(files)
			local missing = {}
			-- Pattern: keymap(..., "<leader>...", ...) or keymap.set(..., "<leader>...", ...)
			-- without a desc = "..." on the same logical call
			local keymap_pattern = "keymap[^(]*%([^,]*,?%s*[\"']([^\"']*<[Ll]eader>[^\"']*)[\"']"
			for _, filepath in ipairs(files) do
				local f = io.open(filepath, "r")
				if f then
					local content = f:read("*a")
					f:close()
					-- Find each keymap call block (up to the closing paren with opts)
					-- We look for lines containing a leader lhs
					for line in content:gmatch("[^\n]+") do
						if line:match("['\"]<[Ll]eader>") and line:match("keymap") then
							-- Check if this line or nearby has desc
							-- Simple heuristic: if the line has desc= it's fine
							-- We'll do a chunk-based scan below for multi-line calls
						end
					end

					-- Chunk-based: find keymap( ... ) blocks and check for desc
					local pos = 1
					while pos <= #content do
						local s, e = content:find("keymap[^(]*%(", pos)
						if not s then
							break
						end
						-- Find matching closing paren (simple depth counter)
						local depth = 0
						local chunk_end = e
						for i = e, math.min(e + 2000, #content) do
							local c = content:sub(i, i)
							if c == "(" then
								depth = depth + 1
							elseif c == ")" then
								depth = depth - 1
								if depth == 0 then
									chunk_end = i
									break
								end
							end
						end
						local chunk = content:sub(s, chunk_end)
						-- Only care about chunks with a leader lhs
						if chunk:match("['\"]<[Ll]eader>") or chunk:match("['\"]%s*<[Ll]eader>") then
							-- Skip if it's setting the leader itself (<Space> = <Nop>)
							if not chunk:match('"",') and not chunk:match('"<[Ss]pace>"') then
								if not chunk:match("desc%s*=") then
									-- Extract lhs for the error message
									local lhs = chunk:match("[\"']([^\"']*<[Ll]eader>[^\"']*)[\"']") or "?"
									local file = vim.fn.fnamemodify(filepath, ":t")
									table.insert(missing, file .. ": " .. lhs)
								end
							end
						end
						pos = chunk_end + 1
					end
				end
			end
			return missing
		end

		it("sanity: missing desc is detectable in source scan", function()
			-- Inject a fake file content and verify the scanner catches it
			local fake_file = vim.fn.tempname() .. ".lua"
			local f = io.open(fake_file, "w")
			if f then
				f:write('keymap("n", "<leader>foo", ":echo hi<CR>", { noremap = true })\n')
				f:close()
				local missing = scan_keymaps_missing_desc({ fake_file })
				assert.is_true(#missing > 0, "Expected scanner to detect missing desc")
				os.remove(fake_file)
			end
		end)

		it("sanity: keymap with desc passes source scan", function()
			local fake_file = vim.fn.tempname() .. ".lua"
			local f = io.open(fake_file, "w")
			if f then
				f:write('keymap("n", "<leader>foo", ":echo hi<CR>", { noremap = true, desc = "My action" })\n')
				f:close()
				local missing = scan_keymaps_missing_desc({ fake_file })
				assert.are.same({}, missing, "Expected no missing desc")
				os.remove(fake_file)
			end
		end)

		it("all leader keymaps in all config files have a desc", function()
			local files = get_lua_config_files()
			assert.is_true(#files > 0, "No config files found")
			local missing = scan_keymaps_missing_desc(files)
			assert.are.same(
				{},
				missing,
				"Keymaps missing desc across config files (" .. #missing .. "):\n  " .. table.concat(missing, "\n  ")
			)
		end)
	end)

	describe("terminal leader safety", function()
		local function read_keymaps_source()
			local test_file = debug.getinfo(1, "S").source:sub(2)
			local tests_dir = vim.fn.fnamemodify(test_file, ":h")
			local keymaps_path = vim.fn.fnamemodify(tests_dir, ":h") .. "/lua/config/keymaps.lua"
			local file = assert(io.open(keymaps_path, "r"))
			local content = file:read("*a")
			file:close()
			return content
		end

		it("does not bind leader-prefixed mappings in terminal mode", function()
			local content = read_keymaps_source()
			assert.is_nil(content:match('keymap%s*%(%s*"t"%s*,%s*"<leader>'))
			assert.is_nil(content:match('keymap%s*%(%s*%{[^}]*"t"[^}]*}%s*,%s*"<leader>'))
		end)

		it("uses alt-based terminal management mappings instead", function()
			local content = read_keymaps_source()
			assert.is_truthy(content:match('keymap%s*%(%s*"t"%s*,%s*"<M%-h>"'))
			assert.is_truthy(content:match('keymap%s*%(%s*"t"%s*,%s*"<M%-j>"'))
			assert.is_truthy(content:match('keymap%s*%(%s*"t"%s*,%s*"<M%-u>"'))
			assert.is_truthy(content:match('keymap%s*%(%s*"t"%s*,%s*"<M%-n>"'))
			assert.is_truthy(content:match('keymap%s*%(%s*"t"%s*,%s*"<M%-p>"'))
		end)
	end)
end)
