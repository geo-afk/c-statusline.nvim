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

	-- Create cache key
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

-- Get relative path with smart truncation (folder../subfolder/file)
local function get_relative_path()
	local full_path = vim.fn.expand("%:p")
	if full_path == "" then
		return "✦ Empty "
	end

	-- Get path relative to cwd
	local cwd = vim.fn.getcwd()
	local relative = vim.fn.fnamemodify(full_path, ":~:.")

	-- If file is in cwd or subdirectory
	if not relative:match("^%.%.") and not relative:match("^/") then
		-- Split path into components
		local parts = {}
		for part in relative:gmatch("[^/\\]+") do
			table.insert(parts, part)
		end

		if #parts <= 3 then
			-- Short path, show it all
			return relative
		else
			-- Long path, show first/../last two
			return parts[1] .. "/../" .. parts[#parts - 1] .. "/" .. parts[#parts]
		end
	else
		-- File outside cwd, just show filename
		return vim.fn.fnamemodify(full_path, ":t")
	end
end

-- File info with size cache (optimized with buffer-local caching)
local file_cache = {}
function M.fileinfo(opts)
	opts = opts or { add_icon = true, show_size = true }

	local buf = vim.api.nvim_get_current_buf()

	-- Use buffer-local cache with timestamp validation
	if not file_cache[buf] or not file_cache[buf].valid then
		local path = get_relative_path()
		local size = vim.fn.getfsize(vim.fn.expand("%"))
		file_cache[buf] = {
			path = path,
			size = size,
			valid = true,
			timestamp = vim.loop.now(),
		}

		-- Invalidate cache on buffer leave
		vim.api.nvim_create_autocmd("BufLeave", {
			buffer = buf,
			once = true,
			callback = function()
				file_cache[buf] = nil
			end,
		})
	end

	local cached = file_cache[buf]
	local name = cached.path
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

-- Git branch with caching
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

-- Prebind icons once (performance optimization)
local DIAG_ICONS = {
	error = M.get_icon("error"),
	warn = M.get_icon("warn"),
	info = M.get_icon("info"),
	hint = M.get_icon("hint"),
}

-- Diagnostics with optimized caching
function M.diagnostics()
	-- Hard guards
	if not vim.diagnostic or not vim.api.nvim_buf_is_valid(0) then
		return ""
	end

	local b = vim.b
	b.status_cache = b.status_cache or {}

	local cache = b.status_cache.diagnostics
	local now = vim.uv.now()

	-- Adaptive staleness based on buffer size
	local lines = vim.api.nvim_buf_line_count(0)
	local stale = math.min(20000, 5000 + lines * 2)

	if cache and cache.valid and (now - cache.timestamp) <= stale then
		return cache.str or ""
	end

	local diagnostics = vim.diagnostic.get(0)
	if #diagnostics == 0 then
		cache = { str = "", timestamp = now, counts = nil, valid = true }
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
		valid = true,
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

-- File format with icons
function M.file_format()
	local format = vim.bo.fileformat
	local icons = {
		unix = "󰌽 ", -- LF (Unix / Linux)
		dos = " ", -- CRLF (Windows)
		mac = "󰀵 ", -- CR (Classic Mac)
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
		or not cache.valid
		or (now - (cache.timestamp or 0)) > stale
		or cache.lines ~= lines
		or cache.cur ~= cur_line
	then
		local percentage = math.floor((cur_line / lines) * 100)

		-- Visual tuning
		local width = 8
		local ratio = cur_line / lines
		local filled = math.floor(ratio * width)

		local hl_fill = M.get_or_create_hl("#7aa2f7", "StatusLine")
		local hl_empty = M.get_or_create_hl("#414868", "StatusLine")
		local hl_cap = M.get_or_create_hl("#3b4261", "StatusLine")
		local hl_pct = M.get_or_create_hl("#a9b1d6", "StatusLine")

		local left_cap = "▌"
		local right_cap = "▐"
		local fill_char = "▪"
		local empty_char = "▫"

		local bar = hl_cap
			.. left_cap
			.. "%*"
			.. hl_fill
			.. string.rep(fill_char, filled)
			.. "%*"
			.. hl_empty
			.. string.rep(empty_char, width - filled)
			.. "%*"
			.. hl_cap
			.. right_cap
			.. "%*"

		cache.str = bar .. " " .. hl_pct .. percentage .. "%%" .. "%*"
		cache.percentage = percentage
		cache.lines = lines
		cache.cur = cur_line
		cache.timestamp = now
		cache.valid = true

		-- Invalidate cache on buffer leave
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

-- LSP Progress State Management (event-driven)
M.lsp_state = M.lsp_state
	or {
		client_name = nil,
		title = nil,
		message = nil,
		percentage = nil,
		spinner_index = 1,
		spinner_timer = nil,
	}

-- Spinner frames
local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

-- Start spinner animation
local function start_spinner()
	if M.lsp_state.spinner_timer then
		return
	end
	M.lsp_state.spinner_timer = vim.loop.new_timer()
	M.lsp_state.spinner_timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			M.lsp_state.spinner_index = (M.lsp_state.spinner_index % #SPINNER_FRAMES) + 1
			vim.cmd.redrawstatus()
		end)
	)
end

-- Stop spinner animation
local function stop_spinner()
	if M.lsp_state.spinner_timer then
		M.lsp_state.spinner_timer:stop()
		M.lsp_state.spinner_timer:close()
		M.lsp_state.spinner_timer = nil
	end
end

-- Setup autocmd for LspProgress events
local statusline_augroup = vim.api.nvim_create_augroup("StatuslineLspProgress", { clear = true })
vim.api.nvim_create_autocmd("LspProgress", {
	group = statusline_augroup,
	desc = "LSP Progress Tracker",
	pattern = { "begin", "report", "end" },
	callback = function(args)
		local data = args.data
		if not (data and data.client_id) then
			return
		end

		if data.params.value.kind == "end" then
			M.lsp_state.client_name = nil
			M.lsp_state.title = nil
			M.lsp_state.message = nil
			M.lsp_state.percentage = nil
			stop_spinner()
			vim.defer_fn(vim.cmd.redrawstatus, 500)
		else
			M.lsp_state.client_name = vim.lsp.get_client_by_id(data.client_id).name
			M.lsp_state.title = data.params.value.title
			M.lsp_state.message = data.params.value.message
			M.lsp_state.percentage = data.params.value.percentage
			start_spinner()
			vim.cmd.redrawstatus()
		end
	end,
})

-- Main LSP progress component
function M.lsp_progress()
	if vim.o.columns < 100 then
		return ""
	end

	if not M.lsp_state.title then
		return ""
	end

	local parts = {}
	local label = M.lsp_state.title or "Loading"
	table.insert(parts, label)

	if M.lsp_state.percentage then
		local pct = math.floor(tonumber(M.lsp_state.percentage) or 0)
		table.insert(parts, string.format("(%d%%%%)", pct))
	end

	local spinner_frame = SPINNER_FRAMES[M.lsp_state.spinner_index]
	local content = spinner_frame .. " " .. table.concat(parts, " ")

	return utils.hl_str("SL_LspProgress", content) .. " "
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

-- Dev server status (optimized)
function M.dev_server_status()
	local ok, devserver = pcall(require, "dev-server")
	if not ok or not devserver then
		return ""
	end

	local bufnr = vim.api.nvim_get_current_buf()

	-- Are we in a dev-server project?
	local in_project, servers = devserver.is_in_project(bufnr)
	if not in_project or not servers or #servers == 0 then
		return ""
	end

	local parts = {}

	for _, name in ipairs(servers) do
		local status = devserver.get_statusline()
		if status ~= "" then
			-- status looks like: " ● server-name" or " ○ server-name"
			local icon = status:match("[●○]")
			local text = status:gsub("^%s*[●○]%s*", "")

			local fg, bg

			if icon == "●" then
				-- running & visible
				fg = "#1a1b26"
				bg = "#9ece6a"
			elseif icon == "○" then
				-- running but hidden
				fg = "#c0caf5"
				bg = "#4a5a3a"
			else
				goto continue
			end

			local hl = M.get_or_create_hl(fg, bg, { bold = true })
			table.insert(parts, hl .. " " .. icon .. " " .. text .. " %*")
		end

		::continue::
	end

	if #parts == 0 then
		return ""
	end

	return table.concat(parts, " ")
end

-- Cache invalidation on specific events (called from init.lua)
vim.api.nvim_create_augroup("StatuslineComponentCache", { clear = true })

-- Invalidate diagnostics cache on change
vim.api.nvim_create_autocmd("DiagnosticChanged", {
	group = "StatuslineComponentCache",
	callback = function(args)
		local b = vim.b[args.buf]
		if b and b.status_cache and b.status_cache.diagnostics then
			b.status_cache.diagnostics.valid = false
		end
	end,
})

-- Invalidate file cache on write
vim.api.nvim_create_autocmd("BufWritePost", {
	group = "StatuslineComponentCache",
	callback = function(args)
		if file_cache[args.buf] then
			file_cache[args.buf].valid = false
		end
	end,
})

-- Cleanup large buffer caches
vim.api.nvim_create_autocmd("BufDelete", {
	group = "StatuslineComponentCache",
	callback = function(args)
		local bufnr = args.buf
		file_cache[bufnr] = nil
		progress_cache[bufnr] = nil

		if vim.b[bufnr].status_cache then
			vim.b[bufnr].status_cache = nil
		end
	end,
})

return M
