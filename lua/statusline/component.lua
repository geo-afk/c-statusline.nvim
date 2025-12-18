---@module "statusline.components"
local M = {}

-- Icon sets
local icon_sets = {
	nerd_v3 = {
		branch = " ",
		added = " ",
		changed = " ",
		removed = " ",
		error = " ",
		warn = " ",
		info = " ",
		hint = "󰌵 ",
		lock = "󰍁 ",
		separator = "│",
	},
	nerd_v2 = {
		branch = " ",
		added = " ",
		changed = " ",
		removed = " ",
		error = " ",
		warn = " ",
		info = " ",
		hint = " ",
		lock = " ",
		separator = "│",
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
		separator = "|",
	},
}

-- Get icon based on configured set
function M.get_icon(name)
	local statusline = package.loaded["statusline"]
	local icon_set = (statusline and statusline.config and statusline.config.icon_set) or "nerd_v3"
	return icon_sets[icon_set][name] or icon_sets.ascii[name] or "?"
end

-- Simple padding
function M.padding(nr)
	return string.rep(" ", nr or 1)
end

-- File icon with devicons support
function M.file_icon()
	local ok, devicons = pcall(require, "nvim-web-devicons")
	local icon, hl

	if ok then
		local filename = vim.fn.expand("%:t")
		local ext = vim.fn.expand("%:e")
		if filename and filename ~= "" then
			icon, hl = devicons.get_icon(filename, ext)
		end
	end

	if not icon then
		icon = "◆"
		hl = "SLFileIcon"
	end

	if not vim.bo.modifiable then
		icon = M.get_icon("lock")
		hl = "SLReadonly"
	end

	return "%#" .. hl .. "#" .. icon .. "%*"
end

-- File info with modern styling
local file_cache = {}
function M.fileinfo(opts)
	opts = opts or { add_icon = true, show_size = false }

	local buf = vim.api.nvim_get_current_buf()
	local now = vim.loop.now()

	if not file_cache[buf] or (now - (file_cache[buf].timestamp or 0)) > 1000 then
		local path = vim.fn.expand("%:t")
		local size = vim.fn.getfsize(vim.fn.expand("%"))
		file_cache[buf] = { path = path, size = size, timestamp = now }
	end

	local cached = file_cache[buf]
	local name = (cached.path == "" and "Empty") or cached.path

	local parts = {}

	-- Add icon
	if opts.add_icon then
		table.insert(parts, M.file_icon())
		table.insert(parts, " ")
	end

	-- Add filename
	table.insert(parts, "%#SLFileName#" .. name .. "%*")

	-- Modified indicator
	if vim.bo.modified then
		table.insert(parts, " %#SLModified#●%*")
	end

	-- Readonly indicator
	if not vim.bo.modifiable or vim.bo.readonly then
		table.insert(parts, " %#SLReadonly#%*")
	end

	-- Size indicator (if enabled)
	if opts.show_size and cached.size > 0 then
		local size_str
		if cached.size > 1024 * 1024 then
			size_str = string.format("%.1fM", cached.size / (1024 * 1024))
		elseif cached.size > 1024 then
			size_str = string.format("%.1fK", cached.size / 1024)
		else
			size_str = string.format("%dB", cached.size)
		end
		table.insert(parts, " %#SLFileSection#[" .. size_str .. "]%*")
	end

	return table.concat(parts)
end

-- Git branch with icon
function M.git_branch()
	local ok, branch = pcall(function()
		return vim.b.gitsigns_head
	end)

	if not ok or not branch or branch == "" then
		return ""
	end

	local icon = M.get_icon("branch")
	return "%#SLGitBranch#" .. icon .. branch .. "%* "
end

-- Git status with modern indicators
function M.git_status()
	if not vim.b.status_cache then
		vim.b.status_cache = {}
	end

	local cache = vim.b.status_cache.git
	local now = vim.loop.now()
	local lines = vim.api.nvim_buf_line_count(0)
	local stale = (lines > 10000) and 30000 or 10000

	if not cache or (now - (cache.timestamp or 0)) > stale then
		local ok, gitsigns = pcall(function()
			return vim.b.gitsigns_status_dict
		end)

		if not ok or not gitsigns then
			cache = { str = "", timestamp = now }
		else
			local parts = {}

			if gitsigns.added and gitsigns.added > 0 then
				table.insert(parts, "%#SLGitAdded#" .. M.get_icon("added") .. gitsigns.added .. "%*")
			end

			if gitsigns.changed and gitsigns.changed > 0 then
				table.insert(parts, "%#SLGitChanged#" .. M.get_icon("changed") .. gitsigns.changed .. "%*")
			end

			if gitsigns.removed and gitsigns.removed > 0 then
				table.insert(parts, "%#SLGitRemoved#" .. M.get_icon("removed") .. gitsigns.removed .. "%*")
			end

			local str = #parts == 0 and "" or (table.concat(parts, " ") .. " ")
			cache = { str = str, timestamp = now }
		end

		vim.b.status_cache.git = cache
	end

	return cache.str or ""
