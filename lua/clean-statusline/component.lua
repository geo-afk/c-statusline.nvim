---@module "custom.statusline.components"
local utils = require("custom.statusline.utils")
local hl_str = utils.hl_str

local M = {}
M._hls = {}

-- Optimized highlight creation with caching
function M.get_or_create_hl(fg, bg, opts)
	opts = opts or {}
	bg = bg or "StatusLine"
	fg = fg or "#ffffff"

	local sanitized_fg = tostring(fg):gsub("#", "")
	local sanitized_bg = tostring(bg):gsub("#", "")
	local suffix = ""
	if opts.bold then
		suffix = suffix .. "B"
	end
	if opts.italic then
		suffix = suffix .. "I"
	end
	local name = "SL" .. sanitized_fg .. sanitized_bg .. suffix

	if not M._hls[name] then
		local bg_hl, fg_hl

		if tostring(bg):match("^#") then
			bg_hl = { bg = bg }
		else
			bg_hl = vim.api.nvim_get_hl(0, { name = bg })
		end

		if tostring(fg):match("^#") then
			fg_hl = { fg = fg }
		else
			fg_hl = vim.api.nvim_get_hl(0, { name = fg })
		end

		local bg_val = bg_hl and bg_hl.bg
		local fg_val = fg_hl and fg_hl.fg

		vim.api.nvim_set_hl(0, name, {
			fg = fg_val and (type(fg_val) == "string" and fg_val or ("#%06x"):format(fg_val)) or fg,
			bg = bg_val and (type(bg_val) == "string" and bg_val or ("#%06x"):format(bg_val)) or "none",
			bold = opts.bold,
			italic = opts.italic,
		})
		M._hls[name] = true
	end

	return "%#" .. name .. "#"
end

-- Simple padding
function M.padding(nr)
	return string.rep(" ", nr or 1)
end

-- Simple separator
function M.separator()
	return hl_str("SLSeparator", "│")
end

-- Enhanced file icon
function M.file_icon()
	local ok, devicons = pcall(require, "nvim-web-devicons")
	local icon, igroup

	if ok then
		icon, igroup = devicons.get_icon(vim.fn.expand("%:t"))
	end

	if not icon then
		icon = "◆"
		igroup = "DevIconDefault"
	end

	if not vim.bo.modifiable then
		icon = "🔒"
		igroup = "SLNotModifiable"
	end

	return hl_str(igroup, icon)
end

-- File info with size cache (unchanged)
local file_cache = {}
function M.fileinfo(opts)
	opts = opts or { add_icon = true }

	local buf = vim.api.nvim_get_current_buf()
	if not file_cache[buf] then
		local path = vim.fn.expand("%:t")
		local size = vim.fn.getfsize(vim.fn.expand("%"))
		file_cache[buf] = { path = path, size = size }

		vim.api.nvim_create_autocmd("BufLeave", {
			buffer = buf,
			once = true,
			callback = function()
				file_cache[buf] = nil
			end,
		})
	end

	local cached = file_cache[buf]
	local name = (cached.path == "" and "✦ Empty ") or cached.path:match("([^/\\]+)[/\\]*$")
	local modified = vim.bo.modified and " ●" or ""
	local readonly = (not vim.bo.modifiable or vim.bo.readonly) and " " or ""

	local size_str = ""
	if cached.size > 1024 * 1024 then
		size_str = string.format("%.1fMB", cached.size / (1024 * 1024))
	elseif cached.size > 1024 then
		size_str = string.format("%.1fKB", cached.size / 1024)
	elseif cached.size > 0 then
		size_str = string.format("%dB", cached.size)
	else
		size_str = "new"
	end

	return (opts.add_icon and (M.file_icon() .. " ") or "")
		.. hl_str("SLFileInfo", name)
		.. readonly
		.. hl_str("SLModified", modified)
		.. hl_str("SLDim", " [" .. size_str .. "]")
end

-- Git branch (with icon, lualine-style)
function M.git_branch()
	-- Icon restored
	local icon = " "

	-- Use gitsigns buffer var (fastest & non-blocking)
	local branch = vim.b.gitsigns_head
	if not branch or branch == "" then
		return ""
	end

	-- Avoid string concat cost by building minimal pieces
	-- hl_str(name, text) → returns highlighted text
	return hl_str("SLGitBranch", icon .. branch) .. " "
end

-- Git status with icons (unchanged)
function M.git_status()
	if not vim.b.status_cache then
		vim.b.status_cache = {}
	end

	local cache = vim.b.status_cache.git
	local now = vim.loop.now()
	local lines = vim.api.nvim_buf_line_count(0)
	local stale = (lines > 10000) and 30000 or 10000

	if not cache or (now - (cache.timestamp or 0)) > stale then
		local gitsigns = vim.b.gitsigns_status_dict

		if not gitsigns then
			cache = { str = "", timestamp = now }
		else
			local parts = {}
			local icons = { added = " ", changed = "󰦒 ", removed = " " }
			if gitsigns.added and gitsigns.added > 0 then
				table.insert(parts, hl_str("SLGitAdded", icons.added .. gitsigns.added))
			end

			if gitsigns.changed and gitsigns.changed > 0 then
				table.insert(parts, hl_str("SLGitChanged", icons.changed .. gitsigns.changed))
			end

			if gitsigns.removed and gitsigns.removed > 0 then
				table.insert(parts, hl_str("SLGitRemoved", icons.removed .. gitsigns.removed))
			end

			local str = #parts == 0 and "" or (table.concat(parts, " ") .. " ")
			cache = { str = str, timestamp = now }
		end

		vim.b.status_cache.git = cache
	end

	return cache.str or ""
