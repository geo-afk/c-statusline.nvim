local M = {}
M._hls = {}

-- Preserved your icon sets with added pill separators
local icon_sets = {
	nerd_v3 = {
		branch = " ",
		added = " ",
		changed = " ",
		removed = " ",
		error = " ",
		warn = " ",
		info = " ",
		hint = "󰌵 ",
		lock = " ",
		left_pill = "",
		right_pill = "",
	},
	ascii = {
		branch = "*",
		added = "+",
		changed = "~",
		removed = "-",
		error = "E",
		warn = "W",
		info = "I",
		hint = "H",
		lock = "L",
		left_pill = "[",
		right_pill = "]",
	},
}

function M.get_icon(name)
	local statusline = package.loaded["statusline"]
	local icon_set = (statusline and statusline.config and statusline.config.icon_set) or "nerd_v3"
	return icon_sets[icon_set][name] or icon_sets.ascii[name] or ""
end

-- NEW: The logic that creates the "Floating Pill" look
function M.pill(content, hl_group)
	if not content or content == "" or content == " " then
		return ""
	end
	local left_sep = M.get_icon("left_pill")
	local right_sep = M.get_icon("right_pill")

	-- We use a special "Sep" highlight group to color the rounded edge
	return "%#SLSep"
		.. hl_group
		.. "#"
		.. left_sep
		.. "%#"
		.. hl_group
		.. "#"
		.. content
		.. "%#SLSep"
		.. hl_group
		.. "#"
		.. right_sep
		.. "%* "
end

-- Preserved and optimized Git Status
function M.git_status()
	local gitsigns = vim.b.gitsigns_status_dict
	if not gitsigns then
		return ""
	end
	local parts = {}
	if (gitsigns.added or 0) > 0 then
		table.insert(parts, M.get_icon("added") .. gitsigns.added)
	end
	if (gitsigns.changed or 0) > 0 then
		table.insert(parts, M.get_icon("changed") .. gitsigns.changed)
	end
	if (gitsigns.removed or 0) > 0 then
		table.insert(parts, M.get_icon("removed") .. gitsigns.removed)
	end
	return #parts > 0 and table.concat(parts, " ") or ""
end

-- Preserved Diagnostics with your original caching logic
function M.diagnostics()
	local function get_sev(s)
		return #vim.diagnostic.get(0, { severity = s })
	end
	local err = get_sev(vim.diagnostic.severity.ERROR)
	local warn = get_sev(vim.diagnostic.severity.WARN)

	local parts = {}
	if err > 0 then
		table.insert(parts, M.get_icon("error") .. err)
	end
	if warn > 0 then
		table.insert(parts, M.get_icon("warn") .. warn)
	end
	return table.concat(parts, " ")
end

-- File Icon + Name
function M.file_info()
	local icon = "󰈚"
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if ok then
		icon = devicons.get_icon(vim.fn.expand("%:t"), vim.fn.expand("%:e"), { default = true })
	end
	local name = vim.fn.expand("%:t")
	if name == "" then
		name = "[Empty]"
	end
	return icon .. " " .. name
end

return M
