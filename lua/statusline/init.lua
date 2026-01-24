---@module "custom.statusline"
local M = {}

local components = require("statusline.component")

--- Default config
local defaults = {
	bg_hex = "#1f2335",
	fg_main = "#c0caf5",
	fg_dim = "#565f89",

	icon_set = "nerd_v3", -- "nerd_v3", "nerd_v2", "ascii"
	separator_style = "vertical", -- "vertical", "angle_right", "dot"

	components = {
		mode = { enabled = true, style = "bubble" },
		git = { enabled = true },
		diagnostics = { enabled = true },
		file_info = { enabled = true, show_size = true },
		progress = { enabled = true, style = "bar" },
		lsp_progress = { enabled = true, min_width = 100 },
		dev_server = { enabled = true },
	},

	-- Performance settings
	fallback_interval = 10000, -- 10 second safety net timer
	throttle_intervals = {
		position = 200, -- max update frequency for position
		diagnostics = 500, -- debounce delay for diagnostics
		git = 1000, -- debounce delay for git
	},
}

-- State management for static statusline approach
M.state = {
	-- Pre-rendered component strings (cached)
	rendered = {
		mode = "",
		git = "",
		file = "",
		diagnostics = "",
		lsp = "",
		position = "",
		right_info = "",
	},

	-- Track which components need re-rendering
	dirty = {
		mode = true,
		git = true,
		file = true,
		diagnostics = true,
		lsp = true,
		position = true,
		right_info = true,
	},

	-- Full statusline string
	statusline = "",
	last_rebuild = 0,
}

-- Timers
local timers = {
	fallback = nil,
	debounce = {},
}

-- Last update timestamps for throttling
local last_update = {
	position = 0,
	diagnostics = 0,
	git = 0,
}

-----------------------------------------------------------
-- COMPONENT RENDERERS (with caching and dirty tracking)
-----------------------------------------------------------

local function render_mode()
	if not M.state.dirty.mode then
		return M.state.rendered.mode
	end

	local ok, mode_data = pcall(vim.api.nvim_get_mode)
	if not ok then
		M.state.rendered.mode = ""
		M.state.dirty.mode = false
		return ""
	end

	local mode_config = M.mode_config
	local info = mode_config[mode_data.mode] or mode_config.n

	M.state.rendered.mode = table.concat({
		"%#" .. info.hl .. "#",
		" ",
		info.icon,
		" ",
		info.name,
		" ",
		"%#" .. info.hl .. "Sep#",
		"",
		"%*",
	})

	M.state.dirty.mode = false
	return M.state.rendered.mode
end

local function render_git()
	if not M.state.dirty.git then
		return M.state.rendered.git
	end

	if not M.config.components.git.enabled then
		M.state.rendered.git = ""
		M.state.dirty.git = false
		return ""
	end

	local git_branch = components.git_branch()
	local git_status = components.git_status()

	if git_branch == "" and git_status == "" then
		M.state.rendered.git = ""
		M.state.dirty.git = false
		return ""
	end

	local parts = {}
	if git_branch ~= "" then
		table.insert(parts, git_branch)
	end
	if git_status ~= "" then
		table.insert(parts, " ")
		table.insert(parts, git_status)
	end
	table.insert(parts, components.separator(M.config.separator_style) .. " ")

	M.state.rendered.git = table.concat(parts)
	M.state.dirty.git = false
	return M.state.rendered.git
end

local function render_file()
	if not M.state.dirty.file then
		return M.state.rendered.file
	end

	if not M.config.components.file_info.enabled then
		M.state.rendered.file = ""
		M.state.dirty.file = false
		return ""
	end

	M.state.rendered.file = components.fileinfo({
		add_icon = true,
		show_size = M.config.components.file_info.show_size,
	})

	M.state.dirty.file = false
	return M.state.rendered.file
end

local function render_diagnostics()
	if not M.state.dirty.diagnostics then
		return M.state.rendered.diagnostics
	end

	if not M.config.components.diagnostics.enabled then
		M.state.rendered.diagnostics = ""
		M.state.dirty.diagnostics = false
		return ""
	end

	local diag = components.diagnostics()
	if diag ~= "" then
		diag = components.separator(M.config.separator_style) .. " " .. diag
	end

	M.state.rendered.diagnostics = diag
	M.state.dirty.diagnostics = false
	return M.state.rendered.diagnostics
end

