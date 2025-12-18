---@module "custom.statusline"
local M = {}

-- Cache API functions at module level (OPTIMIZATION: reduces table lookups)
local api = vim.api
local fn = vim.fn
local uv = vim.loop or vim.uv
local cmd = vim.cmd

local components = require("statusline.component")

--- Default config
local defaults = {
	bg_hex = "#1f2335",
	fg_main = "#c0caf5",
	fg_dim = "#565f89",

	-- New configuration options
	icon_set = "nerd_v3", -- "nerd_v3", "nerd_v2", "ascii"
	separator_style = "vertical", -- "vertical", "angle_right", "dot"

	components = {
		mode = { enabled = true, style = "bubble" },
		git = { enabled = true },
		diagnostics = { enabled = true },
		file_info = { enabled = true, show_size = true },
		progress = { enabled = true, style = "bar" },
	},

	refresh_rate = 100, -- ms for debounce
	cache_timeout = 10000, -- ms
}

-- Mode configuration with modern icons (OPTIMIZATION: pre-computed at module level)
local MODE_CONFIG = {
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
	i = { name = "INSERT", hl = "StatusInsert", icon = "󰫫", desc = "Insert" },
	ic = { name = "I·COMP", hl = "StatusInsert", icon = "󰫫", desc = "Insert Completion" },
	ix = { name = "I·COMP", hl = "StatusInsert", icon = "󰫫", desc = "Insert Completion" },

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
	["!"] = { name = "SHELL", hl = "StatusTerminal", icon = "󱞕", desc = "Shell" },
}

-- Optimized debounce using vim.defer_fn (OPTIMIZATION: faster than vim.fn.timer_*)
local redraw_pending = false
local function debounced_redraw(delay)
	if redraw_pending then
		return
	end
	redraw_pending = true

	vim.defer_fn(function()
		cmd("redrawstatus")
		redraw_pending = false
	end, delay or defaults.refresh_rate)
end

-- Get mode info with error handling (OPTIMIZATION: direct access to pre-computed config)
local function get_mode_info()
	local ok, mode_data = pcall(api.nvim_get_mode)
	if not ok then
		return MODE_CONFIG.n
	end
	return MODE_CONFIG[mode_data.mode] or MODE_CONFIG.n
end

