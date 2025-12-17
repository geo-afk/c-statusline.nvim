---@module "custom.statusline"
local M = {}

local components = require("statusline.component")

--- Default config
local defaults = {
	-- Modern color scheme with rich backgrounds
	colors = {
		-- Mode colors (vibrant, high contrast)
		mode_normal = "#7aa2f7",
		mode_insert = "#9ece6a",
		mode_visual = "#bb9af7",
		mode_replace = "#f7768e",
		mode_command = "#e0af68",
		mode_terminal = "#73daca",
		mode_select = "#ff9e64",

		-- Background colors
		bg_main = "#1f2335", -- Main statusline background
		bg_section = "#24283b", -- Section backgrounds
		bg_accent = "#414868", -- Accent backgrounds

		-- Foreground colors
		fg_main = "#c0caf5", -- Primary text
		fg_dim = "#565f89", -- Dimmed text
		fg_bright = "#ffffff", -- Bright text
		fg_dark = "#1a1b26", -- Dark text (for mode labels)

		-- Component colors
		git_branch = "#bb9af7",
		git_added = "#9ece6a",
		git_changed = "#e0af68",
		git_removed = "#f7768e",
		diagnostic_error = "#f7768e",
		diagnostic_warn = "#e0af68",
		diagnostic_info = "#0db9d7",
		diagnostic_hint = "#1abc9c",
		lsp_active = "#bb9af7",
		folder = "#7aa2f7",
	},

	-- Style options
	style = "bubble", -- "bubble", "powerline", "minimal"
	separator_style = "round", -- "round", "angle", "vertical"

	components = {
		mode = { enabled = true },
		git = { enabled = true },
		diagnostics = { enabled = true },
		file_info = { enabled = true, show_size = true },
		folder = { enabled = true },
		lsp = { enabled = true },
		position = { enabled = true, style = "enhanced" },
		progress = { enabled = true, style = "bar" },
	},

	refresh_rate = 100,
	cache_timeout = 10000,
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

	local colors = opts.colors

	-- Enhanced highlight groups with backgrounds
	local highlights = {
		-- Base statusline
		SLBackground = { fg = colors.fg_main, bg = colors.bg_main },
		SLSection = { fg = colors.fg_main, bg = colors.bg_section },
		SLAccent = { fg = colors.fg_bright, bg = colors.bg_accent, bold = true },

		-- Text variants
		SLDim = { fg = colors.fg_dim, bg = colors.bg_main },
		SLBright = { fg = colors.fg_bright, bg = colors.bg_main, bold = true },
		SLModified = { fg = colors.diagnostic_error, bg = colors.bg_main, bold = true },
		SLNotModifiable = { fg = colors.diagnostic_warn, bg = colors.bg_main, italic = true },

		-- File info
		SLFileInfo = { fg = colors.fg_bright, bg = colors.bg_section, bold = true },
		SLFiletype = { fg = colors.lsp_active, bg = colors.bg_section },
		SLFolder = { fg = colors.folder, bg = colors.bg_section },

		-- Position with background
		SLPosition = { fg = colors.fg_bright, bg = colors.bg_accent, bold = true },
		SLPositionLabel = { fg = colors.fg_dim, bg = colors.bg_accent },

		-- Git with backgrounds
		SLGitBranch = { fg = colors.fg_dark, bg = colors.git_branch, bold = true },
		SLGitAdded = { fg = colors.git_added, bg = colors.bg_section },
		SLGitChanged = { fg = colors.git_changed, bg = colors.bg_section },
		SLGitRemoved = { fg = colors.git_removed, bg = colors.bg_section },

		-- LSP
		SLLspActive = { fg = colors.fg_dark, bg = colors.lsp_active, bold = true },
		SLLspCount = { fg = colors.fg_dim, bg = colors.bg_section },

		-- Diagnostics (keep existing diagnostic colors)
		SLDiagError = { fg = colors.diagnostic_error, bg = colors.bg_section },
		SLDiagWarn = { fg = colors.diagnostic_warn, bg = colors.bg_section },
		SLDiagInfo = { fg = colors.diagnostic_info, bg = colors.bg_section },
		SLDiagHint = { fg = colors.diagnostic_hint, bg = colors.bg_section },

		-- Separators
		SLSeparator = { fg = colors.bg_accent, bg = colors.bg_main },

		-- Encoding/Format
		SLEncoding = { fg = colors.fg_dim, bg = colors.bg_section },
		SLFormat = { fg = colors.fg_dim, bg = colors.bg_section },

		-- Search matches
		SLMatches = { fg = colors.fg_dark, bg = "#7dcfff", bold = true },

		-- Progress bar
		SLProgressFilled = { fg = colors.mode_normal, bg = colors.bg_section, bold = true },
		SLProgressEmpty = { fg = colors.bg_accent, bg = colors.bg_section },
	}

	for name, hl_opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, hl_opts)
	end

	-- Mode highlight groups with backgrounds
	local function create_mode_hl(name, color)
		-- Mode section background
		vim.api.nvim_set_hl(0, "Status" .. name, {
			bg = color,
			fg = colors.fg_dark,
			bold = true,
		})
		-- Separator that transitions from mode color to main bg
		vim.api.nvim_set_hl(0, "Status" .. name .. "Sep", {
			fg = color,
			bg = colors.bg_main,
		})
	end

	create_mode_hl("Normal", colors.mode_normal)
	create_mode_hl("Insert", colors.mode_insert)
	create_mode_hl("Visual", colors.mode_visual)
	create_mode_hl("Replace", colors.mode_replace)
	create_mode_hl("Command", colors.mode_command)
	create_mode_hl("Terminal", colors.mode_terminal)
	create_mode_hl("Select", colors.mode_select)

	-- Mode configuration
	local mode_config = {
		n = { name = "NORMAL", hl = "StatusNormal", icon = "", desc = "Normal" },
		no = { name = "N·OP", hl = "StatusNormal", icon = "", desc = "Operator Pending" },
		nov = { name = "N·OP·V", hl = "StatusNormal", icon = "", desc = "Operator Pending Char" },
		noV = { name = "N·OP·L", hl = "StatusNormal", icon = "", desc = "Operator Pending Line" },
		["no\22"] = { name = "N·OP·B", hl = "StatusNormal", icon = "", desc = "Operator Pending Block" },
		v = { name = "VISUAL", hl = "StatusVisual", icon = "", desc = "Visual" },
		V = { name = "V·LINE", hl = "StatusVisual", icon = "", desc = "Visual Line" },
		["\22"] = { name = "V·BLOCK", hl = "StatusVisual", icon = "", desc = "Visual Block" },
		s = { name = "SELECT", hl = "StatusSelect", icon = "", desc = "Select" },
		S = { name = "S·LINE", hl = "StatusSelect", icon = "", desc = "Select Line" },
		["\19"] = { name = "S·BLOCK", hl = "StatusSelect", icon = "", desc = "Select Block" },
		i = { name = "INSERT", hl = "StatusInsert", icon = "", desc = "Insert" },
		ic = { name = "I·COMP", hl = "StatusInsert", icon = "", desc = "Insert Completion" },
		ix = { name = "I·COMP", hl = "StatusInsert", icon = "", desc = "Insert Completion" },
		R = { name = "REPLACE", hl = "StatusReplace", icon = "", desc = "Replace" },
		Rc = { name = "R·COMP", hl = "StatusReplace", icon = "", desc = "Replace Completion" },
		Rv = { name = "V·REPLACE", hl = "StatusReplace", icon = "", desc = "Virtual Replace" },
		Rx = { name = "R·COMP", hl = "StatusReplace", icon = "", desc = "Replace Completion" },
		c = { name = "COMMAND", hl = "StatusCommand", icon = "", desc = "Command" },
		cv = { name = "EX", hl = "StatusCommand", icon = "", desc = "Ex" },
		ce = { name = "EX", hl = "StatusCommand", icon = "", desc = "Ex" },
		t = { name = "TERMINAL", hl = "StatusTerminal", icon = "", desc = "Terminal" },
		r = { name = "PROMPT", hl = "StatusCommand", icon = "?", desc = "Hit Enter Prompt" },
		rm = { name = "MORE", hl = "StatusCommand", icon = "?", desc = "More" },
		["r?"] = { name = "CONFIRM", hl = "StatusCommand", icon = "?", desc = "Confirm" },
		["!"] = { name = "SHELL", hl = "StatusTerminal", icon = "", desc = "Shell" },
	}

	local function get_mode_info()
		local ok, mode_data = pcall(vim.api.nvim_get_mode)
		if not ok then
			return mode_config.n
		end
		return mode_config[mode_data.mode] or mode_config.n
	end

	-- Separator functions based on style
	local function get_separator_chars()
		if opts.separator_style == "round" then
			return { left = "", right = "", left_alt = "", right_alt = "" }
		elseif opts.separator_style == "angle" then
			return { left = "", right = "", left_alt = "", right_alt = "" }
		else -- vertical
			return { left = "│", right = "│", left_alt = "│", right_alt = "│" }
		end
	end

	local sep_chars = get_separator_chars()

	-- Modern bubble-style mode indicator
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
			sep_chars.right,
			"%*",
		})
	end

	-- Section wrapper with background
	local function section(content, hl_group)
		if content == "" then
			return ""
		end
		hl_group = hl_group or "SLSection"
		return "%#" .. hl_group .. "#" .. " " .. content .. " " .. "%*"
	end

	-- Separator with transition
	local function section_sep()
		return "%#SLSeparator#" .. sep_chars.left_alt .. "%*"
	end

	-- Main statusline builder
	local function Status_line()
		local width = vim.api.nvim_win_get_width(0)
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
			return section(" ✦ " .. ft:sub(1, 1):upper() .. ft:sub(2) .. " ▸ " .. dir, "SLAccent")
		end

		-- Minimal mode for very narrow windows
		if width < 80 then
			return table.concat({
				mode_indicator(),
				"%=",
				section(components.position_enhanced(), "SLPosition"),
			})
		end

		-- Left side
		local left = { mode_indicator(), " " }

		-- Git branch with bubble background
		if opts.components.git.enabled then
			local git_branch = components.git_branch()
			if git_branch ~= "" then
				table.insert(left, section(git_branch, "SLGitBranch"))
			end

			-- Git stats
			local git_status = components.git_status()
			if git_status ~= "" then
				table.insert(left, " ")
				table.insert(left, section(git_status, "SLSection"))
			end
		end

		-- Folder name
		if opts.components.folder.enabled and width >= 100 then
			local folder = components.folder_name()
			if folder ~= "" then
				table.insert(left, section_sep())
				table.insert(left, section(folder, "SLFolder"))
			end
		end

		-- File info
		if opts.components.file_info.enabled then
			table.insert(left, section_sep())
			table.insert(
				left,
				section(
					components.fileinfo({ add_icon = true, show_size = opts.components.file_info.show_size }),
					"SLFileInfo"
				)
			)
		end

		-- Diagnostics
		if opts.components.diagnostics.enabled and width >= 100 then
			local diagnostics = components.diagnostics()
			if diagnostics ~= "" then
				table.insert(left, " ")
				table.insert(left, section(diagnostics, "SLSection"))
			end
		end

		-- Middle spacer
		local middle = { "%=" }

		-- Right side
		local right = {}

		-- Active indicators
		if width >= 100 then
			for _, fn in ipairs({
				components.maximized_status,
				components.macro_recording,
				components.search_count,
			}) do
				local val = fn()
				if val ~= "" then
					table.insert(right, val)
				end
			end
		end

		-- LSP status with bubble
		if opts.components.lsp.enabled and width >= 120 then
			local lsp_status = components.lsp_status()
			if lsp_status ~= "" then
				table.insert(right, section(lsp_status, "SLLspActive"))
				table.insert(right, " ")
			end
		end

		-- File encoding/format
		if width >= 120 then
			local enc = components.file_encoding()
			local fmt = components.file_format()
			if enc ~= "" or fmt ~= "" then
				table.insert(right, section_sep())
				table.insert(right, section((enc .. fmt), "SLSection"))
			end
		end

		-- Filetype
		if width >= 100 then
			local filetype = components.filetype()
			if filetype ~= "" then
				table.insert(right, section_sep())
				table.insert(right, section(filetype, "SLFiletype"))
			end
		end

		-- Position with background bubble
		table.insert(right, section_sep())
		if opts.components.position.style == "enhanced" then
			table.insert(right, section(components.position_enhanced(), "SLPosition"))
		else
			table.insert(right, section(components.position() .. components.total_lines(), "SLPosition"))
		end

		-- Progress bar
		if opts.components.progress.enabled and width >= 100 then
			table.insert(right, " ")
			table.insert(right, section(components.progress_bar(), "SLSection"))
		end

		return table.concat(left) .. table.concat(middle) .. table.concat(right)
	end

	-- Set the statusline
	vim.o.statusline = "%!luaeval(\"require('statusline').Status_line()\")"

	-- Smart redraw with debouncing
	vim.api.nvim_create_augroup("StatuslineEvents", { clear = true })

	vim.api.nvim_create_autocmd({ "ModeChanged" }, {
		group = "StatuslineEvents",
		callback = function()
			debounced_redraw(16) -- Fast refresh for mode changes
		end,
	})

	vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufWritePost" }, {
		group = "StatuslineEvents",
		callback = function()
			debounced_redraw(opts.refresh_rate)
		end,
	})

	vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
		group = "StatuslineEvents",
		callback = function()
			vim.cmd("redrawstatus")
		end,
	})

	-- Git status updates
	vim.api.nvim_create_autocmd("User", {
		pattern = "GitSignsUpdate",
		group = "StatuslineEvents",
		callback = function()
			if vim.b.status_cache then
				vim.b.status_cache.git = nil
			end
			debounced_redraw(opts.refresh_rate)
		end,
	})

	M.Status_line = Status_line
end

return M
