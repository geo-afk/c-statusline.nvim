---@module "custom.statusline.components"
local utils = require("statusline.utils")
local hl_str = utils.hl_str

-- OPTIMIZATION: Cache API functions at module level
local api = vim.api
local fn = vim.fn
local uv = vim.loop or vim.uv
local diagnostic = vim.diagnostic
local bo = vim.bo

local M = {}
M._hls = {}

-- Icon sets with fallbacks (OPTIMIZATION: Lazy-loaded)
local icon_sets
local function get_icon_sets()
	if not icon_sets then
		icon_sets = {
			nerd_v3 = {
				branch = " ",
				added = " ",
				changed = "󰦒 ",
				removed = " ",
				error = " ",
				warn = " ",
				info = " ",
				hint = "󰌵 ",
				lock = "󰍁 ",
				separator = "│",
				angle_right = "",
				angle_left = "",
				dot = "•",
			},
			nerd_v2 = {
				branch = " ",
				added = " ",
				changed = "󰦒 ",
				removed = " ",
				error = " ",
				warn = " ",
				info = " ",
				hint = "󰌵 ",
				lock = "󰍁 ",
				separator = "│",
				angle_right = "❯",
				angle_left = "❮",
				dot = "•",
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
				angle_right = ">",
				angle_left = "<",
				dot = "·",
			},
		}
	end
	return icon_sets
end

-- Get icon based on configured set
function M.get_icon(name)
	local statusline = package.loaded["statusline"]
	local icon_set = (statusline and statusline.config and statusline.config.icon_set) or "nerd_v3"
	local sets = get_icon_sets()
	return sets[icon_set][name] or sets.ascii[name] or "?"
end

-- Optimized highlight creation with caching
local hl_cache = {}
local hl_name_cache = {}

function M.get_or_create_hl(fg, bg, opts)
	opts = opts or {}
	bg = bg or "StatusLine"
	fg = fg or "#ffffff"

	-- OPTIMIZATION: Faster key generation
	local key = string.format("%s_%s_%s%s", fg, bg, opts.bold and "B" or "", opts.italic and "I" or "")

	if hl_cache[key] then
		return hl_cache[key]
	end

	-- Generate or retrieve cached name
	local name = hl_name_cache[key]
	if not name then
		local sanitized_fg = tostring(fg):gsub("#", "")
		local sanitized_bg = tostring(bg):gsub("#", "")
		local suffix = (opts.bold and "B" or "") .. (opts.italic and "I" or "")
		name = "SL" .. sanitized_fg .. sanitized_bg .. suffix
		hl_name_cache[key] = name
	end

	if not M._hls[name] then
		local bg_hl, fg_hl

		if tostring(bg):match("^#") then
			bg_hl = { bg = bg }
		else
			local ok, result = pcall(api.nvim_get_hl, 0, { name = bg })
			bg_hl = ok and result or nil
		end

		if tostring(fg):match("^#") then
			fg_hl = { fg = fg }
		else
			local ok, result = pcall(api.nvim_get_hl, 0, { name = fg })
			fg_hl = ok and result or nil
		end

		local bg_val = bg_hl and bg_hl.bg
		local fg_val = fg_hl and fg_hl.fg

		api.nvim_set_hl(0, name, {
			fg = fg_val and (type(fg_val) == "string" and fg_val or ("#%06x"):format(fg_val)) or fg,
			bg = bg_val and (type(bg_val) == "string" and bg_val or ("#%06x"):format(bg_val)) or "none",
			bold = opts.bold,
			italic = opts.italic,
		})
		M._hls[name] = true
	end

	local result = "%#" .. name .. "#"
	hl_cache[key] = result
	return result
end

-- Simple padding
function M.padding(nr)
	return string.rep(" ", nr or 1)
end

-- Configurable separator
local separator_cache = {}
function M.separator(style)
	style = style or "vertical"

	if separator_cache[style] then
		return separator_cache[style]
	end

	local icon = M.get_icon(style == "vertical" and "separator" or style)
	local result = hl_str("SLSeparator", icon)
	separator_cache[style] = result
	return result