end

-- Diagnostics with detailed counts (unchanged)
function M.diagnostics()
	if not vim.b.status_cache then
		vim.b.status_cache = {}
	end

	local cache = vim.b.status_cache.diagnostics
	local now = vim.loop.now()
	local lines = vim.api.nvim_buf_line_count(0)
	local stale = (lines > 10000) and 30000 or 10000

	if not cache or (now - (cache.timestamp or 0)) > stale then
		local function get_sev(s)
			return #vim.diagnostic.get(0, { severity = s })
		end

		local res = {
			errors = get_sev(vim.diagnostic.severity.ERROR),
			warnings = get_sev(vim.diagnostic.severity.WARN),
			info = get_sev(vim.diagnostic.severity.INFO),
			hints = get_sev(vim.diagnostic.severity.HINT),
		}

		local total = res.errors + res.warnings + res.hints + res.info
		local parts = {}

		if res.errors > 0 then
			table.insert(parts, hl_str("DiagnosticError", " " .. res.errors))
		end

		if res.warnings > 0 then
			table.insert(parts, hl_str("DiagnosticWarn", " " .. res.warnings))
		end

		if res.info > 0 then
			table.insert(parts, hl_str("DiagnosticInfo", " " .. res.info))
		end

		if res.hints > 0 then
			table.insert(parts, hl_str("DiagnosticHint", " " .. res.hints))
		end

		local str = vim.bo.modifiable and total > 0 and (table.concat(parts, " ") .. " ") or ""
		cache = { str = str, timestamp = now }
		vim.b.status_cache.diagnostics = cache
	end

	return cache.str or ""
end

-- File encoding (unchanged)
function M.file_encoding()
	local enc = vim.bo.fileencoding or vim.o.encoding
	if enc:upper() == "UTF-8" then
		return ""
	end
	return hl_str("SLEncoding", enc:upper()) .. " "
end

-- File format (unchanged)
function M.file_format()
	local format = vim.bo.fileformat
	local icons = {
		unix = "",
		dos = "",
		mac = "",
	}
	return hl_str("SLFormat", icons[format] or format) .. " "
end

-- Position (unchanged)
function M.position()
	return hl_str("SLPosition", "%3l:%-2c")
end

-- Total lines (unchanged)
function M.total_lines()
	return hl_str("SLDim", "/%L")
end

-- Progress bar with percentage (unchanged)
local progress_cache = {}
function M.progress_bar()
	local buf = vim.api.nvim_get_current_buf()
	local now = vim.loop.now()
	if not progress_cache[buf] then
		progress_cache[buf] = {}
	end
	local cache = progress_cache[buf]
	local lines = vim.api.nvim_buf_line_count(0)
	local cur_line = vim.api.nvim_win_get_cursor(0)[1]
	local stale = (lines > 50000) and 5000 or 1000

	if
		not cache.percentage
		or (now - (cache.timestamp or 0)) > stale
		or cache.lines ~= lines
		or cache.cur ~= cur_line
	then
		local percentage = math.floor((cur_line / lines) * 100)
		local width = 10
		local filled = math.floor((cur_line / lines) * width)

		local hl_filled = M.get_or_create_hl("#7aa2f7", "StatusLine", { bold = true })
		local hl_empty = M.get_or_create_hl("#3b4261", "StatusLine")
		local bar = hl_filled
			.. string.rep("█", filled)
			.. "%*"
			.. hl_empty
			.. string.rep("░", width - filled)
			.. "%*"

		local pct_hl = M.get_or_create_hl("#7aa2f7", "StatusLine", { bold = true })
		cache.str = bar .. " " .. pct_hl .. percentage .. "%% %*"
		cache.percentage = percentage
		cache.lines = lines
		cache.cur = cur_line
		cache.timestamp = now

		vim.api.nvim_create_autocmd("BufLeave", {
			buffer = buf,
			once = true,
			callback = function()
				progress_cache[buf] = nil
			end,
		})
	end

	return cache.str
end

-- Filetype (unchanged)
function M.filetype()
	local ft = vim.bo.filetype
	if ft == "" then
		ft = "none"
	end
	return hl_str("SLFiletype", ft:upper())
end

-- Macro recording (unchanged)
function M.macro_recording()
	local reg = vim.fn.reg_recording()
	if reg == "" then
		return ""
	end
	return hl_str("SLModified", " ● REC @" .. reg .. " ")
end

-- Maximized window (unchanged)
function M.maximized_status()
	if not vim.b.is_zoomed then
		return ""
	end
	return hl_str("SLModified", " ⛶ ")
end

-- Search count (unchanged)
function M.search_count()
	if vim.v.hlsearch == 0 then
		return ""
	end

	local ok, result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
	if not ok or result.current == nil or result.total == 0 then
		return ""
	end

	return hl_str("SLMatches", string.format(" [%d/%d] ", result.current, result.total))
end

-- Cache invalidation (unchanged)
local function invalidate_caches()
	vim.b.status_cache = nil
	file_cache[vim.api.nvim_get_current_buf()] = nil
end

vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "BufWritePost", "BufLeave" }, {
	callback = invalidate_caches,
	group = vim.api.nvim_create_augroup("StatuslineCache", { clear = true }),
})

return M
