---@module "statusline"
local M = {}

local components = require("statusline.component")

--- Default config with modern design
local defaults = {
	-- Modern color palette (vibrant and bright)
	colors = {
		bg = "#1a1b26",
		fg = "#c0caf5",
		bg_light = "#24283b",
		bg_highlight = "#292e42",
		blue = "#7aa2f7",
		cyan = "#7dcfff",
		green = "#9ece6a",
		purple = "#bb9af7",
		red = "#f7768e",
		orange = "#ff9e64",
		yellow = "#e0af68",
		gray = "#565f89",
		dark_gray = "#3b4261",
	},

	icon_set = "nerd_v3", -- "nerd_v3", "nerd_v2", "ascii"
	separator_style = "rounded", -- "rounded", "arrow", "vertical"

	components = {
		mode = { enabled = true },
		git = { enabled = true },
		diagnostics = { enabled = true },
		file_info = { enabled = true, show_size = false },
		progress = { enabled = true },
	},

	refresh_rate = 100,
}

-- Debounced redraw
local redraw_timer = nil
local function debounced_redraw(delay)
	delay = delay or defaults.refresh_rate
	if redraw_timer then
		vim.fn.timer_stop(redraw_timer)
	end
	redraw_timer = vim.fn.timer_start(delay, function()
		vim.cmd("redrawstatus")
		redraw_timer = nil
	end)
end