local function render_lsp()
	if not M.state.dirty.lsp then
		return M.state.rendered.lsp
	end

	if not M.config.components.lsp_progress.enabled then
		M.state.rendered.lsp = ""
		M.state.dirty.lsp = false
		return ""
	end

	local lsp_prog = components.lsp_progress()
	if lsp_prog ~= "" then
		lsp_prog = lsp_prog .. components.separator("dot") .. " "
	end

	M.state.rendered.lsp = lsp_prog
	M.state.dirty.lsp = false
	return M.state.rendered.lsp
end

local function render_position()
	if not M.state.dirty.position then
		return M.state.rendered.position
	end

	local parts = {}

	-- Position
	table.insert(parts, components.separator(M.config.separator_style))
	table.insert(parts, " ")
	table.insert(parts, components.position())
	table.insert(parts, components.total_lines())
	table.insert(parts, " ")

	-- Progress bar
	if M.config.components.progress.enabled then
		table.insert(parts, components.separator(M.config.separator_style))
		table.insert(parts, " ")
		table.insert(parts, components.progress_bar())
		table.insert(parts, " ")
	end

	M.state.rendered.position = table.concat(parts)
	M.state.dirty.position = false
	return M.state.rendered.position
end

local function render_right_info()
	if not M.state.dirty.right_info then
		return M.state.rendered.right_info
	end

	local width = vim.api.nvim_win_get_width(0)
	local parts = {}

	-- Dev server status
	if M.config.components.dev_server and M.config.components.dev_server.enabled and width >= 100 then
		local dev_status = components.dev_server_status()
		if dev_status ~= "" then
			table.insert(parts, dev_status)
			table.insert(parts, components.separator("dot") .. " ")
		end
	end

	-- Active indicators
	if width >= 100 then
		for _, fn in ipairs({
			components.maximized_status,
			components.macro_recording,
			components.search_count,
		}) do
			local val = fn()
			if val ~= "" then
				table.insert(parts, val)
			end
		end
	end

	-- File encoding/format
	if width >= 120 then
		local enc = components.file_encoding()
		local fmt = components.file_format()
		if enc ~= "" or fmt ~= "" then
			table.insert(parts, components.separator(M.config.separator_style) .. " ")
			if enc ~= "" then
				table.insert(parts, enc)
			end
			if fmt ~= "" then
				table.insert(parts, fmt)
			end
		end
	end

	-- Filetype
	local filetype = components.filetype()
	if filetype ~= "" and width >= 100 then
		table.insert(parts, components.separator(M.config.separator_style) .. " ")
		table.insert(parts, filetype)
		table.insert(parts, " ")
	end

	M.state.rendered.right_info = table.concat(parts)
	M.state.dirty.right_info = false
	return M.state.rendered.right_info
end

-----------------------------------------------------------
-- STATUSLINE BUILDER (static string approach)
-----------------------------------------------------------

local function build_statusline_string()
	local width = vim.api.nvim_win_get_width(0)
	local ft = vim.bo.filetype

	-- Special filetypes
	local special = {
		"neo-tree",
		"minifiles",
		"oil",
		"TelescopePrompt",
		"fzf",
		"snacks_picker_input",
		"alpha",
		"dashboard",
		"NvimTree",
		"packer",
		"lazy",
	}

	if vim.tbl_contains(special, ft) then
		local home = vim.loop.os_homedir() or ""
		local dir = vim.fn.getcwd():gsub("^" .. home, "~")
		return components.get_or_create_hl("#7dcfff", M.colors.bg_hex, { bold = true })
			.. " ✦ "
			.. ft:sub(1, 1):upper()
			.. ft:sub(2)
			.. " ▸ "
			.. dir
			.. "%*"
	end

	-- Minimal mode for very narrow windows
	if width < 80 then
		return table.concat({
			render_mode(),
			"%=",
			components.position(),
			components.padding(1),
		})
	end

	-- Build sections
	local left = {
		render_mode(),
		components.padding(2),
		render_git(),
		render_file(),
	}

	if width >= 100 then
		table.insert(left, render_diagnostics())
	end

	local middle = { "%=" }

	local right = {}

	-- LSP progress
	if width >= M.config.components.lsp_progress.min_width then
		table.insert(right, render_lsp())
	end

	-- Other right-side components
	table.insert(right, render_right_info())

	-- Position (always show)
	table.insert(right, render_position())

	return table.concat(left) .. table.concat(middle) .. table.concat(right)
