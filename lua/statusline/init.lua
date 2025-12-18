-- Modern, clean statusline with refined aesthetics and generous spacing
-- Inspired by 2025 UI design trends: subtle depth, soft backgrounds, clear hierarchy

---@module "custom.statusline"
local M = {}

local components = require("statusline.component")

--- Modern config with refined aesthetics
local defaults = {
	-- Refined color palette with subtle depth
	colors = {
		-- Mode colors (softer, more harmonious)
		mode_normal = "#7aa2f7", -- Soft blue
		mode_insert = "#9ece6a", -- Gentle green
		mode_visual = "#bb9af7", -- Muted purple
		mode_replace = "#f7768e", -- Soft red
		mode_command = "#e0af68", -- Warm amber
		mode_terminal = "#7dcfff", -- Calm cyan
		mode_select = "#ff9e64", -- Soft orange

		-- Background layers (subtle gradation for depth)
		bg_main = "#1a1b26", -- Deep base
		bg_elevated = "#24283b", -- Slightly elevated
		bg_panel = "#292e42", -- Panel surface
		bg_subtle = "#3b4261", -- Subtle highlights

		-- Foreground colors (refined contrast)
		fg_main = "#c0caf5", -- Primary text
		fg_dim = "#565f89", -- Dimmed text
		fg_bright = "#a9b1d6", -- Bright text
		fg_inverse = "#1a1b26", -- For colored backgrounds

		-- Component colors (harmonious palette)
		git_branch = "#bb9af7", -- Branch purple
		git_added = "#9ece6a", -- Added green
		git_changed = "#e0af68", -- Changed amber
		git_removed = "#f7768e", -- Removed red
		diagnostic_error = "#db4b4b", -- Error red
		diagnostic_warn = "#e0af68", -- Warning amber
		diagnostic_info = "#0db9d7", -- Info cyan
		diagnostic_hint = "#1abc9c", -- Hint teal
		lsp_active = "#7aa2f7", -- LSP blue
		folder = "#7aa2f7", -- Folder blue

		-- Accent colors
		accent_blue = "#7aa2f7",
		accent_purple = "#9d7cd8",
	},

	-- Modern styling with clean separators
	style = "modern",
	separator_style = "subtle",

	components = {
		mode = { enabled = true },
		git = { enabled = true },
		diagnostics = { enabled = true },
		file_info = { enabled = true, show_size = false },
		folder = { enabled = false },
		lsp = { enabled = true },
		position = { enabled = true, style = "simple" },
		progress = { enabled = true, style = "percentage" },
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

	-- Modern highlight groups with refined contrast
	local highlights = {
		-- Base statusline with subtle elevation
		SLBackground = { fg = colors.fg_main, bg = colors.bg_main },
		SLElevated = { fg = colors.fg_main, bg = colors.bg_elevated },
		SLPanel = { fg = colors.fg_main, bg = colors.bg_panel },
		SLSubtle = { fg = colors.fg_bright, bg = colors.bg_subtle },

		-- Text variants
		SLDim = { fg = colors.fg_dim, bg = colors.bg_elevated },
		SLBright = { fg = colors.fg_bright, bg = colors.bg_elevated },
		SLModified = { fg = colors.diagnostic_error, bg = colors.bg_elevated, bold = true },
		SLNotModifiable = { fg = colors.diagnostic_warn, bg = colors.bg_elevated },

		-- File info
		SLFileInfo = { fg = colors.fg_bright, bg = colors.bg_elevated },
		SLFiletype = { fg = colors.accent_purple, bg = colors.bg_elevated },
		SLFolder = { fg = colors.folder, bg = colors.bg_elevated },

		-- Position
		SLPosition = { fg = colors.fg_bright, bg = colors.bg_panel },
		SLPositionLabel = { fg = colors.fg_dim, bg = colors.bg_panel },

		-- Git
		SLGitBranch = { fg = colors.git_branch, bg = colors.bg_elevated },
		SLGitAdded = { fg = colors.git_added, bg = colors.bg_elevated },
		SLGitChanged = { fg = colors.git_changed, bg = colors.bg_elevated },
		SLGitRemoved = { fg = colors.git_removed, bg = colors.bg_elevated },

		-- LSP
		SLLspActive = { fg = colors.lsp_active, bg = colors.bg_elevated },

		-- Diagnostics
		SLDiagError = { fg = colors.diagnostic_error, bg = colors.bg_elevated },
		SLDiagWarn = { fg = colors.diagnostic_warn, bg = colors.bg_elevated },
		SLDiagInfo = { fg = colors.diagnostic_info, bg = colors.bg_elevated },
		SLDiagHint = { fg = colors.diagnostic_hint, bg = colors.bg_elevated },

		-- Separators
		SLSeparator = { fg = colors.fg_dim, bg = colors.bg_main },

		-- Special states
		SLMatches = { fg = colors.fg_inverse, bg = colors.accent_blue, bold = true },
		SLRecording = { fg = colors.diagnostic_error, bg = colors.bg_elevated, bold = true },

		-- Progress
		SLProgressFilled = { fg = colors.accent_blue, bg = colors.bg_elevated, bold = true },
		SLProgressEmpty = { fg = colors.bg_subtle, bg = colors.bg_elevated },
	}

	for name, hl_opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, hl_opts)
	end

	-- Mode highlights
	local function create_mode_hl(name, color)
		vim.api.nvim_set_hl(0, "Status" .. name, {
			bg = colors.bg_elevated,
			fg = color,
			bold = true,
		})
		vim.api.nvim_set_hl(0, "Status" .. name .. "Icon", {
			bg = colors.bg_elevated,
			fg = color,
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
		n = { name = "NORMAL", hl = "StatusNormal", icon = "N", desc = "Normal" },
		no = { name = "N-OP", hl = "StatusNormal", icon = "N", desc = "Operator Pending" },
		nov = { name = "N-OP-V", hl = "StatusNormal", icon = "N", desc = "Operator Pending Char" },
		noV = { name = "N-OP-L", hl = "StatusNormal", icon = "N", desc = "Operator Pending Line" },
		["no\22"] = { name = "N-OP-B", hl = "StatusNormal", icon = "N", desc = "Operator Pending Block" },

		v = { name = "VISUAL", hl = "StatusVisual", icon = "V", desc = "Visual" },
		V = { name = "V-LINE", hl = "StatusVisual", icon = "V", desc = "Visual Line" },
		["\22"] = { name = "V-BLOCK", hl = "StatusVisual", icon = "V", desc = "Visual Block" },

		s = { name = "SELECT", hl = "StatusSelect", icon = "S", desc = "Select" },
		S = { name = "S-LINE", hl = "StatusSelect", icon = "S", desc = "Select Line" },
		["\19"] = { name = "S-BLOCK", hl = "StatusSelect", icon = "S", desc = "Select Block" },

		i = { name = "INSERT", hl = "StatusInsert", icon = "I", desc = "Insert" },
		ic = { name = "I-COMP", hl = "StatusInsert", icon = "I", desc = "Insert Completion" },
		ix = { name = "I-COMP", hl = "StatusInsert", icon = "I", desc = "Insert Completion" },

		R = { name = "REPLACE", hl = "StatusReplace", icon = "R", desc = "Replace" },
		Rc = { name = "R-COMP", hl = "StatusReplace", icon = "R", desc = "Replace Completion" },
		Rv = { name = "V-REPLACE", hl = "StatusReplace", icon = "R", desc = "Virtual Replace" },
		Rx = { name = "R-COMP", hl = "StatusReplace", icon = "R", desc = "Replace Completion" },

		c = { name = "COMMAND", hl = "StatusCommand", icon = "C", desc = "Command" },
		cv = { name = "EX", hl = "StatusCommand", icon = "E", desc = "Ex" },
		ce = { name = "EX", hl = "StatusCommand", icon = "E", desc = "Ex" },

		t = { name = "TERMINAL", hl = "StatusTerminal", icon = "T", desc = "Terminal" },

		r = { name = "PROMPT", hl = "StatusCommand", icon = "?", desc = "Hit Enter Prompt" },
		rm = { name = "MORE", hl = "StatusCommand", icon = "?", desc = "More" },
		["r?"] = { name = "CONFIRM", hl = "StatusCommand", icon = "?", desc = "Confirm" },
		["!"] = { name = "SHELL", hl = "StatusTerminal", icon = "!", desc = "Shell" },
	}

	local function get_mode_info()
		local ok, mode_data = pcall(vim.api.nvim_get_mode)
		if not ok then
			return mode_config.n
		end
		return mode_config[mode_data.mode] or mode_config.n
	end

	-- Separator characters
	local sep_chars = {
		subtle = " · ",
		line = " | ",
		space = "  ",
	}

	-- Clean mode indicator
	local function mode_indicator()
		local info = get_mode_info()
		return table.concat({
			"%#" .. info.hl .. "Icon#",
			"  ",
			info.icon,
			" ",
			"%#" .. info.hl .. "#",
			info.name,
			"  ",
			"%*",
		})
	end

	-- Section wrapper
	local function section(content, hl_group)
		if content == "" then
			return ""
		end
		hl_group = hl_group or "SLElevated"
		return "%#" .. hl_group .. "#" .. " " .. content .. " " .. "%*"
	end

	-- Separator
	local function separator()
		local sep_style = opts.separator_style or "subtle"
		local sep = sep_chars[sep_style] or sep_chars.subtle
		return "%#SLSeparator#" .. sep .. "%*"
	end

	-- Main statusline
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
			return section("  " .. ft:sub(1, 1):upper() .. ft:sub(2) .. "  " .. dir, "SLSubtle")
		end

		-- Minimal for narrow windows
		if width < 80 then
			return table.concat({
				mode_indicator(),
				"%=",
				section(components.position(), "SLPosition"),
			})
		end

		-- Left side
		local left = { mode_indicator() }

		-- Git branch
		if opts.components.git.enabled then
			local git_branch = components.git_branch()
			if git_branch ~= "" then
				table.insert(left, separator())
				table.insert(left, section(git_branch, "SLGitBranch"))
			end
		end

		-- File info
		if opts.components.file_info.enabled then
			table.insert(left, separator())
			table.insert(
				left,
				section(
					components.fileinfo({ add_icon = true, show_size = opts.components.file_info.show_size }),
					"SLFileInfo"
				)
			)
		end

		-- Git stats
		if opts.components.git.enabled and width >= 100 then
			local git_status = components.git_status()
			if git_status ~= "" then
				table.insert(left, separator())
				table.insert(left, section(git_status, "SLElevated"))
			end
		end

		-- Diagnostics
		if opts.components.diagnostics.enabled and width >= 100 then
			local diagnostics = components.diagnostics()
			if diagnostics ~= "" then
				table.insert(left, separator())
				table.insert(left, section(diagnostics, "SLElevated"))
			end
		end

		-- Middle spacer
		local middle = { "%=" }

		-- Right side
		local right = {}

		-- Recording/search/maximized
		if width >= 100 then
			for _, fn in ipairs({
				components.macro_recording,
				components.search_count,
				components.maximized_status,
			}) do
				local val = fn()
				if val ~= "" then
					table.insert(right, section(val, "SLRecording"))
					table.insert(right, separator())
				end
			end
		end

		-- LSP
		if opts.components.lsp.enabled and width >= 120 then
			local lsp_status = components.lsp_status()
			if lsp_status ~= "" then
				table.insert(right, section(lsp_status, "SLLspActive"))
				table.insert(right, separator())
			end
		end

		-- Filetype
		if width >= 100 then
			local filetype = components.filetype()
			if filetype ~= "" then
				table.insert(right, section(filetype, "SLFiletype"))
				table.insert(right, separator())
			end
		end

		-- Position
		table.insert(right, section(components.position(), "SLPosition"))

		-- Progress
		if opts.components.progress.enabled and width >= 100 then
			table.insert(right, separator())
			if opts.components.progress.style == "percentage" then
				local lines = vim.api.nvim_buf_line_count(0)
				local cur_line = vim.api.nvim_win_get_cursor(0)[1]
				local percentage = math.floor((cur_line / lines) * 100)
				table.insert(right, section(percentage .. "%%", "SLProgressFilled"))
			else
				table.insert(right, section(components.progress_bar(), "SLElevated"))
			end
		end

		return table.concat(left) .. table.concat(middle) .. table.concat(right)
	end

	-- Set statusline
	vim.o.statusline = "%!luaeval(\"require('statusline').Status_line()\")"

	-- Event handlers
	vim.api.nvim_create_augroup("StatuslineEvents", { clear = true })

	vim.api.nvim_create_autocmd({ "ModeChanged" }, {
		group = "StatuslineEvents",
		callback = function()
			debounced_redraw(16)
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