--- Setup function
function M.setup(opts)
	opts = vim.tbl_deep_extend("force", defaults, opts or {})
	M.config = opts

	-- Color palette with error handling
	local ok, statusline_hl = pcall(api.nvim_get_hl, 0, { name = "StatusLine" })
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

	-- Lualine-style highlight groups
	local highlights = {
		SLBgNoneHl = { fg = fg_main, bg = "none" },
		SLNotModifiable = { fg = "#e0af68", bg = bg_hex, italic = true },
		SLNormal = { fg = fg_main, bg = bg_hex },
		SLModified = { fg = "#f7768e", bg = bg_hex, bold = true },
		SLMatches = { fg = "#1a1b26", bg = "#7dcfff", bold = true },
		SLDim = { fg = fg_dim, bg = bg_hex },
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
	}

	-- OPTIMIZATION: Set highlights in batch
	for name, hl_opts in pairs(highlights) do
		api.nvim_set_hl(0, name, hl_opts)
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
		api.nvim_set_hl(0, "Status" .. name, {
			bg = color,
			fg = "#1a1b26",
			bold = true,
		})
		api.nvim_set_hl(0, "Status" .. name .. "Sep", {
			fg = color,
			bg = bg_hex,
		})
	end

	for name, color in pairs(mode_colors) do
		create_mode_hl(name, color)
	end

	-- Lualine-style mode indicator with rounded edges (bubble style)
	local function mode_indicator()
		local info = get_mode_info()

		return table.concat({
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
	end

	-- Right-side separator
	local function section_sep()
		return components.separator(opts.separator_style) .. " "
	end

	-- OPTIMIZATION: Cache special filetypes at module level
	local special_filetypes = {
		["neo-tree"] = true,
		["minifiles"] = true,
		["oil"] = true,
		["TelescopePrompt"] = true,
		["fzf"] = true,
		["snacks_picker_input"] = true,
		["alpha"] = true,
		["dashboard"] = true,
		["NvimTree"] = true,
		["packer"] = true,
		["lazy"] = true,
	}

	-- Main statusline builder with responsive design
	local function Status_line()
		local width = api.nvim_win_get_width(0)
		local ft = vim.bo.filetype

		-- OPTIMIZATION: Use hash lookup instead of vim.tbl_contains
		if special_filetypes[ft] then
			local home = uv.os_homedir() or ""
			local dir = (uv.cwd() or fn.getcwd()):gsub("^" .. home, "~") -- OPTIMIZATION: Use uv.cwd() instead of fn.getcwd()
			return components.get_or_create_hl("#7dcfff", bg_hex, { bold = true })
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
				mode_indicator(),
				"%=",
				components.position(),
				components.padding(1),
			})
		end

		-- Left side
		local left = { mode_indicator(), components.padding(2) }

		if opts.components.git.enabled then
			local git_branch = components.git_branch()
			local git_status = components.git_status()
			if git_branch ~= "" or git_status ~= "" then
				if git_branch ~= "" then
					left[#left + 1] = git_branch -- OPTIMIZATION: Use #left + 1 instead of table.insert
				end
				if git_status ~= "" then
					left[#left + 1] = components.padding(1)
					left[#left + 1] = git_status
				end
				left[#left + 1] = section_sep()
			end
		end

		if opts.components.file_info.enabled then
			left[#left + 1] = components.fileinfo({ add_icon = true, show_size = opts.components.file_info.show_size })
		end

		if opts.components.diagnostics.enabled and width >= 100 then
			local diagnostics = components.diagnostics()
			if diagnostics ~= "" then
				left[#left + 1] = section_sep()
				left[#left + 1] = diagnostics
			end
		end

		-- Middle (empty)
		local middle = { "%=" }

		-- Right side
		local right = {}

		-- Show any active indicators (only in wider windows)
		if width >= 100 then
			for _, fn_comp in ipairs({
				components.maximized_status,
				components.macro_recording,
				components.search_count,
			}) do
				local val = fn_comp()
				if val ~= "" then
					right[#right + 1] = val
				end
			end
		end

		-- File info (encoding/format) - skip in narrow windows
		if width >= 120 then
			local enc = components.file_encoding()
			local fmt = components.file_format()
			if enc ~= "" or fmt ~= "" then
				right[#right + 1] = section_sep()
				if enc ~= "" then
					right[#right + 1] = enc
				end
				if fmt ~= "" then
					right[#right + 1] = fmt
				end
			end
		end

		-- Filetype
		local filetype = components.filetype()
		if filetype ~= "" and width >= 100 then
			right[#right + 1] = section_sep()
			right[#right + 1] = filetype
			right[#right + 1] = components.padding(1)
		end

		-- Position info (always show)
		right[#right + 1] = section_sep()
		right[#right + 1] = components.position()
		right[#right + 1] = components.total_lines()
		right[#right + 1] = components.padding(1)

		-- Progress bar (only in wider windows)
		if opts.components.progress.enabled and width >= 100 then
			right[#right + 1] = section_sep()
			right[#right + 1] = components.progress_bar()
			right[#right + 1] = components.padding(1)
		end

		return table.concat(left) .. table.concat(middle) .. table.concat(right)
	end

	-- Set the statusline
	vim.o.statusline = "%!luaeval(\"require('statusline').Status_line()\")"

	-- Smart redraw with debouncing
	api.nvim_create_augroup("StatuslineEvents", { clear = true })

	-- OPTIMIZATION: No debounce for mode changes (immediate feedback)
	api.nvim_create_autocmd({ "ModeChanged" }, {
		group = "StatuslineEvents",
		callback = function()
			cmd("redrawstatus")
		end,
	})

	-- OPTIMIZATION: Increased debounce for less critical updates
	api.nvim_create_autocmd({ "DiagnosticChanged", "BufWritePost" }, {
		group = "StatuslineEvents",
		callback = function()
			debounced_redraw(opts.refresh_rate)
		end,
	})

	api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
		group = "StatuslineEvents",
		callback = function()
			cmd("redrawstatus")
		end,
	})

	-- Git status updates
	api.nvim_create_autocmd("User", {
		pattern = "GitSignsUpdate",
		group = "StatuslineEvents",
		callback = function()
			if vim.b.status_cache then
				vim.b.status_cache.git = nil
			end
			debounced_redraw(opts.refresh_rate)
		end,
	})

	-- Expose Status_line for external calls
	M.Status_line = Status_line
end

return M
