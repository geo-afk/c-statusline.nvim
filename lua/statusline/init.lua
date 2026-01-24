---@module "custom.statusline"
--- Shadow Eminence Edition - Modernized statusline with elegant dark aesthetics
local M = {}

local components = require("statusline.component")
local theme = require("statusline.theme.shadow_eminence")

--- Default config with Shadow Eminence theme
local defaults = {
	theme = "shadow_eminence", -- Theme to use

	icon_set = "nerd_v3",
	separator_style = "refined", -- "refined", "powerline", "minimal"

	components = {
		mode = { enabled = true, style = "elegant" }, -- "elegant", "bubble", "minimal"
		git = { enabled = true, style = "refined" },
		diagnostics = { enabled = true, style = "compact" },
		file_info = { enabled = true, show_size = true, show_icon = true },
		progress = { enabled = true, style = "modern" }, -- "modern", "bar", "percentage"
		lsp_progress = { enabled = true, min_width = 100 },
		dev_server = { enabled = true },
	},

	-- Visual preferences
	spacing = {
		mode = 2, -- Spacing around mode
		section = 3, -- Between major sections
		component = 2, -- Between components
	},

	-- Performance settings
	fallback_interval = 10000,
	throttle_intervals = {
		position = 200,
		diagnostics = 500,
		git = 1000,
	},
}

-- State management for static statusline approach
M.state = {
	rendered = {
		mode = "",
		git = "",
		file = "",
		diagnostics = "",
		lsp = "",
		position = "",
		right_info = "",
	},
	dirty = {
		mode = true,
		git = true,
		file = true,
		diagnostics = true,
		lsp = true,
		position = true,
		right_info = true,
	},
	statusline = "",
	last_rebuild = 0,
}

-- Timers
local timers = {
	fallback = nil,
	debounce = {},
}

-- Last update timestamps
local last_update = {
	position = 0,
	diagnostics = 0,
	git = 0,
}

-----------------------------------------------------------
-- THEME-AWARE HELPERS
-----------------------------------------------------------

local t = {} -- Theme cache

local function get_theme()
	return t
end

local function spacing(type)
	return string.rep(" ", M.config.spacing[type] or 1)
end

-----------------------------------------------------------
-- REFINED COMPONENT RENDERERS
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

	local mode_info = t.modes[mode_data.mode] or t.modes.n
	local style = M.config.components.mode.style

	local result
	if style == "elegant" then
		-- Elegant style: refined borders with powerline transitions
		result = table.concat({
			"%#" .. mode_info.hl .. "#",
			spacing("mode"),
			mode_info.icon,
			" ",
			mode_info.name,
			spacing("mode"),
			"%#" .. mode_info.hl .. "Sep#",
			t.separators.powerline_right,
			"%*",
		})
	elseif style == "bubble" then
		-- Bubble style: rounded with shadow
		result = table.concat({
			"%#" .. mode_info.hl .. "Sep#",
			t.separators.powerline_right_thin,
			"%#" .. mode_info.hl .. "#",
			" ",
			mode_info.icon,
			" ",
			mode_info.name,
			" ",
			"%#" .. mode_info.hl .. "Sep#",
			t.separators.powerline_right_thin,
			"%*",
		})
	else
		-- Minimal style: simple with brackets
		result = table.concat({
			"%#" .. mode_info.hl .. "#",
			t.separators.bracket_left,
			" ",
			mode_info.icon,
			" ",
			mode_info.name,
			" ",
			t.separators.bracket_right,
			"%*",
		})
	end

	M.state.rendered.mode = result
	M.state.dirty.mode = false
	return result
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

	-- Refined separator before git section
	table.insert(parts, t.get_separator("bar_medium", "SLSeparatorProminent"))
	table.insert(parts, spacing("component"))

	if git_branch ~= "" then
		table.insert(parts, git_branch)
	end

	if git_status ~= "" then
		table.insert(parts, git_status)
	end

	table.insert(parts, spacing("component"))

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

	local parts = {}

	-- Subtle separator
	table.insert(parts, t.get_separator("dot_medium", "SLSeparatorSubtle"))
	table.insert(parts, spacing("component"))

	table.insert(
		parts,
		components.fileinfo({
			add_icon = M.config.components.file_info.show_icon,
			show_size = M.config.components.file_info.show_size,
		})
	)

	M.state.rendered.file = table.concat(parts)
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
	if diag == "" then
		M.state.rendered.diagnostics = ""
		M.state.dirty.diagnostics = false
		return ""
	end

	local parts = {}
	table.insert(parts, spacing("component"))
	table.insert(parts, t.get_separator("bar_medium", "SLSeparatorProminent"))
	table.insert(parts, spacing("component"))
	table.insert(parts, diag)

	M.state.rendered.diagnostics = table.concat(parts)
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
	if lsp_prog == "" then
		M.state.rendered.lsp = ""
		M.state.dirty.lsp = false
		return ""
	end

	local parts = {}
	table.insert(parts, lsp_prog)
	table.insert(parts, t.get_separator("dot_small", "SLSeparatorSubtle"))
	table.insert(parts, spacing("component"))

	M.state.rendered.lsp = table.concat(parts)
	M.state.dirty.lsp = false
	return M.state.rendered.lsp
