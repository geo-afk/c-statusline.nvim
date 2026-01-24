---@module "custom.statusline.components"
--- Enhanced components with Shadow Eminence theming support
local utils = require("statusline.utils")
local hl_str = utils.hl_str

local M = {}
M._hls = {}
M.config = {}

-- Icon sets with Shadow Eminence defaults
local icon_sets = {
	nerd_v3 = {
		branch = "",
		added = "",
		changed = "",
		removed = "",
		error = "",
		warn = "",
		info = "",
		hint = "󰌵",
		lock = "",
		separator = "│",
		dot = "•",
		modified = "●",
		readonly = "",
		file = "◆",
		folder = "",
		lightning = "󰓅",
		spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
	},
	nerd_v2 = {
		branch = "",
		added = "",
		changed = "",
		removed = "",
		error = "",
		warn = "",
		info = "",
		hint = "󰌵",
		lock = "",
		separator = "│",
		dot = "•",
		modified = "●",
		readonly = "",
		file = "◆",
		folder = "",
		lightning = "󰓅",
		spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
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
		dot = "·",
		modified = "*",
		readonly = "RO",
		file = "#",
		folder = "/",
		lightning = ">",
		spinner = { "|", "/", "-", "\\", "|", "/", "-", "\\" },
	},
}

function M.setup(config)
	M.config = config or {}
end

function M.get_icon(name)
	local icon_set = M.config.icon_set or "nerd_v3"
	return icon_sets[icon_set][name] or icon_sets.ascii[name] or "?"
end

-- Enhanced highlight creation with theme awareness
local hl_cache = {}
function M.get_or_create_hl(fg, bg, opts)
	opts = opts or {}
	bg = bg or "StatusLine"
	fg = fg or "#ffffff"

	local bold_str = opts.bold and "bold" or ""
	local italic_str = opts.italic and "italic" or ""
	local key = table.concat({ tostring(fg), tostring(bg), bold_str, italic_str }, "_")

	if hl_cache[key] then
		return hl_cache[key]
	end

	local sanitized_fg = tostring(fg):gsub("#", "")
	local sanitized_bg = tostring(bg):gsub("#", "")
	local suffix = (opts.bold and "B" or "") .. (opts.italic and "I" or "")
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

function M.padding(nr)
	return string.rep(" ", nr or 1)
end

function M.separator(style)
	return M.get_icon(style == "vertical" and "separator" or style)
end

-- Enhanced file icon with devicons integration
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
		icon = M.get_icon("file")
		igroup = "DevIconDefault"
	end

	if not vim.bo.modifiable then
		icon = M.get_icon("lock")
		igroup = "SLNotModifiable"
	end

	return hl_str(igroup, icon)
end

