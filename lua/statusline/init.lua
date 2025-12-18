local M = {}
local comp = require("statusline.component")

-- Modern Tokyo Night / Catppuccin inspired palette
local palette = {
	bg = "#16161e", -- Statusline background (the "gap")
	surface = "#2f334d", -- Pill background
	blue = "#7aa2f7", -- Normal Mode
	green = "#9ece6a", -- Insert Mode
	magenta = "#bb9af7", -- Visual Mode
	red = "#f7768e", -- Replace Mode
	fg = "#c0caf5", -- Text
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", { icon_set = "nerd_v3" }, opts or {})

	-- 1. Define Highlight Groups
	local hls = {
		StatusLine = { bg = palette.bg, fg = palette.fg },
		SLNormal = { bg = palette.blue, fg = palette.bg, bold = true },
		SLInsert = { bg = palette.green, fg = palette.bg, bold = true },
		SLVisual = { bg = palette.magenta, fg = palette.bg, bold = true },
		SLReplace = { bg = palette.red, fg = palette.bg, bold = true },
		SLSurface = { bg = palette.surface, fg = palette.fg },
		SLGit = { bg = palette.surface, fg = palette.magenta, bold = true },
	}

	for name, hl in pairs(hls) do
		vim.api.nvim_set_hl(0, name, hl)
	end

	-- 2. Create the Separator Highlights (blending pills into the BG)
	local function make_sep(name)
		local pill_hl = vim.api.nvim_get_hl(0, { name = name })
		vim.api.nvim_set_hl(0, "SLSep" .. name, { fg = pill_hl.bg, bg = palette.bg })
	end
	for _, n in ipairs({ "SLNormal", "SLInsert", "SLVisual", "SLReplace", "SLSurface", "SLGit" }) do
		make_sep(n)
	end

	-- 3. The Main Render Function
	M.render = function()
		local mode_map = {
			n = "SLNormal",
			i = "SLInsert",
			v = "SLVisual",
			V = "SLVisual",
			[""] = "SLVisual",
			R = "SLReplace",
		}
		local mode_hl = mode_map[vim.api.nvim_get_mode().mode] or "SLNormal"
		local width = vim.api.nvim_win_get_width(0)

		-- Left side components
		local left = table.concat({
			comp.pill("  " .. vim.api.nvim_get_mode().mode:upper() .. " ", mode_hl),
			comp.pill(comp.file_info(), "SLSurface"),
			comp.pill(comp.git_status(), "SLGit"),
		})

		-- Right side components (responsive)
		local right_parts = {}
		if width > 80 then
			table.insert(right_parts, comp.pill(comp.diagnostics(), "SLSurface"))
		end
		table.insert(right_parts, comp.pill(" %l:%c ", mode_hl))

		return left .. "%=" .. table.concat(right_parts)
	end

	vim.o.statusline = "%!luaeval('require(\"statusline\").render()')"
end

return M