end

local function render_position()
	if not M.state.dirty.position then
		return M.state.rendered.position
	end

	local parts = {}

	-- Prominent separator before position
	table.insert(parts, t.get_separator("bar_medium", "SLSeparatorProminent"))
	table.insert(parts, spacing("component"))

	-- Position info
	table.insert(parts, components.position())
	table.insert(parts, components.total_lines())

	table.insert(parts, spacing("component"))

	-- Progress visualization
	if M.config.components.progress.enabled then
		local style = M.config.components.progress.style

		if style == "modern" then
			-- Modern style: sleek bar with percentage
			table.insert(parts, t.get_separator("bar_thin", "SLSeparatorSubtle"))
			table.insert(parts, spacing("component"))
			table.insert(parts, components.progress_bar())
		elseif style == "percentage" then
			-- Just show percentage
			local line = vim.api.nvim_win_get_cursor(0)[1]
			local total = vim.api.nvim_buf_line_count(0)
			local pct = math.floor((line / total) * 100)
			table.insert(parts, "%#SLProgress#")
			table.insert(parts, pct .. "%%")
			table.insert(parts, "%*")
		else
			-- Bar style (default)
			table.insert(parts, t.get_separator("bar_medium", "SLSeparatorProminent"))
			table.insert(parts, spacing("component"))
			table.insert(parts, components.progress_bar())
		end

		table.insert(parts, spacing("component"))
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
			table.insert(parts, t.get_separator("dot_medium", "SLSeparatorSubtle"))
			table.insert(parts, spacing("component"))
		end
	end

	-- Active indicators (recording, search, etc.)
	if width >= 100 then
		for _, fn in ipairs({
			components.maximized_status,
			components.macro_recording,
			components.search_count,
		}) do
			local val = fn()
			if val ~= "" then
				table.insert(parts, val)
				table.insert(parts, spacing("component"))
			end
		end
	end

	-- File metadata (encoding, format)
	if width >= 120 then
		local enc = components.file_encoding()
		local fmt = components.file_format()
		if enc ~= "" or fmt ~= "" then
			table.insert(parts, t.get_separator("bar_thin", "SLSeparatorSubtle"))
			table.insert(parts, spacing("component"))
			if enc ~= "" then
				table.insert(parts, enc)
			end
			if fmt ~= "" then
				table.insert(parts, fmt)
			end
			table.insert(parts, spacing("component"))
		end
	end

	-- Filetype
	local filetype = components.filetype()
	if filetype ~= "" and width >= 100 then
		table.insert(parts, t.get_separator("bar_medium", "SLSeparatorProminent"))
		table.insert(parts, spacing("component"))
		table.insert(parts, filetype)
		table.insert(parts, spacing("component"))
	end

	M.state.rendered.right_info = table.concat(parts)
	M.state.dirty.right_info = false
	return M.state.rendered.right_info
end

-----------------------------------------------------------
-- STATUSLINE BUILDER
-----------------------------------------------------------