end

-- Enhanced file icon with error handling
function M.file_icon()
	local ok, devicons = pcall(require, "nvim-web-devicons")
	local icon, igroup

	if ok then
		local filename = fn.expand("%:t")
		if filename and filename ~= "" then
			icon, igroup = devicons.get_icon(filename)
		end
	end

	if not icon then
		icon = "◆"
		igroup = "DevIconDefault"
	end

	if not bo.modifiable then
		icon = M.get_icon("lock")
		igroup = "SLNotModifiable"
	end

	return hl_str(igroup, icon)
end

-- OPTIMIZATION: Fast file size calculation using uv.fs_stat
local function get_file_size()
	local file = api.nvim_buf_get_name(0)
	if file == "" then
		return 0
	end

	-- OPTIMIZATION: Use uv.fs_stat instead of vim.fn.getfsize (much faster)
	local stat = uv.fs_stat(file)
	return stat and stat.size or 0
end

-- File info with size cache
local file_cache = {}
function M.fileinfo(opts)
	opts = opts or { add_icon = true, show_size = true }

	local buf = api.nvim_get_current_buf()
	local cache = file_cache[buf]

	-- OPTIMIZATION: Check changedtick to detect file changes
	local changedtick = api.nvim_buf_get_changedtick(buf)

	if not cache or cache.changedtick ~= changedtick then
		local path = fn.expand("%:t")
		local size = get_file_size()

		cache = {
			path = path,
			size = size,
			changedtick = changedtick,
		}
		file_cache[buf] = cache

		-- OPTIMIZATION: Clean up cache when buffer is deleted
		api.nvim_create_autocmd("BufDelete", {
			buffer = buf,
			once = true,
			callback = function()
				file_cache[buf] = nil
			end,
		})
	end

	local name = (cache.path == "" and "✦ Empty ") or cache.path:match("([^/\\]+)[/\\]*$")
	local modified = bo.modified and " ●" or ""
	local readonly = (not bo.modifiable or bo.readonly) and " " or ""

	local size_str = ""
	if opts.show_size then
		if cache.size > 1024 * 1024 then
			size_str = string.format("%.1fMB", cache.size / (1024 * 1024))
		elseif cache.size > 1024 then
			size_str = string.format("%.1fKB", cache.size / 1024)
		elseif cache.size > 0 then
			size_str = string.format("%dB", cache.size)
		else
			size_str = "new"
		end
		size_str = " [" .. size_str .. "]"
	end

	return (opts.add_icon and (M.file_icon() .. " ") or "")
		.. hl_str("SLFileInfo", name)
		.. readonly
		.. hl_str("SLModified", modified)
		.. hl_str("SLDim", size_str)
end

-- OPTIMIZATION: Remove unnecessary pcall, direct access is safe
function M.git_branch()
	local branch = vim.b.gitsigns_head

	if not branch or branch == "" then
		return ""
	end

	local icon = M.get_icon("branch")
	return hl_str("SLGitBranch", icon .. " " .. branch) .. " "
end

