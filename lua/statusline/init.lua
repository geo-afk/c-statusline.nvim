---@module "custom.statusline"
local M = {}

local components = require("statusline.component")

--- Default config
local defaults = {
	bg_hex = "#1f2335", -- Fallback bg
	fg_main = "#c0caf5",
	fg_dim = "#565f89",
}

--- Setup function
function M.setup(opts)
	opts = vim.tbl_deep_extend("force", defaults, opts or {})

	-- Color palette
	local statusline_hl = vim.api.nvim_get_hl(0, { name = "StatusLine" })
	local bg_hex
	if statusline_hl and statusline_hl.bg and statusline_hl.bg ~= 0 then
		bg_hex = string.format("#%06x", statusline_hl.bg)
	else
		bg_hex = opts.bg_hex or "#1f2335" -- fallback to config or default
	end
	local fg_main = opts.fg_main or "#c0caf5"
	local fg_dim = opts.fg_dim or "#565f89"

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

	for name, hl_opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, hl_opts)
	end

	-- Mode colors (lualine-inspired bubbles)
	local mode_colors = {
		Normal = "#7aa2f7",
		Insert = "#9ece6a",
		Visual = "#bb9af7",
		Replace = "#f7768e",
		Command = "#e0af68",
		Terminal = "#73daca",
		Select = "#ff9e64",
	}

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

	-- Mode configuration (unchanged)
	local mode_config = {
		-- Normal modes
		n = { name = "NORMAL", hl = "StatusNormal", icon = "󰋜", desc = "Normal" },
		no = { name = "N·OP", hl = "StatusNormal", icon = "󰋜", desc = "Operator Pending" },
		nov = { name = "N·OP·V", hl = "StatusNormal", icon = "󰋜", desc = "Operator Pending Char" },
		noV = { name = "N·OP·L", hl = "StatusNormal", icon = "󰋜", desc = "Operator Pending Line" },
		["no�"] = { name = "N·OP·B", hl = "StatusNormal", icon = "󰋜", desc = "Operator Pending Block" },

		-- Visual modes
		v = { name = "VISUAL", hl = "StatusVisual", icon = "󰈈", desc = "Visual" },
		V = { name = "V·LINE", hl = "StatusVisual", icon = "󰈈", desc = "Visual Line" },
		["�"] = { name = "V·BLOCK", hl = "StatusVisual", icon = "󰈈", desc = "Visual Block" },

		-- Select modes
		s = { name = "SELECT", hl = "StatusSelect", icon = "󰈈", desc = "Select" },
		S = { name = "S·LINE", hl = "StatusSelect", icon = "󰈈", desc = "Select Line" },
		["�"] = { name = "S·BLOCK", hl = "StatusSelect", icon = "󰈈", desc = "Select Block" },

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
		["!"] = { name = "SHELL", hl = "StatusTerminal", icon = "", desc = "Shell" },
	}

	-- Get mode info
	local function get_mode_info()
		local mode = vim.api.nvim_get_mode().mode
		return mode_config[mode] or mode_config.n
	end

	-- Lualine-style mode indicator with rounded edges
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

	-- Right-side separator (lualine style)
	local function section_sep()
		return components.separator() .. " "
	end

	-- Main statusline builder
	local function Status_line()
		local ft = vim.bo.filetype
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
			return components.get_or_create_hl("#7dcfff", bg_hex, { bold = true })
				.. " ✦ "
				.. ft:sub(1, 1):upper()
				.. ft:sub(2)
				.. " ▸ "
				.. dir
				.. "%*"
		end

		-- Left side
		local left = { mode_indicator(), components.padding(1) }

		local git_branch = components.git_branch()
		local git_status = components.git_status()
		if git_branch ~= "" or git_status ~= "" then
			if git_branch ~= "" then
				table.insert(left, git_branch)
			end
			if git_status ~= "" then
				table.insert(left, git_status)
			end
			table.insert(left, section_sep())
		end

		table.insert(left, components.fileinfo({ add_icon = true }))

		local diagnostics = components.diagnostics()
		if diagnostics ~= "" then
			table.insert(left, section_sep())
			table.insert(left, diagnostics)
		end

		-- Middle (empty)
		local middle = { "%=" }

		-- Right side
		local right = {}

		-- Show any active indicators
		for _, fn in ipairs({ components.maximized_status, components.macro_recording, components.search_count }) do
			local val = fn()
			if val ~= "" then
				table.insert(right, val)
			end
		end

		-- File info
		local enc = components.file_encoding()
		local fmt = components.file_format()
		if enc ~= "" or fmt ~= "" then
			table.insert(right, section_sep())
			if enc ~= "" then
				table.insert(right, enc)
			end
			if fmt ~= "" then
				table.insert(right, fmt)
			end
		end

		-- Filetype
		local filetype = components.filetype()
		if filetype ~= "" then
			table.insert(right, section_sep())
			table.insert(right, filetype)
			table.insert(right, components.padding(1))
		end

		-- Position info
		table.insert(right, section_sep())
		table.insert(right, components.position())
		table.insert(right, components.total_lines())
		table.insert(right, components.padding(1))
		table.insert(right, section_sep())
		table.insert(right, components.progress_bar())
		table.insert(right, components.padding(1))

		return table.concat(left) .. table.concat(middle) .. table.concat(right)
	end

	-- Set the statusline
	vim.o.statusline = "%!luaeval(\"require('statusline').Status_line()\")"

	-- Smart redraw on relevant events
	vim.api.nvim_create_augroup("StatuslineEvents", { clear = true })
	vim.api.nvim_create_autocmd({ "ModeChanged", "DiagnosticChanged", "BufWritePost", "FileType", "BufEnter" }, {
		group = "StatuslineEvents",
		callback = function()
			vim.cmd("redrawstatus")
		end,
	})

	-- Expose Status_line for external calls if needed
	M.Status_line = Status_line
end

return M
