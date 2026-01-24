---@module "custom.statusline.theme.shadow_eminence"
--- Shadow Eminence Theme - Inspired by "The Eminence in Shadow"
--- A dark, elegant, high-contrast theme with refined purple and blue accents

local M = {}

--- Shadow Eminence Color Palette
--- Designed for maximum contrast and visual hierarchy
M.colors = {
	-- Core background/foreground
	bg_base = "#0d0d14", -- Deep void black
	bg_float = "#14141f", -- Slightly elevated surfaces
	bg_statusline = "#11111a", -- Statusline background
	fg_main = "#c7c7e0", -- Primary text (soft lavender-white)
	fg_dim = "#6e6e8f", -- Secondary text (muted gray-purple)
	fg_accent = "#9d9dcc", -- Tertiary text

	-- Elite accent colors (The "Shadow" aesthetic)
	shadow_purple = "#6c3082", -- Deep royal purple (eminence)
	shadow_violet = "#8b4f9f", -- Lighter purple accent
	elite_silver = "#b8b8d9", -- Metallic silver-blue
	void_blue = "#4a5a7a", -- Deep blue-gray
	midnight_blue = "#2d3d5f", -- Darker blue

	-- Semantic colors (refined and subdued)
	error = "#c74d5f", -- Muted crimson
	warn = "#d4a574", -- Subdued amber
	info = "#7aa5d9", -- Soft blue
	hint = "#88b3a8", -- Muted teal
	success = "#7fa86f", -- Subdued green

	-- Git colors (elegant earth tones)
	git_add = "#7fa86f",
	git_change = "#d4a574",
	git_delete = "#c74d5f",

	-- Mode colors (high contrast but elegant)
	mode_normal = "#6c7fb8", -- Calm blue
	mode_insert = "#7fa86f", -- Vital green
	mode_visual = "#8b4f9f", -- Royal purple
	mode_replace = "#c74d5f", -- Warning crimson
	mode_command = "#d4a574", -- Commanding amber
	mode_terminal = "#7aa5d9", -- Tech cyan-blue
	mode_select = "#d47f6f", -- Highlight orange

	-- Separator tones
	separator_subtle = "#2a2a3a",
	separator_prominent = "#3f3f5f",

	-- Special highlights
	modified = "#d47f6f",
	readonly = "#88b3a8",
	border = "#3f3f5f",
}

--- Visual Design Philosophy:
--- 1. High contrast between functional zones
--- 2. Subtle gradients through separator usage
--- 3. Refined spacing with purposeful density
--- 4. Elite feel through metallic accents
--- 5. Shadow motif: dark with strategic highlights