end

-----------------------------------------------------------
-- UPDATE FUNCTIONS (event-driven)
-----------------------------------------------------------

-- Mark component as dirty
local function mark_dirty(component_name)
	if M.state.dirty[component_name] ~= nil then
		M.state.dirty[component_name] = true
	end
end

-- Apply statusline update (only if changed)
local function apply_update()
	local new_statusline = build_statusline_string()

	if new_statusline ~= M.state.statusline then
		M.state.statusline = new_statusline
		vim.o.statusline = new_statusline
		M.state.last_rebuild = vim.loop.now()
	end
end

-- Immediate update (for critical changes)
local function update_immediate(component)
	mark_dirty(component)
	apply_update()
end

-- Throttled update (for high-frequency events)
local function update_throttled(component, interval)
	local now = vim.loop.now()

	if now - last_update[component] < interval then
		return -- Skip this update
	end

	last_update[component] = now
	mark_dirty(component)
	apply_update()
end

-- Debounced update (wait for quiet period)
local function update_debounced(component, delay)
	if timers.debounce[component] then
		vim.fn.timer_stop(timers.debounce[component])
	end

	timers.debounce[component] = vim.fn.timer_start(delay, function()
		mark_dirty(component)
		apply_update()
		timers.debounce[component] = nil
	end)
end

-----------------------------------------------------------
-- FALLBACK TIMER (safety net)
-----------------------------------------------------------

local function start_fallback_timer()
	if timers.fallback then
		return
	end

	timers.fallback = vim.fn.timer_start(M.config.fallback_interval, function()
		-- Mark all components dirty for full refresh
		for component in pairs(M.state.dirty) do
			M.state.dirty[component] = true
		end
		apply_update()
	end, { ["repeat"] = -1 })
end

local function stop_fallback_timer()
	if timers.fallback then
		vim.fn.timer_stop(timers.fallback)
		timers.fallback = nil
	end
end

-----------------------------------------------------------
-- EVENT HANDLERS
-----------------------------------------------------------

local function setup_events()
	vim.api.nvim_create_augroup("StatuslineEvents", { clear = true })

	-- Mode changes (immediate)
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = "StatuslineEvents",
		callback = function()
			update_immediate("mode")
		end,
	})

	-- File changes (immediate)
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "BufModifiedSet", "FileType" }, {
		group = "StatuslineEvents",
		callback = function()
			update_immediate("file")
		end,
	})

	-- Git updates (debounced)
	vim.api.nvim_create_autocmd("User", {
		pattern = "GitSignsUpdate",
		group = "StatuslineEvents",
		callback = function()
			-- Clear component cache
			if vim.b.status_cache then
				vim.b.status_cache.git = nil
			end
			update_debounced("git", M.config.throttle_intervals.git)
		end,
	})

	-- Diagnostic changes (debounced)
	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = "StatuslineEvents",
		callback = function()
			update_debounced("diagnostics", M.config.throttle_intervals.diagnostics)
		end,
	})

	-- LSP Progress (immediate)
	vim.api.nvim_create_autocmd("LspProgress", {
		group = "StatuslineEvents",
		callback = function(args)
			local client_id = args.data and args.data.client_id
			local params = args.data and args.data.params

			if not (client_id and params) then
				return
			end

			local value = params.value
			if not value then
				return
			end

			-- Get client name
			local client = vim.lsp.get_client_by_id(client_id)
			local client_name = client and client.name or "LSP"

			-- Update component state based on progress kind
			if value.kind == "begin" then
				components.lsp_state.clients[client_id] = {
					client_name = client_name,
					title = value.title or "",
					message = value.message or "",
					percentage = value.percentage,
					active = true,
					timestamp = vim.loop.now(),
				}
			elseif value.kind == "report" then
				local existing = components.lsp_state.clients[client_id]
				if existing then
					existing.message = value.message or existing.message
					existing.percentage = value.percentage or existing.percentage
					existing.timestamp = vim.loop.now()
				end
			elseif value.kind == "end" then
				local existing = components.lsp_state.clients[client_id]
				if existing then
					existing.active = false
					vim.defer_fn(function()
						components.lsp_state.clients[client_id] = nil
						update_immediate("lsp")
					end, 500)
				end
			end

			update_immediate("lsp")
		end,
	})

	-- Position updates (throttled on CursorHold instead of CursorMoved)
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = "StatuslineEvents",
		callback = function()
			update_throttled("position", M.config.throttle_intervals.position)
		end,
	})

	-- Window resize (mark all dirty)
	vim.api.nvim_create_autocmd("VimResized", {
		group = "StatuslineEvents",
		callback = function()
			for component in pairs(M.state.dirty) do
				M.state.dirty[component] = true
			end
			apply_update()
		end,
	})

	-- Right info needs update on various events
	vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave", "SearchWrapped" }, {
		group = "StatuslineEvents",
		callback = function()
			update_immediate("right_info")
		end,
	})

	-- Cleanup on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = "StatuslineEvents",
		callback = function()
			stop_fallback_timer()
			for name, timer in pairs(timers.debounce) do
				if timer then
					vim.fn.timer_stop(timer)
				end
			end
			-- Stop LSP spinner timer
			if components.lsp_state and components.lsp_state.spinner_timer then
				components.lsp_state.spinner_timer:stop()
				components.lsp_state.spinner_timer:close()
			end
		end,
	})