end

-- Diagnostics with colored icons
function M.diagnostics()
	if not vim.b.status_cache then
		vim.b.status_cache = {}
	end

	local cache = vim.b.status_cache.diagnostics
	local now = vim.loop.now()
	local lines = vim.api.nvim_buf_line_count(0)
	local stale = (lines > 10000) and 30000 or 10000

	if not cache or (now - (cache.timestamp or 0)) > stale then
		local ok, result = pcall(function()
			local function get_sev(s)
				return #vim.diagnostic.get(0, { severity = s })
			end

			return {
				errors = get_sev(vim.diagnostic.severity.ERROR),
				warnings = get_sev(vim.diagnostic.severity.WARN),
				info = get_sev(vim.diagnostic.severity.INFO),
				hints = get_sev(vim.diagnostic.severity.HINT),
			}
		end)

		if not ok then
			cache = { str = "", timestamp = now }
		else
			local res = result
			local total = res.errors + res.warnings + res.hints + res.info
			local parts = {}

			if res.errors > 0 then
				table.insert(parts, "%#SLDiagError#" .. M.get_icon("error") .. res.errors .. "%*")
			end

			if res.warnings > 0 then
				table.insert(parts, "%#SLDiagWarn#" .. M.get_icon("warn") .. res.warnings .. "%*")
			end

			if res.info > 0 then
				table.insert(parts, "%#SLDiagInfo#" .. M.get_icon("info") .. res.info .. "%*")
			end

			if res.hints > 0 then
				table.insert(parts, "%#SLDiagHint#" .. M.get_icon("hint") .. res.hints .. "%*")
			end

			local str = vim.bo.modifiable and total > 0 and table.concat(parts, " ") or ""
			cache = { str = str, timestamp = now }
		end

		vim.b.status_cache.diagnostics = cache
	end

	return cache.str or ""
end

-- Position indicator
function M.position()
	return "%#SLPosition#%3l:%-2c%*"
end

-- Progress indicator (percentage and visual bar)
function M.progress()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_line_count(0)
	local percentage = math.floor((line / lines) * 100)

	-- Special cases
	if line == 1 then
		return "%#SLProgress#Top%*"
	elseif line == lines then
		return "%#SLProgress#Bot%*"
	else
		return "%#SLProgress#" .. percentage .. "%%%*"
	end
end

-- Filetype with icon
function M.filetype()
	local ft = vim.bo.filetype
	if ft == "" then
		return ""
	end

	local ok, devicons = pcall(require, "nvim-web-devicons")
	local icon = ""

	if ok then
		local icon_data, _ = devicons.get_icon_by_filetype(ft)
		if icon_data then
			icon = icon_data .. " "
		end
	end

	return "%#SLFiletype#" .. icon .. ft:upper() .. "%*"
end

-- Macro recording indicator
function M.macro_recording()
	local ok, reg = pcall(vim.fn.reg_recording)
	if not ok or reg == "" then
		return ""
	end
	return "%#SLIndicator# REC @" .. reg .. " %*"
end

-- Search count with modern styling
function M.search_count()
	if vim.v.hlsearch == 0 then
		return ""
	end

	local ok, result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
	if not ok or result.current == nil or result.total == 0 then
		return ""
	end

	return "%#SLSearch# " .. result.current .. "/" .. result.total .. " %*"
end

-- Cache management
local function invalidate_caches()
	vim.b.status_cache = nil
	file_cache[vim.api.nvim_get_current_buf()] = nil
end

-- Setup cache management
local augroup = vim.api.nvim_create_augroup("StatuslineCache", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "BufWritePost" }, {
	callback = invalidate_caches,
	group = augroup,
})

vim.api.nvim_create_autocmd("BufDelete", {
	callback = function(args)
		file_cache[args.buf] = nil
	end,
	group = augroup,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function()
		if vim.b.status_cache then
			vim.b.status_cache.diagnostics = nil
		end
	end,
	group = augroup,
})

return M