--- Create refined highlight groups
function M.setup_highlights()
	local c = M.colors
	local hl = vim.api.nvim_set_hl

	-- Base statusline
	hl(0, "StatusLine", { bg = c.bg_statusline, fg = c.fg_main })
	hl(0, "StatusLineNC", { bg = c.bg_base, fg = c.fg_dim })

	-- Mode highlights with refined borders
	local modes = {
		{ name = "Normal", color = c.mode_normal },
		{ name = "Insert", color = c.mode_insert },
		{ name = "Visual", color = c.mode_visual },
		{ name = "Replace", color = c.mode_replace },
		{ name = "Command", color = c.mode_command },
		{ name = "Terminal", color = c.mode_terminal },
		{ name = "Select", color = c.mode_select },
	}

	for _, mode in ipairs(modes) do
		-- Main mode block (filled)
		hl(0, "Status" .. mode.name, {
			bg = mode.color,
			fg = c.bg_base,
			bold = true,
		})

		-- Mode separator (creates elegant transition)
		hl(0, "Status" .. mode.name .. "Sep", {
			fg = mode.color,
			bg = c.bg_statusline,
		})

		-- Mode border accent (subtle depth)
		hl(0, "Status" .. mode.name .. "Border", {
			fg = c.elite_silver,
			bg = mode.color,
		})
	end

	-- Component highlights
	hl(0, "SLFileInfo", { fg = c.fg_main, bg = c.bg_statusline, bold = true })
	hl(0, "SLFileInfoDim", { fg = c.fg_dim, bg = c.bg_statusline })
	hl(0, "SLModified", { fg = c.modified, bg = c.bg_statusline, bold = true })
	hl(0, "SLReadonly", { fg = c.readonly, bg = c.bg_statusline, italic = true })

	-- Git highlights (earthy sophistication)
	hl(0, "SLGitBranch", { fg = c.shadow_violet, bg = c.bg_statusline, bold = true })
	hl(0, "SLGitAdded", { fg = c.git_add, bg = c.bg_statusline })
	hl(0, "SLGitChanged", { fg = c.git_change, bg = c.bg_statusline })
	hl(0, "SLGitRemoved", { fg = c.git_delete, bg = c.bg_statusline })

	-- Diagnostic highlights (refined danger levels)
	hl(0, "SLDiagError", { fg = c.error, bg = c.bg_statusline, bold = true })
	hl(0, "SLDiagWarn", { fg = c.warn, bg = c.bg_statusline })
	hl(0, "SLDiagInfo", { fg = c.info, bg = c.bg_statusline })
	hl(0, "SLDiagHint", { fg = c.hint, bg = c.bg_statusline })

	-- LSP highlights (mystical purple accent)
	hl(0, "SLLspProgress", { fg = c.shadow_purple, bg = c.bg_statusline, bold = true })
	hl(0, "SLLspActive", { fg = c.shadow_violet, bg = c.bg_statusline })

	-- Metadata highlights
	hl(0, "SLFiletype", { fg = c.elite_silver, bg = c.bg_statusline })
	hl(0, "SLEncoding", { fg = c.void_blue, bg = c.bg_statusline })
	hl(0, "SLFormat", { fg = c.void_blue, bg = c.bg_statusline })

	-- Position and progress (silver elegance)
	hl(0, "SLPosition", { fg = c.fg_accent, bg = c.bg_statusline, bold = true })
	hl(0, "SLProgress", { fg = c.elite_silver, bg = c.bg_statusline })
	hl(0, "SLProgressFill", { fg = c.shadow_purple, bg = c.bg_statusline })
	hl(0, "SLProgressEmpty", { fg = c.separator_subtle, bg = c.bg_statusline })

	-- Separators (layered depth)
	hl(0, "SLSeparatorSubtle", { fg = c.separator_subtle, bg = c.bg_statusline })
	hl(0, "SLSeparatorProminent", { fg = c.separator_prominent, bg = c.bg_statusline })
	hl(0, "SLSeparatorAccent", { fg = c.shadow_purple, bg = c.bg_statusline })

	-- Special states
	hl(0, "SLMatches", { fg = c.bg_base, bg = c.shadow_violet, bold = true })
	hl(0, "SLRecording", { fg = c.bg_base, bg = c.error, bold = true })
	hl(0, "SLNotModifiable", { fg = c.readonly, bg = c.bg_statusline, italic = true })

	-- Dev server status
	hl(0, "SLDevServerActive", { fg = c.bg_base, bg = c.success, bold = true })
	hl(0, "SLDevServerInactive", { fg = c.fg_dim, bg = c.midnight_blue })
end

--- Refined separator system
--- Uses three levels of visual weight for hierarchy
M.separators = {
	-- Powerline-style (elegant transitions)
	powerline_right = "",
	powerline_left = "",
	powerline_right_thin = "",
	powerline_left_thin = "",

	-- Vertical bars (clean divisions)
	bar_thick = "▌",
	bar_medium = "│",
	bar_thin = "┊",

	-- Dots (subtle separations)
	dot_large = "●",
	dot_medium = "•",
	dot_small = "·",

	-- Brackets (elegant framing)
	bracket_left = "❮",
	bracket_right = "❯",
	angle_left = "‹",
	angle_right = "›",

	-- Spacing
	space_1 = " ",
	space_2 = "  ",
}

--- Icon set (Nerd Font v3 compatible)
M.icons = {
	-- File states
	modified = "●",
	readonly = "",
	lock = "",

	-- Git
	branch = "",
	git_add = "",
	git_change = "",
	git_delete = "",

	-- Diagnostics
	error = "",
	warn = "",
	info = "",
	hint = "󰌵",

	-- LSP
	lsp_active = "",
	lsp_inactive = "",
	spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },

	-- Modes (refined symbols)
	mode_normal = "󰋜",
	mode_insert = "󰏫",
	mode_visual = "󰈈",
	mode_replace = "󰛔",
	mode_command = "󰘳",
	mode_terminal = "󰆍",
	mode_select = "󰒅",

	-- File info
	file_default = "◆",
	folder = "",

	-- Progress
	progress_full = "▰",
	progress_empty = "▱",

	-- Misc
	lightning = "󰓅",
	circle = "○",
	circle_filled = "●",
}