end

-----------------------------------------------------------
-- SETUP FUNCTION
-----------------------------------------------------------

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", defaults, opts or {})
	M.config = opts

	-- Update components config
	components.setup({
		icon_set = opts.icon_set,
		separator_style = opts.separator_style,
	})

	-- Color palette with error handling
	local ok, statusline_hl = pcall(vim.api.nvim_get_hl, 0, { name = "StatusLine" })
	local bg_hex
	if ok and statusline_hl and statusline_hl.bg and statusline_hl.bg ~= 0 then
		bg_hex = string.format("#%06x", statusline_hl.bg)
	else
		bg_hex = opts.bg_hex or "#1f2335"
	end
	local fg_main = opts.fg_main or "#c0caf5"
	local fg_dim = opts.fg_dim or "#565f89"

	-- Store colors for components
	M.colors = {
		bg_hex = bg_hex,
		fg_main = fg_main,
		fg_dim = fg_dim,
	}

	-- Highlight groups
	local highlights = {
		SLBgNoneHl = { fg = fg_main, bg = "none" },
		SLNotModifiable = { fg = "#e0af68", bg = bg_hex, italic = true },
		SLNormal = { fg = fg_main, bg = bg_hex },
		SLModified = { fg = "#f7768e", bg = bg_hex, bold = true },
		SLMatches = { fg = "#1a1b26", bg = "#7dcfff", bold = true },
		SLDIM = { fg = fg_dim, bg = bg_hex },
		SLFileInfo = { fg = "#c0caf5", bg = bg_hex, bold = true },
		SLPosition = { fg = "#c0caf5", bg = bg_hex, bold = true },
		SLFiletype = { fg = "#bb9af7", bg = bg_hex },
		SLSeparator = { fg = "#3b4261", bg = bg_hex },
		SLGitBranch = { fg = "#bb9af7", bg = bg_hex },
		SLGitAdded = { fg = "#9ece6a", bg = bg_hex },
		SLGitChanged = { fg = "#e0af68", bg = bg_hex },
		SLGitRemoved = { fg = "#f7768e", bg = bg_hex },
		SLEncoding = { fg = "#7aa2f7", bg = bg_hex },
		SLFormat = { fg = "#7aa2f7", bg = bg_hex },
		SL_LspProgress = { fg = "#7dcfff", bg = bg_hex, bold = true },
	}

	for name, hl_opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, hl_opts)
	end

	-- Mode colors with adaptive light/dark support
	local function get_mode_colors()
		if vim.o.background == "light" then
			return {
				Normal = "#5a7fc7",
				Insert = "#6da85a",
				Visual = "#9768b5",
				Replace = "#d15757",
				Command = "#c99435",
				Terminal = "#4a9c8e",
				Select = "#d17557",
			}
		else
			return {
				Normal = "#7aa2f7",
				Insert = "#9ece6a",
				Visual = "#bb9af7",
				Replace = "#f7768e",
				Command = "#e0af68",
				Terminal = "#73daca",
				Select = "#ff9e64",
			}
		end
	end

	local mode_colors = get_mode_colors()

	local function create_mode_hl(name, color)
		vim.api.nvim_set_hl(0, "Status" .. name, {
			bg = color,
			fg = "#1a1b26",
			bold = true,
		})
		vim.api.nvim_set_hl(0, "Status" .. name .. "Sep", {
			fg = color,
			bg = bg_hex,
		})
	end

	for name, color in pairs(mode_colors) do
		create_mode_hl(name, color)
	end

	-- Mode configuration with modern icons
	M.mode_config = {
		-- Normal modes
		n = { name = "NORMAL", hl = "StatusNormal", icon = "󰋜", desc = "Normal" },
		no = { name = "N·OP", hl = "StatusNormal", icon = "󰋜", desc = "Operator Pending" },
		nov = { name = "N·OP·V", hl = "StatusNormal", icon = "󰋜", desc = "Operator Pending Char" },
		noV = { name = "N·OP·L", hl = "StatusNormal", icon = "󰋜", desc = "Operator Pending Line" },
		["no\22"] = { name = "N·OP·B", hl = "StatusNormal", icon = "󰋜", desc = "Operator Pending Block" },

		-- Visual modes
		v = { name = "VISUAL", hl = "StatusVisual", icon = "󰈈", desc = "Visual" },
		V = { name = "V·LINE", hl = "StatusVisual", icon = "󰈈", desc = "Visual Line" },
		["\22"] = { name = "V·BLOCK", hl = "StatusVisual", icon = "󰈈", desc = "Visual Block" },

		-- Select modes
		s = { name = "SELECT", hl = "StatusSelect", icon = "󰈈", desc = "Select" },
		S = { name = "S·LINE", hl = "StatusSelect", icon = "󰈈", desc = "Select Line" },
		["\19"] = { name = "S·BLOCK", hl = "StatusSelect", icon = "󰈈", desc = "Select Block" },

		-- Insert modes

		i = { name = "INSERT", hl = "StatusInsert", icon = "󰏫", desc = "Insert" },
		ic = { name = "I·COMP", hl = "StatusInsert", icon = "󰏫", desc = "Insert Completion" },
		ix = { name = "I·COMP", hl = "StatusInsert", icon = "󰏫", desc = "Insert Completion" },

		-- Replace modes
		R = { name = "REPLACE", hl = "StatusReplace", icon = "󰛔", desc = "Replace" },
		Rc = { name = "R·COMP", hl = "StatusReplace", icon = "󰛔", desc = "Replace Completion" },
		Rv = { name = "V·REPLACE", hl = "StatusReplace", icon = "󰛔", desc = "Virtual Replace" },
		Rx = { name = "R·COMP", hl = "StatusReplace", icon = "󰛔", desc = "Replace Completion" },

		-- Command modes
		c = { name = "COMMAND", hl = "StatusCommand", icon = "󰘳", desc = "Command" },
		cv = { name = "EX", hl = "StatusCommand", icon = "󰘳", desc = "Ex" },
		ce = { name = "EX", hl = "StatusCommand", icon = "󰘳", desc = "Ex" },

		-- Terminal mode
		t = { name = "TERMINAL", hl = "StatusTerminal", icon = "󰆍", desc = "Terminal" },

		-- Misc
		r = { name = "PROMPT", hl = "StatusCommand", icon = "?", desc = "Hit Enter Prompt" },
		rm = { name = "MORE", hl = "StatusCommand", icon = "?", desc = "More" },
		["r?"] = { name = "CONFIRM", hl = "StatusCommand", icon = "?", desc = "Confirm" },
		["!"] = { name = "SHELL", hl = "StatusTerminal", icon = "", desc = "Shell" },
	}

	-- Setup event handlers
	setup_events()

	-- Initial build (mark all components dirty)
	for component in pairs(M.state.dirty) do
		M.state.dirty[component] = true
	end
	apply_update()

	-- Start fallback timer
	start_fallback_timer()
end

-----------------------------------------------------------
-- PUBLIC API
-----------------------------------------------------------

-- Force full rebuild
function M.rebuild()
	for component in pairs(M.state.dirty) do
		M.state.dirty[component] = true
	end
	apply_update()
end

-- Update specific component manually
function M.update_component(name)
	if M.state.dirty[name] ~= nil then
		mark_dirty(name)
		apply_update()
	end
end

-- Get performance stats
function M.stats()
	local dirty_count = 0
	for _, is_dirty in pairs(M.state.dirty) do
		if is_dirty then
			dirty_count = dirty_count + 1
		end
	end

	return {
		last_rebuild = M.state.last_rebuild,
		statusline_length = #M.state.statusline,
		dirty_components = dirty_count,
	}
end

return M
