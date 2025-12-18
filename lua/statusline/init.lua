---@module "custom.statusline"
local M = {}

local components = require("statusline.component")

--- Default config
local defaults = {
	bg_hex = "#1a1b26",
	bg_highlight = "#24283b",
	fg_main = "#c0caf5",
	fg_dim = "#565f89",

	-- New configuration options
	icon_set = "nerd_v3", -- "nerd_v3", "nerd_v2", "ascii"
	separator_style = "powerline", -- "powerline", "vertical", "angle_right", "dot"

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

	-- Color palette with error handling
	local ok, statusline_hl = pcall(vim.api.nvim_get_hl, 0, { name = "StatusLine" })
	local bg_hex
	if ok and statusline_hl and statusline_hl.bg and statusline_hl.bg ~= 0 then
		bg_hex = string.format("#%06x", statusline_hl.bg)
	else
		bg_hex = opts.bg_hex or "#1a1b26"
	end
	local bg_highlight = opts.bg_highlight or "#24283b"
	local fg_main = opts.fg_main or "#c0caf5"
	local fg_dim = opts.fg_dim or "#565f89"

	-- Store colors for components
	M.colors = {
		bg_hex = bg_hex,
		bg_highlight = bg_highlight,
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
		SLGitBranch = { fg = "#bb9af7", bg = bg_highlight },
		SLGitAdded = { fg = "#9ece6a", bg = bg_highlight },
		SLGitChanged = { fg = "#e0af68", bg = bg_highlight },
		SLGitRemoved = { fg = "#f7768e", bg = bg_highlight },
		SLEncoding = { fg = "#7aa2f7", bg = bg_hex },
		SLFormat = { fg = "#7aa2f7", bg = bg_hex },
		SLRightSection = { fg = fg_main, bg = bg_highlight },
	}

	for name, hl_opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, hl_opts)
	end

	-- Mode colors (dark theme defaults)
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
		vim.api.nvim_set_hl(0, "Status" .. name, { bg = color, fg = "#1a1b26", bold = true })
		vim.api.nvim_set_hl(0, "Status" .. name .. "Sep", { fg = color, bg = bg_hex })
	end

	for name, color in pairs(mode_colors) do
		create_mode_hl(name, color)
	end

	-- Mode configuration with modern icons
	local mode_config = {
		n = { name = "NORMAL", hl = "StatusNormal", icon = "󰋜" },
		v = { name = "VISUAL", hl = "StatusVisual", icon = "󰈈" },
		V = { name = "V·LINE", hl = "StatusVisual", icon = "󰈈" },
		["\22"] = { name = "V·BLOCK", hl = "StatusVisual", icon = "󰈈" },
		i = { name = "INSERT", hl = "StatusInsert", icon = "󰏫" },
		R = { name = "REPLACE", hl = "StatusReplace", icon = "󰛔" },
		c = { name = "COMMAND", hl = "StatusCommand", icon = "󰘳" },
		t = { name = "TERMINAL", hl = "StatusTerminal", icon = "󰆍" },
		-- Add other modes as needed...
	}

	local function get_mode_info()
		local ok, mode_data = pcall(vim.api.nvim_get_mode)
		if not ok then
			return mode_config.n
		end
		return mode_config[mode_data.mode] or mode_config.n
	end

	local function mode_indicator()
		local info = get_mode_info()
		return table.concat({
			"%#" .. info.hl .. "#",
			" ",
			info.icon,
			" ",
			info.name,
			" ",
			"%*",
		})
	end

	-- Main statusline builder
	local function Status_line()
		local width = vim.api.nvim_win_get_width(0)
		local ft = vim.bo.filetype

		local special_fts = {
			"neo-tree",
			"minifiles",
			"oil",
			"TelescopePrompt",
			"alpha",
			"dashboard",
			"lazy",
		}
		if vim.tbl_contains(special_fts, ft) then
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

		if width < 80 then
			return mode_indicator() .. "%=" .. components.position() .. components.padding(1)
		end

		local left = { mode_indicator() }
		local middle = { "%=" }
		local right = {}

		-- Mode → Git section transition
		local mode_info = get_mode_info()
		local mode_color = mode_colors[mode_info.name:match("^(%u+)")]

		if opts.separator_style == "powerline" then
			table.insert(left, components.transition(mode_color, M.colors.bg_highlight, "right"))
		else
			table.insert(left, components.separator(opts.separator_style) .. " ")
		end

		-- Git info
		if opts.components.git.enabled then
			local git_branch = components.git_branch()
			local git_status = components.git_status()
			if git_branch ~= "" or git_status ~= "" then
				table.insert(left, "%#SLGitBranch#" .. git_branch .. git_status .. "%*")
				if opts.separator_style == "powerline" then
					table.insert(left, components.transition(M.colors.bg_highlight, bg_hex, "right"))
				else
					table.insert(left, components.separator(opts.separator_style) .. " ")
				end
			end
		end

		-- File info
		if opts.components.file_info.enabled then
			table.insert(
				left,
				"%#SLFileInfo#"
					.. components.fileinfo({ add_icon = true, show_size = opts.components.file_info.show_size })
					.. "%*"
			)
		end

		-- Diagnostics
		if opts.components.diagnostics.enabled and width >= 100 then
			local diag = components.diagnostics()
			if diag ~= "" then
				table.insert(left, diag)
			end
		end

		-- Right side indicators
		if width >= 100 then
			for _, fn in ipairs({ components.maximized_status, components.macro_recording, components.search_count }) do
				local val = fn()
				if val ~= "" then
					table.insert(right, val)
				end
			end
		end

		-- Encoding / format
		if width >= 120 then
			local enc = components.file_encoding()
			local fmt = components.file_format()
			if enc ~= "" or fmt ~= "" then
				table.insert(right, "%#SLEncoding#" .. enc .. fmt .. "%*")
			end
		end

		-- Filetype & position
		local filetype = components.filetype()
		if filetype ~= "" and width >= 100 then
			if opts.separator_style == "powerline" then
				table.insert(right, components.transition(bg_hex, M.colors.bg_highlight, "left"))
			end
			table.insert(right, "%#SLRightSection#" .. filetype .. components.padding(1) .. "%*")
		end

		if opts.separator_style == "powerline" then
			table.insert(right, components.transition(bg_hex, M.colors.bg_highlight, "left"))
		end
		table.insert(
			right,
			"%#SLRightSection#" .. components.position() .. components.total_lines() .. components.padding(1) .. "%*"
		)

		-- Progress bar
		if opts.components.progress.enabled and width >= 100 then
			table.insert(right, components.progress_bar() .. components.padding(1))
		end

		return table.concat(left) .. table.concat(middle) .. table.concat(right)
	end

	vim.o.statusline = "%!luaeval(\"require('statusline').Status_line()\")"

	-- Autocommands for updates
	local aug = vim.api.nvim_create_augroup("StatuslineEvents", { clear = true })

	vim.api.nvim_create_autocmd({ "ModeChanged" }, {
		group = aug,
		callback = function()
			debounced_redraw(16)
		end,
	})

	vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufWritePost" }, {
		group = aug,
		callback = function()
			debounced_redraw(opts.refresh_rate)
		end,
	})

	vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
		group = aug,
		callback = function()
			vim.cmd("redrawstatus")
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "GitSignsUpdate",
		group = aug,
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
