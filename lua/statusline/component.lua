---@module "custom.statusline.components"
local utils = require("statusline.utils")
local hl_str = utils.hl_str

local M = {}
M._hls = {}
M.config = {} -- Will be populated by init.lua

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

-- Setup function to receive config from init.lua
function M.setup(config)
	M.config = config or {}
end

-- Get icon based on configured set
function M.get_icon(name)
	local icon_set = M.config.icon_set or "nerd_v3"
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

-- Prebind icons once
local DIAG_ICONS = {
	error = M.get_icon("error"),
	warn = M.get_icon("warn"),
	info = M.get_icon("info"),
	hint = M.get_icon("hint"),
}

-- Invalidate diagnostics cache on change
vim.api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function(args)
		local b = vim.b[args.buf]
		if b and b.status_cache then
			b.status_cache.diagnostics = nil
		end
	end,
})

function M.diagnostics()
	-- Hard guards
	if not vim.diagnostic or not vim.api.nvim_buf_is_valid(0) then
		return ""
	end

	local b = vim.b
	b.status_cache = b.status_cache or {}

	local cache = b.status_cache.diagnostics
	local now = vim.uv.now()

	-- Adaptive staleness (kept as safety net)
	local lines = vim.api.nvim_buf_line_count(0)
	local stale = math.min(20000, 5000 + lines * 2)

	if cache and (now - cache.timestamp) <= stale then
		return cache.str or ""
	end

	local diagnostics = vim.diagnostic.get(0)
	if #diagnostics == 0 then
		cache = { str = "", timestamp = now, counts = nil }
		b.status_cache.diagnostics = cache
		return ""
	end

	-- Single-pass severity count
	local counts = { errors = 0, warnings = 0, info = 0, hints = 0 }

	for _, d in ipairs(diagnostics) do
		local sev = d.severity
		if sev == vim.diagnostic.severity.ERROR then
			counts.errors = counts.errors + 1
		elseif sev == vim.diagnostic.severity.WARN then
			counts.warnings = counts.warnings + 1
		elseif sev == vim.diagnostic.severity.INFO then
			counts.info = counts.info + 1
		elseif sev == vim.diagnostic.severity.HINT then
			counts.hints = counts.hints + 1
		end
	end

	local total = counts.errors + counts.warnings + counts.info + counts.hints

	local parts = {}

	if counts.errors > 0 then
		parts[#parts + 1] = hl_str("DiagnosticError", DIAG_ICONS.error .. " " .. counts.errors)
	end

	if counts.warnings > 0 then
		parts[#parts + 1] = hl_str("DiagnosticWarn", DIAG_ICONS.warn .. " " .. counts.warnings)
	end

	if counts.info > 0 then
		parts[#parts + 1] = hl_str("DiagnosticInfo", DIAG_ICONS.info .. " " .. counts.info)
	end

	if counts.hints > 0 then
		parts[#parts + 1] = hl_str("DiagnosticHint", DIAG_ICONS.hint .. " " .. counts.hints)
	end

	local str = (vim.bo.modifiable and total > 0) and (table.concat(parts, " ") .. " ") or ""

	cache = {
		str = str,
		timestamp = now,
		counts = counts,
	}

	b.status_cache.diagnostics = cache
	return str
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

-- LSP Progress State Management
M.lsp_state = M.lsp_state or {
	clients = {}, -- Store per-client progress
	last_update = 0,
}

-- Spinner frames (Braille patterns for smooth animation)
local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1

-- Timer for spinner animation
local spinner_timer = nil

-- Start spinner animation
local function start_spinner()
	if spinner_timer then
		return
	end

	spinner_timer = vim.loop.new_timer()
	spinner_timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			spinner_index = (spinner_index % #SPINNER_FRAMES) + 1
			vim.cmd("redrawstatus")
		end)
	)
end

-- Stop spinner animation
local function stop_spinner()
	if spinner_timer then
		spinner_timer:stop()
		spinner_timer:close()
		spinner_timer = nil
	end
end

-- Format percentage consistently
local function format_percentage(percentage)
	if not percentage then
		return nil
	end
	-- Ensure it's a number and format with %% for statusline
	local pct = tonumber(percentage) or 0
	return string.format("%d%%%%", math.floor(pct))
end

-- Clean and format LSP progress message
local function format_lsp_message(title, message, percentage)
	local parts = {}

	-- Add title if present
	if title and title ~= "" then
		-- Trim and clean title
		title = vim.trim(title)
		table.insert(parts, title)
	end

	-- Add message if present and different from title
	if message and message ~= "" then
		message = vim.trim(message)
		if message ~= title then
			table.insert(parts, message)
		end
	end

	-- Add percentage if present
	if percentage then
		table.insert(parts, format_percentage(percentage))
	end

	return parts
end

-- Get active LSP progress messages
local function get_active_progress()
	local active = {}
	local now = vim.loop.now()

	-- Clean up old/stale messages (older than 30 seconds)
	for client_id, data in pairs(M.lsp_state.clients) do
		if now - data.timestamp > 30000 then
			M.lsp_state.clients[client_id] = nil
		elseif data.active then
			table.insert(active, data)
		end
	end

	return active
end

-- Main LSP progress component
function M.lsp_progress()
	-- Check window width
	if vim.o.columns < 100 then
		return ""
	end

	local active_progress = get_active_progress()

	-- No active progress
	if #active_progress == 0 then
		stop_spinner()
		return ""
	end

	-- Start spinner for active progress
	start_spinner()

	-- Build progress message
	local messages = {}

	for _, progress in ipairs(active_progress) do
		local parts = format_lsp_message(progress.title, progress.message, progress.percentage)

		if #parts > 0 then
			-- Add client name if multiple clients
			local msg
			if #active_progress > 1 then
				msg = string.format("[%s] %s", progress.client_name, table.concat(parts, " · "))
			else
				msg = table.concat(parts, " · ")
			end
			table.insert(messages, msg)
		end
	end

	if #messages == 0 then
		stop_spinner()
		return ""
	end

	-- Combine all messages
	local content = table.concat(messages, " | ")

	-- Add spinner
	content = SPINNER_FRAMES[spinner_index] .. " " .. content

	-- Truncate if too long
	-- local max_width = math.min(60, vim.o.columns / 3)
	-- if vim.fn.strwidth(content) > max_width then
	-- 	content = utils.truncate(content, max_width - 1, "…")
	-- end

	return utils.hl_str("SL_LspProgress", "[ " .. content .. " ]") .. " "
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