--- Layout configuration
--- Defines spacing and visual density
M.layout = {
	-- Mode section spacing
	mode_padding = { left = 1, right = 1 },
	mode_icon_spacing = 1,

	-- Component spacing
	component_padding = 1,
	section_spacing = 2,

	-- Separator preferences
	primary_separator = "bar_medium", -- Main visual divider
	secondary_separator = "dot_medium", -- Subtle grouping
	accent_separator = "dot_large", -- Important boundaries

	-- Width breakpoints for responsive design
	width_minimal = 80,
	width_compact = 100,
	width_comfortable = 120,
	width_full = 140,
}

--- Helper to get separator with proper highlight
function M.get_separator(type, highlight)
	highlight = highlight or "SLSeparatorSubtle"
	local sep = M.separators[type] or M.separators.bar_medium
	return "%#" .. highlight .. "#" .. sep .. "%*"
end

--- Mode configuration with Shadow Eminence theme
M.modes = {
	-- Normal modes
	n = { name = "NORMAL", hl = "StatusNormal", icon = M.icons.mode_normal },
	no = { name = "N·OP", hl = "StatusNormal", icon = M.icons.mode_normal },
	nov = { name = "N·OP", hl = "StatusNormal", icon = M.icons.mode_normal },
	noV = { name = "N·OP", hl = "StatusNormal", icon = M.icons.mode_normal },
	["no\22"] = { name = "N·OP", hl = "StatusNormal", icon = M.icons.mode_normal },

	-- Visual modes
	v = { name = "VISUAL", hl = "StatusVisual", icon = M.icons.mode_visual },
	V = { name = "V·LINE", hl = "StatusVisual", icon = M.icons.mode_visual },
	["\22"] = { name = "V·BLOCK", hl = "StatusVisual", icon = M.icons.mode_visual },

	-- Select modes
	s = { name = "SELECT", hl = "StatusSelect", icon = M.icons.mode_select },
	S = { name = "S·LINE", hl = "StatusSelect", icon = M.icons.mode_select },
	["\19"] = { name = "S·BLOCK", hl = "StatusSelect", icon = M.icons.mode_select },

	-- Insert modes
	i = { name = "INSERT", hl = "StatusInsert", icon = M.icons.mode_insert },
	ic = { name = "I·COMP", hl = "StatusInsert", icon = M.icons.mode_insert },
	ix = { name = "I·COMP", hl = "StatusInsert", icon = M.icons.mode_insert },

	-- Replace modes
	R = { name = "REPLACE", hl = "StatusReplace", icon = M.icons.mode_replace },
	Rc = { name = "R·COMP", hl = "StatusReplace", icon = M.icons.mode_replace },
	Rv = { name = "V·REPLACE", hl = "StatusReplace", icon = M.icons.mode_replace },
	Rx = { name = "R·COMP", hl = "StatusReplace", icon = M.icons.mode_replace },

	-- Command modes
	c = { name = "COMMAND", hl = "StatusCommand", icon = M.icons.mode_command },
	cv = { name = "EX", hl = "StatusCommand", icon = M.icons.mode_command },
	ce = { name = "EX", hl = "StatusCommand", icon = M.icons.mode_command },

	-- Terminal mode
	t = { name = "TERMINAL", hl = "StatusTerminal", icon = M.icons.mode_terminal },

	-- Misc
	r = { name = "PROMPT", hl = "StatusCommand", icon = "?" },
	rm = { name = "MORE", hl = "StatusCommand", icon = "?" },
	["r?"] = { name = "CONFIRM", hl = "StatusCommand", icon = "?" },
	["!"] = { name = "SHELL", hl = "StatusTerminal", icon = "" },
}

--- Apply theme to your statusline
function M.apply()
	M.setup_highlights()
	return {
		colors = M.colors,
		separators = M.separators,
		icons = M.icons,
		modes = M.modes,
		layout = M.layout,
		get_separator = M.get_separator,
	}
end

return M