--- Setup function
function M.setup(opts)
	opts = vim.tbl_deep_extend("force", defaults, opts or {})
	M.config = opts

	-- Store colors for components
	M.colors = opts.colors

	-- Modern highlight groups with better contrast
	local c = opts.colors

	-- Base statusline
	vim.api.nvim_set_hl(0, "StatusLine", { bg = c.bg, fg = c.fg })
	vim.api.nvim_set_hl(0, "StatusLineNC", { bg = c.bg, fg = c.gray })

	-- Component highlights with backgrounds
	local highlights = {
		-- File info section with background
		SLFileSection = { fg = c.fg, bg = c.bg_light, bold = true },
		SLFileIcon = { fg = c.cyan, bg = c.bg_light },
		SLFileName = { fg = c.fg, bg = c.bg_light, bold = true },
		SLModified = { fg = c.red, bg = c.bg_light, bold = true },
		SLReadonly = { fg = c.orange, bg = c.bg_light },
		SLFiletype = { fg = c.purple, bg = c.bg_highlight },

		-- Git section with background
		SLGitSection = { bg = c.bg_highlight },
		SLGitBranch = { fg = c.purple, bg = c.bg_highlight, bold = true },
		SLGitAdded = { fg = c.green, bg = c.bg_highlight },
		SLGitChanged = { fg = c.yellow, bg = c.bg_highlight },
		SLGitRemoved = { fg = c.red, bg = c.bg_highlight },

		-- Diagnostics with icons
		SLDiagError = { fg = c.red, bg = c.bg },
		SLDiagWarn = { fg = c.yellow, bg = c.bg },
		SLDiagInfo = { fg = c.blue, bg = c.bg },
		SLDiagHint = { fg = c.cyan, bg = c.bg },

		-- Position section
		SLPosition = { fg = c.fg, bg = c.bg_highlight, bold = true },
		SLProgress = { fg = c.cyan, bg = c.bg_highlight },

		-- Separators
		SLSep = { fg = c.dark_gray, bg = c.bg },
		SLSepBgLight = { fg = c.bg_light, bg = c.bg },
		SLSepBgHighlight = { fg = c.bg_highlight, bg = c.bg },
		SLSepLightToHighlight = { fg = c.bg_light, bg = c.bg_highlight },

		-- Special indicators
		SLIndicator = { fg = c.bg, bg = c.cyan, bold = true },
		SLSearch = { fg = c.bg, bg = c.yellow, bold = true },
	}

	for name, hl_opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, hl_opts)
	end

	-- Mode colors - vibrant and distinct
	local mode_colors = {
		Normal = { bg = c.blue, fg = c.bg },
		Insert = { bg = c.green, fg = c.bg },
		Visual = { bg = c.purple, fg = c.bg },
		Replace = { bg = c.red, fg = c.bg },
		Command = { bg = c.yellow, fg = c.bg },
		Terminal = { bg = c.cyan, fg = c.bg },
		Select = { bg = c.orange, fg = c.bg },
	}

	-- Create mode highlights
	for name, color in pairs(mode_colors) do
		vim.api.nvim_set_hl(0, "SLMode" .. name, {
			bg = color.bg,
			fg = color.fg,
			bold = true,
		})
		-- Separator from mode to bg
		vim.api.nvim_set_hl(0, "SLMode" .. name .. "Sep", {
			fg = color.bg,
			bg = c.bg,
		})
		-- Separator from mode to bg_light
		vim.api.nvim_set_hl(0, "SLMode" .. name .. "ToLight", {
			fg = color.bg,
			bg = c.bg_light,
		})
	end

	-- Mode configuration with icons
	local mode_config = {
		-- Normal modes
		n = { name = "NORMAL", hl = "SLModeNormal", icon = "" },
		no = { name = "N·OP", hl = "SLModeNormal", icon = "" },
		nov = { name = "N·OP", hl = "SLModeNormal", icon = "" },
		noV = { name = "N·OP", hl = "SLModeNormal", icon = "" },
		["no\22"] = { name = "N·OP", hl = "SLModeNormal", icon = "" },

		-- Visual modes
		v = { name = "VISUAL", hl = "SLModeVisual", icon = "󰈈" },
		V = { name = "V·LINE", hl = "SLModeVisual", icon = "󰈈" },
		["\22"] = { name = "V·BLOCK", hl = "SLModeVisual", icon = "󰩬" },

		-- Select modes
		s = { name = "SELECT", hl = "SLModeSelect", icon = "󰈈" },
		S = { name = "S·LINE", hl = "SLModeSelect", icon = "󰈈" },
		["\19"] = { name = "S·BLOCK", hl = "SLModeSelect", icon = "󰈈" },

		-- Insert modes
		i = { name = "INSERT", hl = "SLModeInsert", icon = "" },
		ic = { name = "INSERT", hl = "SLModeInsert", icon = "" },
		ix = { name = "INSERT", hl = "SLModeInsert", icon = "" },

		-- Replace modes
		R = { name = "REPLACE", hl = "SLModeReplace", icon = "󰛔" },
		Rc = { name = "REPLACE", hl = "SLModeReplace", icon = "󰛔" },
		Rv = { name = "V·REPLACE", hl = "SLModeReplace", icon = "󰛔" },
		Rx = { name = "REPLACE", hl = "SLModeReplace", icon = "󰛔" },

		-- Command modes
		c = { name = "COMMAND", hl = "SLModeCommand", icon = "󰘳" },
		cv = { name = "COMMAND", hl = "SLModeCommand", icon = "󰘳" },
		ce = { name = "COMMAND", hl = "SLModeCommand", icon = "󰘳" },

		-- Terminal mode
		t = { name = "TERMINAL", hl = "SLModeTerminal", icon = "" },

		-- Misc
		r = { name = "PROMPT", hl = "SLModeCommand", icon = "" },
		rm = { name = "MORE", hl = "SLModeCommand", icon = "" },
		["r?"] = { name = "CONFIRM", hl = "SLModeCommand", icon = "" },
		["!"] = { name = "SHELL", hl = "SLModeTerminal", icon = "" },
	}

	-- Get mode info
	local function get_mode_info()
		local ok, mode_data = pcall(vim.api.nvim_get_mode)
		if not ok then
			return mode_config.n
		end
		return mode_config[mode_data.mode] or mode_config.n
	end

	-- Modern mode indicator with rounded bubble style
	local function mode_indicator()
		local info = get_mode_info()
		local sep = "█"

		return table.concat({
			"%#" .. info.hl .. "#",
			" ",
			info.icon,
			" ",
			info.name,
			" ",
			"%#" .. info.hl .. "Sep#",
			sep,
			"%*",
		})
	end

	-- Separator helper
	local function separator(from_hl, to_hl, char)
		char = char or "█"
		local hl = from_hl and to_hl and (from_hl .. "To" .. to_hl:gsub("^SL", "")) or "SLSep"
		return "%#" .. hl .. "#" .. char .. "%*"
	end

	-- Main statusline builder
	local function Status_line()
		local width = vim.api.nvim_win_get_width(0)
		local ft = vim.bo.filetype

		-- Special filetypes
		local special = {
			"neo-tree",
			"NvimTree",
			"oil",
			"TelescopePrompt",
			"alpha",
			"dashboard",
			"lazy",
		}

		if vim.tbl_contains(special, ft) then
			local home = vim.loop.os_homedir() or ""
			local dir = vim.fn.getcwd():gsub("^" .. home, "~")
			return "%#SLIndicator#  " .. ft:sub(1, 1):upper() .. ft:sub(2) .. " ▸ " .. dir .. "%*"
		end

		-- Minimal mode for very narrow windows
		if width < 70 then
			return table.concat({
				mode_indicator(),
				" ",
				components.position(),
			})
		end

		-- Left side
		local left = {}
		table.insert(left, mode_indicator())

		-- File info section with background
		if opts.components.file_info.enabled then
			table.insert(left, " ")
			local fileinfo = components.fileinfo({
				add_icon = true,
				show_size = opts.components.file_info.show_size,
			})
			if fileinfo ~= "" then
				table.insert(left, "%#SLSepBgLight#█%*")
				table.insert(left, fileinfo)
				table.insert(left, "%#SLSepBgLight#█%*")
			end
		end

		-- Git section with background
		if opts.components.git.enabled and width >= 90 then
			local git_branch = components.git_branch()
			local git_status = components.git_status()
			if git_branch ~= "" or git_status ~= "" then
				table.insert(left, " ")
				table.insert(left, "%#SLSepBgHighlight#█%*")
				if git_branch ~= "" then
					table.insert(left, git_branch)
				end
				if git_status ~= "" then
					table.insert(left, git_status)
				end
				table.insert(left, "%#SLSepBgHighlight#█%*")
			end
		end

		-- Diagnostics
		if opts.components.diagnostics.enabled and width >= 100 then
			local diagnostics = components.diagnostics()
			if diagnostics ~= "" then
				table.insert(left, "  ")
				table.insert(left, diagnostics)
			end
		end

		-- Middle (empty space)
		local middle = { "%=" }

		-- Right side
		local right = {}

		-- Special indicators
		if width >= 100 then
			for _, fn in ipairs({
				components.search_count,
				components.macro_recording,
			}) do
				local val = fn()
				if val ~= "" then
					table.insert(right, val)
					table.insert(right, "  ")
				end
			end
		end

		-- Filetype with background
		local filetype = components.filetype()
		if filetype ~= "" and width >= 100 then
			table.insert(right, "%#SLSepBgHighlight#█%*")
			table.insert(right, filetype)
			table.insert(right, "%#SLSepBgHighlight#█%*")
			table.insert(right, " ")
		end

		-- Position with background
		table.insert(right, "%#SLSepBgHighlight#█%*")
		table.insert(right, components.position())
		table.insert(right, " ")
		table.insert(right, components.progress())
		table.insert(right, "%#SLSepBgHighlight#█%*")

		return table.concat(left) .. table.concat(middle) .. table.concat(right)
	end

	-- Set the statusline
	vim.o.statusline = "%!luaeval(\"require('statusline').Status_line()\")"

	-- Smart redraw with debouncing
	local augroup = vim.api.nvim_create_augroup("StatuslineEvents", { clear = true })

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = augroup,
		callback = function()
			debounced_redraw(16)
		end,
	})

	vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufWritePost" }, {
		group = augroup,
		callback = function()
			debounced_redraw(opts.refresh_rate)
		end,
	})

	vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "WinEnter" }, {
		group = augroup,
		callback = function()
			vim.cmd("redrawstatus")
		end,
	})

	-- Git status updates
	vim.api.nvim_create_autocmd("User", {
		pattern = "GitSignsUpdate",
		group = augroup,
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
