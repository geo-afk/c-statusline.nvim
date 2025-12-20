---@module "custom.statusline.components"
local utils = require("statusline.utils")
local hl_str = utils.hl_str

local M = {}
M._hls = {}

-- Icon sets with fallbacks
local icon_sets = {
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

-- Get icon based on configured set
function M.get_icon(name)
	local statusline = package.loaded["statusline"]
	local icon_set = (statusline and statusline.config and statusline.config.icon_set) or "nerd_v3"
	return icon_sets[icon_set][name] or icon_sets.ascii[name] or "?"
end

-- Optimized highlight creation with caching
local hl_cache = {}
function M.get_or_create_hl(fg, bg, opts)
	opts = opts or {}
	bg = bg or "StatusLine"
	fg = fg or "#ffffff"

	-- Create cache key (fixed to handle booleans as strings)
	local bold_str = opts.bold and "bold" or ""
	local italic_str = opts.italic and "italic" or ""
	local key = table.concat({ tostring(fg), tostring(bg), bold_str, italic_str }, "_")

	if hl_cache[key] then
		return hl_cache[key]
	end

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
			local ok, result = pcall(vim.api.nvim_get_hl, 0, { name = bg })
			bg_hl = ok and result or nil
		end

		if tostring(fg):match("^#") then
			fg_hl = { fg = fg }
		else
			local ok, result = pcall(vim.api.nvim_get_hl, 0, { name = fg })
			fg_hl = ok and result or nil
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
		local filename = vim.fn.expand("%:t")
		if filename and filename ~= "" then
			icon, igroup = devicons.get_icon(filename)
		end
	end

	if not icon then
		icon = "◆"
		igroup = "DevIconDefault"
	end

	if not vim.bo.modifiable then
		icon = M.get_icon("lock")
		igroup = "SLNotModifiable"
	end

	return hl_str(igroup, icon)
end

-- File info with size cache
local file_cache = {}
function M.fileinfo(opts)
	opts = opts or { add_icon = true, show_size = true }

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
	if opts.show_size then
		if cached.size > 1024 * 1024 then
			size_str = string.format("%.1fMB", cached.size / (1024 * 1024))
		elseif cached.size > 1024 then
			size_str = string.format("%.1fKB", cached.size / 1024)
		elseif cached.size > 0 then
			size_str = string.format("%dB", cached.size)
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

function M.git_branch()
	local ok, branch = pcall(function()
		return vim.b.gitsigns_head
	end)

	if not ok or not branch or branch == "" then
		return ""
	end

	local icon = M.get_icon("branch")
	return hl_str("SLGitBranch", icon .. " " .. branch) .. " "
end

-- Git status with icons and caching

local function stbufnr()
	return vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
end

M.git_status = function()
	local status = vim.b[stbufnr()].gitsigns_status_dict
	if not status or not status.head then
		return ""
	end

	local stats = ""
	if vim.o.columns > 90 then
		local parts = {}
		if status.added and status.added > 0 then
			table.insert(parts, hl_str("SLGitAdded", M.get_icon("added") .. " " .. status.added))
		end
		if status.changed and status.changed > 0 then
			table.insert(parts, hl_str("SLGitChanged", M.get_icon("changed") .. " " .. status.changed))
		end
		if status.removed and status.removed > 0 then
			table.insert(parts, hl_str("SLGitRemoved", M.get_icon("removed") .. " " .. status.removed))
		end
		stats = #parts == 0 and "" or (table.concat(parts, " ") .. " ")
	end

	return stats
end

-- function M.git_status()
-- 	if not vim.b.status_cache then
-- 		vim.b.status_cache = {}
-- 	end
-- 	local cache = vim.b.status_cache.git
-- 	-- get high-resolution time in ms
-- 	local now_ns = vim.loop.hrtime()
-- 	local now = now_ns / 1e6
-- 	local lines = vim.api.nvim_buf_line_count(0)
-- 	-- stale threshold in ms
-- 	local stale = (lines > 10000) and 30000 or 10000
--
-- 	if not cache or (now - (cache.timestamp or 0)) > stale then
-- 		local ok, gitsigns = pcall(function()
-- 			return vim.b.gitsigns_status_dict
-- 		end)
--
-- 		if not ok or not gitsigns then
-- 			cache = { str = "", timestamp = now }
-- 		else
-- 			local parts = {}
--
-- 			if gitsigns.added and gitsigns.added > 0 then
-- 				table.insert(parts, hl_str("SLGitAdded", M.get_icon("added") .. " " .. gitsigns.added))
-- 			end
--
-- 			if gitsigns.changed and gitsigns.changed > 0 then
-- 				table.insert(parts, hl_str("SLGitChanged", M.get_icon("changed") .. " " .. gitsigns.changed))
-- 			end
--
-- 			if gitsigns.removed and gitsigns.removed > 0 then
-- 				table.insert(parts, hl_str("SLGitRemoved", M.get_icon("removed") .. " " .. gitsigns.removed))
-- 			end
--
-- 			local str = #parts == 0 and "" or (table.concat(parts, " ") .. " ")
-- 			cache = { str = str, timestamp = now }
-- 		end
--
-- 		vim.b.status_cache.git = cache
-- 	end
--
-- 	return cache.str or ""
-- end

-- Diagnostics with detailed counts
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
				table.insert(parts, hl_str("DiagnosticError", M.get_icon("error") .. " " .. res.errors))
			end

			if res.warnings > 0 then
				table.insert(parts, hl_str("DiagnosticWarn", M.get_icon("warn") .. " " .. res.warnings))
			end

			if res.info > 0 then
				table.insert(parts, hl_str("DiagnosticInfo", M.get_icon("info") .. " " .. res.info))
			end

			if res.hints > 0 then
				table.insert(parts, hl_str("DiagnosticHint", M.get_icon("hint") .. " " .. res.hints))
			end

			local str = vim.bo.modifiable and total > 0 and (table.concat(parts, " ") .. " ") or ""
			cache = { str = str, timestamp = now }
		end

		vim.b.status_cache.diagnostics = cache
	end

	return cache.str or ""
end

-- File encoding
function M.file_encoding()
	local enc = vim.bo.fileencoding or vim.o.encoding
	if enc:upper() == "UTF-8" then
		return ""
	end
	return hl_str("SLEncoding", enc:upper()) .. " "
end

-- File format

function M.file_format()
	local format = vim.bo.fileformat
	local icons = {
		unix = " ", -- LF (Unix / Linux)
		dos = " ", -- CRLF (Windows)
		mac = " ", -- CR (Classic Mac)
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

-- Filetype
function M.filetype()
	local ft = vim.bo.filetype
	if ft == "" then
		ft = "none"
	end
	return hl_str("SLFiletype", ft:upper())
end

-- Macro recording
function M.macro_recording()
	local ok, reg = pcall(vim.fn.reg_recording)
	if not ok or reg == "" then
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

	local ok, result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 100 })
	if not ok or result.current == nil or result.total == 0 then
		return ""
	end

	return hl_str("SLMatches", string.format(" [%d/%d] ", result.current, result.total))
end

-- Enhanced cache invalidation
local function invalidate_caches()
	vim.b.status_cache = nil
	file_cache[vim.api.nvim_get_current_buf()] = nil
end

-- Cleanup for large buffers
local function cleanup_large_buffer_cache(bufnr)
	local ok, lines = pcall(vim.api.nvim_buf_line_count, bufnr)
	if ok and lines > 50000 then
		progress_cache[bufnr] = nil
		file_cache[bufnr] = nil
	end
end

-- Setup cache management
vim.api.nvim_create_augroup("StatuslineCache", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "BufWritePost" }, {
	callback = invalidate_caches,
	group = "StatuslineCache",
})

vim.api.nvim_create_autocmd("BufDelete", {
	callback = function(args)
		cleanup_large_buffer_cache(args.buf)
	end,
	group = "StatuslineCache",
})

-- Specific cache invalidation on diagnostic changes
vim.api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function()
		if vim.b.status_cache then
			vim.b.status_cache.diagnostics = nil
		end
	end,
	group = "StatuslineCache",
})

return M