local function build_statusline_string()
	local width = vim.api.nvim_win_get_width(0)
	local ft = vim.bo.filetype

	-- Special filetypes with elegant design
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
		return "%#SLGitBranch#"
			.. " "
			.. t.icons.lightning
			.. " "
			.. ft:sub(1, 1):upper()
			.. ft:sub(2)
			.. " "
			.. t.separators.angle_right
			.. " "
			.. dir
			.. "%*"
	end

	-- Ultra-minimal mode for very narrow windows
	if width < defaults.spacing.component * 20 then
		return table.concat({
			render_mode(),
			"%=",
			components.position(),
			spacing("component"),
		})
	end

	-- Build main statusline sections
	local left = {
		render_mode(),
		spacing("section"),
		render_git(),
		render_file(),
	}

	-- Add diagnostics for wider windows
	if width >= 100 then
		table.insert(left, render_diagnostics())
	end

	local middle = { "%=" }

	local right = {}

	-- LSP progress
	if width >= M.config.components.lsp_progress.min_width then
		table.insert(right, render_lsp())
	end

	-- Right info section
	table.insert(right, render_right_info())

	-- Position section (always visible)
	table.insert(right, render_position())

	return table.concat(left) .. table.concat(middle) .. table.concat(right)
end

-----------------------------------------------------------
-- UPDATE FUNCTIONS
-----------------------------------------------------------

local function mark_dirty(component_name)
	if M.state.dirty[component_name] ~= nil then
		M.state.dirty[component_name] = true
	end
end

local function apply_update()
	local new_statusline = build_statusline_string()

	if new_statusline ~= M.state.statusline then
		M.state.statusline = new_statusline
		vim.o.statusline = new_statusline
		M.state.last_rebuild = vim.loop.now()
	end
end

local function update_immediate(component)
	mark_dirty(component)
	apply_update()
end

local function update_throttled(component, interval)
	local now = vim.loop.now()
	if now - last_update[component] < interval then
		return
	end
	last_update[component] = now
	mark_dirty(component)
	apply_update()
end

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
-- FALLBACK TIMER
-----------------------------------------------------------

local function start_fallback_timer()
	if timers.fallback then
		return
	end
	timers.fallback = vim.fn.timer_start(M.config.fallback_interval, function()
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

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = "StatuslineEvents",
		callback = function()
			update_immediate("mode")
		end,
	})

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "BufModifiedSet", "FileType" }, {
		group = "StatuslineEvents",
		callback = function()
			update_immediate("file")
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "GitSignsUpdate",
		group = "StatuslineEvents",
		callback = function()
			if vim.b.status_cache then
				vim.b.status_cache.git = nil
			end
			update_debounced("git", M.config.throttle_intervals.git)
		end,
	})

	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = "StatuslineEvents",
		callback = function()
			update_debounced("diagnostics", M.config.throttle_intervals.diagnostics)
		end,
	})

	vim.api.nvim_create_autocmd("LspProgress", {
		group = "StatuslineEvents",
		callback = function(args)
			-- LSP progress handling (same as before)
			local client_id = args.data and args.data.client_id
			local params = args.data and args.data.params
			if not (client_id and params and params.value) then
				return
			end

			local client = vim.lsp.get_client_by_id(client_id)
			local client_name = client and client.name or "LSP"
			local value = params.value

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

	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = "StatuslineEvents",
		callback = function()
			update_throttled("position", M.config.throttle_intervals.position)
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = "StatuslineEvents",
		callback = function()
			for component in pairs(M.state.dirty) do
				M.state.dirty[component] = true
			end
			apply_update()
		end,
	})

	vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave", "SearchWrapped" }, {
		group = "StatuslineEvents",
		callback = function()
			update_immediate("right_info")
		end,
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = "StatuslineEvents",
		callback = function()
			stop_fallback_timer()
			for _, timer in pairs(timers.debounce) do
				if timer then
					vim.fn.timer_stop(timer)
				end
			end
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

	-- Apply theme
	t = theme.apply()

	-- Update components config
	components.setup({
		icon_set = opts.icon_set,
		separator_style = opts.separator_style,
	})

	-- Store theme reference in M for external access
	M.theme = t

	-- Setup event handlers
	setup_events()

	-- Initial build
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

function M.rebuild()
	for component in pairs(M.state.dirty) do
		M.state.dirty[component] = true
	end
	apply_update()
end

function M.update_component(name)
	if M.state.dirty[name] ~= nil then
		mark_dirty(name)
		apply_update()
	end
end

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