-- Git status with icons and caching
function M.git_status()
	local buf = api.nvim_get_current_buf()

	if not vim.b[buf].status_cache then
		vim.b[buf].status_cache = {}
	end
	local cache = vim.b[buf].status_cache.git

	-- OPTIMIZATION: get high-resolution time in ms
	local now = uv.hrtime() / 1e6
	local lines = api.nvim_buf_line_count(buf)
	local stale = (lines > 10000) and 30000 or 10000

	-- OPTIMIZATION: Return cached result immediately if not stale
	if cache and (now - (cache.timestamp or 0)) <= stale then
		return cache.str
	end

	-- Only do expensive lookup if cache is stale
	local gitsigns = vim.b[buf].gitsigns_status_dict

	if not gitsigns then
		cache = { str = "", timestamp = now }
	else
		local parts = {}

		if gitsigns.added and gitsigns.added > 0 then
			parts[#parts + 1] = hl_str("SLGitAdded", M.get_icon("added") .. " " .. gitsigns.added)
		end

		if gitsigns.changed and gitsigns.changed > 0 then
			parts[#parts + 1] = hl_str("SLGitChanged", M.get_icon("changed") .. " " .. gitsigns.changed)
		end

		if gitsigns.removed and gitsigns.removed > 0 then
			parts[#parts + 1] = hl_str("SLGitRemoved", M.get_icon("removed") .. " " .. gitsigns.removed)
		end

		local str = #parts == 0 and "" or (table.concat(parts, " ") .. " ")
		cache = { str = str, timestamp = now }
	end

	vim.b[buf].status_cache.git = cache
	return cache.str
end

-- Diagnostics with detailed counts
function M.diagnostics()
	local buf = api.nvim_get_current_buf()

	if not vim.b[buf].status_cache then
		vim.b[buf].status_cache = {}
	end

	local cache = vim.b[buf].status_cache.diagnostics
	local now = uv.hrtime() / 1e6 -- OPTIMIZATION: Use hrtime for consistency
	local lines = api.nvim_buf_line_count(buf)
	local stale = (lines > 10000) and 30000 or 10000

	-- OPTIMIZATION: Return cached result immediately if not stale
	if cache and (now - (cache.timestamp or 0)) <= stale then
		return cache.str
	end

	local ok, result = pcall(function()
		-- OPTIMIZATION: Use local reference to diagnostic
		local function get_sev(s)
			return #diagnostic.get(buf, { severity = s })
		end

		return {
			errors = get_sev(diagnostic.severity.ERROR),
			warnings = get_sev(diagnostic.severity.WARN),
			info = get_sev(diagnostic.severity.INFO),
			hints = get_sev(diagnostic.severity.HINT),
		}
	end)

	if not ok then
		cache = { str = "", timestamp = now }
	else
		local res = result
		local total = res.errors + res.warnings + res.hints + res.info
		local parts = {}

		if res.errors > 0 then
			parts[#parts + 1] = hl_str("DiagnosticError", M.get_icon("error") .. " " .. res.errors)
		end

		if res.warnings > 0 then
			parts[#parts + 1] = hl_str("DiagnosticWarn", M.get_icon("warn") .. " " .. res.warnings)
		end

		if res.info > 0 then
			parts[#parts + 1] = hl_str("DiagnosticInfo", M.get_icon("info") .. " " .. res.info)
		end

		if res.hints > 0 then
			parts[#parts + 1] = hl_str("DiagnosticHint", M.get_icon("hint") .. " " .. res.hints)
		end

		local str = bo.modifiable and total > 0 and (table.concat(parts, " ") .. " ") or ""
		cache = { str = str, timestamp = now }
	end

	vim.b[buf].status_cache.diagnostics = cache
	return cache.str
end

-- File encoding
function M.file_encoding()
	local enc = bo.fileencoding or vim.o.encoding
	if enc:upper() == "UTF-8" then
		return ""
	end
	return hl_str("SLEncoding", enc:upper()) .. " "
end

-- File format
function M.file_format()
	local format = bo.fileformat
	local icons = {
		unix = " ", -- LF (Unix / Linux)
		dos = " ", -- CRLF (Windows)
		mac = " ", -- CR (Classic Mac)
	}

	return hl_str("SLFormat", icons[format] or format) .. " "
end

-- Position
function M.position()
	return hl_str("SLPosition", "%3l:%-2c")
end

-- Total lines
function M.total_lines()
	return hl_str("SLDim", "/%L")
end

-- Progress bar with percentage and caching
local progress_cache = {}
function M.progress_bar()
	local buf = api.nvim_get_current_buf()
	local cur_line = api.nvim_win_get_cursor(0)[1]

	if not progress_cache[buf] then
		progress_cache[buf] = {}
	end
	local cache = progress_cache[buf]

	-- OPTIMIZATION: Return cached if position hasn't changed
	if cache.str and cache.cur == cur_line then
		return cache.str
	end

	local lines = api.nvim_buf_line_count(buf)
	local percentage = math.floor((cur_line / lines) * 100)
	local width = 10
	local filled = math.floor((cur_line / lines) * width)

	local hl_filled = M.get_or_create_hl("#7aa2f7", "StatusLine", { bold = true })
	local hl_empty = M.get_or_create_hl("#3b4261", "StatusLine")
	local bar = hl_filled .. string.rep("█", filled) .. "%*" .. hl_empty .. string.rep("░", width - filled) .. "%*"

	local pct_hl = M.get_or_create_hl("#7aa2f7", "StatusLine", { bold = true })
	cache.str = bar .. " " .. pct_hl .. percentage .. "%% %*"
	cache.percentage = percentage
	cache.lines = lines
	cache.cur = cur_line

	-- OPTIMIZATION: Clean up cache when buffer is deleted
	api.nvim_create_autocmd("BufDelete", {
		buffer = buf,
		once = true,
		callback = function()
			progress_cache[buf] = nil
		end,
	})

	return cache.str
end

-- Filetype
function M.filetype()
	local ft = bo.filetype
	if ft == "" then
		ft = "none"
	end
	return hl_str("SLFiletype", ft:upper())
end

-- Macro recording (OPTIMIZATION: Remove unnecessary pcall)
function M.macro_recording()
	local reg = fn.reg_recording()
	if reg == "" then
		return ""
	end
	return hl_str("SLModified", " ● REC @" .. reg .. " ")
end

-- Maximized window
function M.maximized_status()
	if not vim.b.is_zoomed then
		return ""
	end
	return hl_str("SLModified", " ⛶ ")
end

-- Search count
function M.search_count()
	if vim.v.hlsearch == 0 then
		return ""
	end

	local ok, result = pcall(fn.searchcount, { maxcount = 999, timeout = 100 })
	if not ok or result.current == nil or result.total == 0 then
		return ""
	end

	return hl_str("SLMatches", string.format(" [%d/%d] ", result.current, result.total))
end

-- OPTIMIZATION: Selective cache invalidation
local function invalidate_file_cache(bufnr)
	file_cache[bufnr] = nil
end

local function invalidate_diagnostics_cache(bufnr)
	if vim.b[bufnr].status_cache then
		vim.b[bufnr].status_cache.diagnostics = nil
	end
end

local function invalidate_git_cache(bufnr)
	if vim.b[bufnr].status_cache then
		vim.b[bufnr].status_cache.git = nil
	end
end

-- Cleanup for large buffers
local function cleanup_large_buffer_cache(bufnr)
	local ok, lines = pcall(api.nvim_buf_line_count, bufnr)
	if ok and lines > 50000 then
		progress_cache[bufnr] = nil
		file_cache[bufnr] = nil
	end
end

-- Setup cache management with selective invalidation
api.nvim_create_augroup("StatuslineCache", { clear = true })

-- OPTIMIZATION: Only invalidate file cache on writes
api.nvim_create_autocmd("BufWritePost", {
	callback = function(args)
		invalidate_file_cache(args.buf)
	end,
	group = "StatuslineCache",
})

api.nvim_create_autocmd("BufDelete", {
	callback = function(args)
		cleanup_large_buffer_cache(args.buf)
		file_cache[args.buf] = nil
		progress_cache[args.buf] = nil
	end,
	group = "StatuslineCache",
})

-- OPTIMIZATION: Specific cache invalidation on diagnostic changes
api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function(args)
		invalidate_diagnostics_cache(args.buf)
	end,
	group = "StatuslineCache",
})

-- OPTIMIZATION: Invalidate git cache on git updates
api.nvim_create_autocmd("User", {
	pattern = "GitSignsUpdate",
	callback = function()
		local buf = api.nvim_get_current_buf()
		invalidate_git_cache(buf)
	end,
	group = "StatuslineCache",
})

return M