-- Refined path display with smart truncation
local function get_relative_path()
	local full_path = vim.fn.expand("%:p")
	if full_path == "" then
		return M.get_icon("lightning") .. " Empty "
	end

	local cwd = vim.fn.getcwd()
	local relative = vim.fn.fnamemodify(full_path, ":~:.")

	if not relative:match("^%.%.") and not relative:match("^/") then
		local parts = {}
		for part in relative:gmatch("[^/\\]+") do
			table.insert(parts, part)
		end

		if #parts <= 3 then
			return relative
		else
			-- Shadow style: elegant truncation
			return parts[1]
				.. " "
				.. M.get_icon("dot")
				.. M.get_icon("dot")
				.. " "
				.. parts[#parts - 1]
				.. "/"
				.. parts[#parts]
		end
	else
		return vim.fn.fnamemodify(full_path, ":t")
	end
end

-- Enhanced file info with Shadow theme styling
local file_cache = {}
function M.fileinfo(opts)
	opts = opts or { add_icon = true, show_size = true }

	local buf = vim.api.nvim_get_current_buf()

	if not file_cache[buf] or not file_cache[buf].valid then
		local path = get_relative_path()
		local size = vim.fn.getfsize(vim.fn.expand("%"))
		file_cache[buf] = {
			path = path,
			size = size,
			valid = true,
			timestamp = vim.loop.now(),
		}

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

	-- Shadow theme: refined modified indicator
	local modified = vim.bo.modified and (" " .. M.get_icon("modified")) or ""
	local readonly = (not vim.bo.modifiable or vim.bo.readonly) and (" " .. M.get_icon("readonly")) or ""

	local size_str = ""
	if opts.show_size and cached.size > 0 then
		if cached.size > 1024 * 1024 then
			size_str = string.format("%.1fMB", cached.size / (1024 * 1024))
		elseif cached.size > 1024 then
			size_str = string.format("%.1fKB", cached.size / 1024)
		else
			size_str = string.format("%dB", cached.size)
		end
		size_str = " [" .. size_str .. "]"
	elseif opts.show_size then
		size_str = " [new]"
	end

	return (opts.add_icon and (M.file_icon() .. " ") or "")
		.. hl_str("SLFileInfo", name)
		.. hl_str("SLReadonly", readonly)
		.. hl_str("SLModified", modified)
		.. hl_str("SLFileInfoDim", size_str)
end

-- Refined git branch display
function M.git_branch()
	local ok, branch = pcall(function()
		return vim.b.gitsigns_head
	end)

	if not ok or not branch or branch == "" then
		return ""
	end

	local icon = M.get_icon("branch")
	return hl_str("SLGitBranch", icon .. " " .. branch)
end

-- Enhanced git status with Shadow theme colors
local function stbufnr()
	return vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
end

function M.git_status()
	local status = vim.b[stbufnr()].gitsigns_status_dict
	if not status or not status.head then
		return ""
	end

	local parts = {}
	if vim.o.columns > 90 then
		if status.added and status.added > 0 then
			table.insert(parts, hl_str("SLGitAdded", M.get_icon("added") .. " " .. status.added))
		end
		if status.changed and status.changed > 0 then
			table.insert(parts, hl_str("SLGitChanged", M.get_icon("changed") .. " " .. status.changed))
		end
		if status.removed and status.removed > 0 then
			table.insert(parts, hl_str("SLGitRemoved", M.get_icon("removed") .. " " .. status.removed))
		end
	end

	return #parts > 0 and table.concat(parts, " ") or ""
end

-- Pre-bind icons for performance
local DIAG_ICONS = {
	error = M.get_icon("error"),
	warn = M.get_icon("warn"),
	info = M.get_icon("info"),
	hint = M.get_icon("hint"),
}

-- Enhanced diagnostics with Shadow theme
function M.diagnostics()
	if not vim.diagnostic or not vim.api.nvim_buf_is_valid(0) then
		return ""
	end

	local b = vim.b
	b.status_cache = b.status_cache or {}

	local cache = b.status_cache.diagnostics
	local now = vim.uv.now()

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

	local parts = {}

	if counts.errors > 0 then
		parts[#parts + 1] = hl_str("SLDiagError", DIAG_ICONS.error .. " " .. counts.errors)
	end
	if counts.warnings > 0 then
		parts[#parts + 1] = hl_str("SLDiagWarn", DIAG_ICONS.warn .. " " .. counts.warnings)
	end
	if counts.info > 0 then
		parts[#parts + 1] = hl_str("SLDiagInfo", DIAG_ICONS.info .. " " .. counts.info)
	end
	if counts.hints > 0 then
		parts[#parts + 1] = hl_str("SLDiagHint", DIAG_ICONS.hint .. " " .. counts.hints)
	end

	local str = vim.bo.modifiable and #parts > 0 and table.concat(parts, " ") or ""

	cache = {
		str = str,
		timestamp = now,
		counts = counts,
		valid = true,
	}

	b.status_cache.diagnostics = cache
	return str
end

function M.file_encoding()
	local enc = vim.bo.fileencoding or vim.o.encoding
	if enc:upper() == "UTF-8" then
		return ""
	end
	return hl_str("SLEncoding", enc:upper())
end

function M.file_format()
	local format = vim.bo.fileformat
	local icons = {
		unix = "󰌽",
		dos = "",
		mac = "󰀵",
	}
	return hl_str("SLFormat", icons[format] or format)
end

function M.position()
	return hl_str("SLPosition", "%3l:%-2c")
end

function M.total_lines()
	return hl_str("SLFileInfoDim", "/%L")
end

-- Enhanced progress bar with Shadow Eminence styling
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

		-- Shadow Eminence style: refined progress visualization
		local width = 8
		local ratio = cur_line / lines
		local filled = math.floor(ratio * width)

		-- Use theme colors
		local hl_fill = M.get_or_create_hl("#6c3082", "StatusLine") -- Shadow purple
		local hl_empty = M.get_or_create_hl("#2a2a3a", "StatusLine") -- Subtle gray
		local hl_cap = M.get_or_create_hl("#3f3f5f", "StatusLine") -- Border
		local hl_pct = M.get_or_create_hl("#9d9dcc", "StatusLine") -- Accent

		local left_cap = "▌"
		local right_cap = "▐"
		local fill_char = "▰"
		local empty_char = "▱"

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

-- LSP Progress with Shadow Eminence spinner
M.lsp_state = M.lsp_state or {
	clients = {},
	spinner_index = 1,
	spinner_active = false,
	spinner_timer = nil,
}

local SPINNER_FRAMES = M.get_icon("spinner")

local function start_spinner()
	if M.lsp_state.spinner_timer then
		return
	end

	M.lsp_state.spinner_active = true
	M.lsp_state.spinner_timer = vim.loop.new_timer()
	M.lsp_state.spinner_timer:start(
		100,
		100,
		vim.schedule_wrap(function()
			M.lsp_state.spinner_index = (M.lsp_state.spinner_index % #SPINNER_FRAMES) + 1
			vim.cmd("redrawstatus")
		end)
	)
end

local function stop_spinner()
	if M.lsp_state.spinner_timer then
		M.lsp_state.spinner_timer:stop()
		M.lsp_state.spinner_timer:close()
		M.lsp_state.spinner_timer = nil
	end
	M.lsp_state.spinner_active = false
end

local function get_active_progress()
	local active = {}
	local now = vim.loop.now()

	for client_id, data in pairs(M.lsp_state.clients) do
		if now - data.timestamp > 30000 then
			M.lsp_state.clients[client_id] = nil
		elseif data.active then
			table.insert(active, data)
		end
	end

	return active
end

function M.lsp_progress()
	if vim.o.columns < 100 then
		return ""
	end

	local active_progress = get_active_progress()

	if #active_progress == 0 then
		stop_spinner()
		return ""
	end

	start_spinner()

	local messages = {}
	for _, progress in ipairs(active_progress) do
		local label = progress.title and progress.title ~= "" and progress.title or "Loading"
		local msg = label
		if progress.percentage then
			msg = msg .. " (" .. math.floor(progress.percentage) .. "%%)"
		end
		table.insert(messages, msg)
	end

	if #messages == 0 then
		stop_spinner()
		return ""
	end

	local spinner_frame = SPINNER_FRAMES[M.lsp_state.spinner_index]
	local content = spinner_frame .. " " .. table.concat(messages, " | ")

	return hl_str("SLLspProgress", content) .. " "
end

function M.filetype()
	local ft = vim.bo.filetype
	if ft == "" then
		ft = "none"
	end
	return hl_str("SLFiletype", ft:upper())
end

function M.macro_recording()
	local ok, reg = pcall(vim.fn.reg_recording)
	if not ok or reg == "" then
		return ""
	end
	return hl_str("SLRecording", " " .. M.get_icon("modified") .. " REC @" .. reg .. " ")
end

function M.maximized_status()
	if not vim.b.is_zoomed then
		return ""
	end
	return hl_str("SLModified", " ⛶ ")
end

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

-- Enhanced dev server status with Shadow theme
function M.dev_server_status()
	local ok, devserver = pcall(require, "dev-server")
	if not ok or not devserver then
		return ""
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local in_project, servers = devserver.is_in_project(bufnr)

	if not in_project or not servers or #servers == 0 then
		return ""
	end

	local parts = {}

	for _, name in ipairs(servers) do
		local status = devserver.get_statusline()
		if status ~= "" then
			local icon = status:match("[●○]")
			local text = status:gsub("^%s*[●○]%s*", "")

			local hl
			if icon == "●" then
				hl = "SLDevServerActive"
			elseif icon == "○" then
				hl = "SLDevServerInactive"
			else
				goto continue
			end

			table.insert(parts, hl_str(hl, " " .. icon .. " " .. text .. " "))
		end

		::continue::
	end

	return #parts > 0 and table.concat(parts, " ") or ""
end

-- Cache management autocmds
vim.api.nvim_create_augroup("StatuslineComponentCache", { clear = true })

vim.api.nvim_create_autocmd("DiagnosticChanged", {
	group = "StatuslineComponentCache",
	callback = function(args)
		local b = vim.b[args.buf]
		if b and b.status_cache and b.status_cache.diagnostics then
			b.status_cache.diagnostics.valid = false
		end
	end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
	group = "StatuslineComponentCache",
	callback = function(args)
		if file_cache[args.buf] then
			file_cache[args.buf].valid = false
		end
	end,
})

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
