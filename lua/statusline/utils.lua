---@module "custom.statusline.utils"
--- Utility functions for the custom statusline

local M = {}

--- Highlight string helper with error handling
---@param group string|nil Highlight group name
---@param str string|nil String to wrap
---@return string Wrapped string or original if inputs invalid
function M.hl_str(group, str)
	if not group or not str then
		return str or ""
	end
	return "%#" .. group .. "#" .. str .. "%*"
end

--- Convert hex color to RGB
---@param hex string Hex color with or without leading '#'
---@return integer|nil r Red component (0-255)
---@return integer|nil g Green component (0-255)
---@return integer|nil b Blue component (0-255)
function M.hex_to_rgb(hex)
	hex = hex:gsub("#", "")
	if #hex ~= 6 then
		return nil
	end

	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)

	return r, g, b
end

--- Convert RGB to hex string
---@param r integer Red (0-255)
---@param g integer Green (0-255)
---@param b integer Blue (0-255)
---@return string Hex color string with leading '#'
function M.rgb_to_hex(r, g, b)
	return string.format("#%02x%02x%02x", r, g, b)
end

--- Linearly blend two hex colors
---@param color1 string First hex color
---@param color2 string Second hex color
---@param ratio number Blend ratio (0.0 = color1, 1.0 = color2)
---@return string Blended hex color
function M.blend_colors(color1, color2, ratio)
	ratio = math.max(0, math.min(1, ratio))

	local r1, g1, b1 = M.hex_to_rgb(color1)
	local r2, g2, b2 = M.hex_to_rgb(color2)

	if not (r1 and r2) then
		return color1
	end

	local r = math.floor(r1 + (r2 - r1) * ratio)
	local g = math.floor(g1 + (g2 - g1) * ratio)
	local b = math.floor(b1 + (b2 - b1) * ratio)

	return M.rgb_to_hex(r, g, b)
end

--- Truncate string to fit within a maximum display width
---@param str string Input string
---@param max_width integer Maximum width in display cells
---@param ellipsis? string Ellipsis to append (default: "…")
---@return string Truncated string
function M.truncate(str, max_width, ellipsis)
	ellipsis = ellipsis or "…"
	if vim.fn.strwidth(str) <= max_width then
		return str
	end

	local truncated = ""
	local width = 0

	-- Use grapheme iterator for proper unicode handling
	for char in vim.fn.split(str, "\\zs") do
		local char_width = vim.fn.strwidth(char)
		if width + char_width + vim.fn.strwidth(ellipsis) > max_width then
			break
		end
		truncated = truncated .. char
		width = width + char_width
	end

	return truncated .. ellipsis
end

--- Shallow merge of tables (t2 overrides t1)
---@param t1 table|nil Base table
---@param t2 table|nil Table with overriding values
---@return table Merged table
function M.merge(t1, t2)
	local result = {}
	for k, v in pairs(t1 or {}) do
		result[k] = v
	end
	for k, v in pairs(t2 or {}) do
		result[k] = v
	end
	return result
end

--- Check if a buffer is valid and loaded
---@param bufnr integer|nil Buffer number (0 for current)
---@return boolean True if valid and loaded
function M.is_valid_buffer(bufnr)
	bufnr = bufnr or 0
	return bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)
end

--- Format byte size into human-readable string
---@param bytes integer File size in bytes
---@return string Formatted size (e.g., "1.2MB", "543KB", "42B")
function M.format_size(bytes)
	if bytes > 1024 * 1024 * 1024 then
		return string.format("%.1fGB", bytes / (1024 * 1024 * 1024))
	elseif bytes > 1024 * 1024 then
		return string.format("%.1fMB", bytes / (1024 * 1024))
	elseif bytes > 1024 then
		return string.format("%.1fKB", bytes / 1024)
	elseif bytes > 0 then
		return string.format("%dB", bytes)
	else
		return "0B"
	end
end

--- Retrieve foreground and background colors from a highlight group
---@param name string Highlight group name
---@return string|nil fg Foreground hex color
---@return string|nil bg Background hex color
function M.get_hl_colors(name)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name })
	if not ok or not hl then
		return nil, nil
	end

	local fg = hl.fg and string.format("#%06x", hl.fg) or nil
	local bg = hl.bg and string.format("#%06x", hl.bg) or nil

	return fg, bg
end

--- Create a debounced version of a function
--- Delays execution until after wait milliseconds have elapsed since the last call
---@param fn function Function to debounce
---@param delay integer Delay in milliseconds
---@return function Debounced function
function M.debounce(fn, delay)
	local timer = nil
	return function(...)
		local args = { ... }
		if timer then
			vim.fn.timer_stop(timer)
		end
		timer = vim.fn.timer_start(delay, function()
			fn(unpack(args))
			timer = nil
		end)
	end
end

--- Create a throttled version of a function
--- Ensures function is called at most once per delay period
---@param fn function Function to throttle
---@param delay integer Minimum delay between calls in milliseconds
---@return function Throttled function
function M.throttle(fn, delay)
	local last_call = 0
	local pending_timer = nil

	return function(...)
		local now = vim.loop.now()
		local args = { ... }

		-- If enough time has passed, call immediately
		if now - last_call >= delay then
			last_call = now
			fn(...)
		else
			-- Otherwise schedule for later (trailing edge)
			if pending_timer then
				vim.fn.timer_stop(pending_timer)
			end

			local remaining = delay - (now - last_call)
			pending_timer = vim.fn.timer_start(remaining, function()
				last_call = vim.loop.now()
				fn(unpack(args))
				pending_timer = nil
			end)
		end
	end
end

--- Memoize a function (cache results based on arguments)
--- Useful for expensive computations with repeated calls
---@param fn function Function to memoize
---@param key_fn? function Optional function to generate cache key from arguments
---@return function Memoized function
function M.memoize(fn, key_fn)
	local cache = {}

	key_fn = key_fn or function(...)
		return table.concat({ ... }, "_")
	end

	return function(...)
		local key = key_fn(...)

		if cache[key] == nil then
			cache[key] = fn(...)
		end

		return cache[key]
	end
end

--- Deep clone a table
---@param t table Table to clone
---@return table Cloned table
function M.deep_clone(t)
	if type(t) ~= "table" then
		return t
	end

	local clone = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			clone[k] = M.deep_clone(v)
		else
			clone[k] = v
		end
	end

	return clone
end

--- Check if a table is empty
---@param t table Table to check
---@return boolean True if table is empty
function M.is_empty(t)
	return next(t) == nil
end

--- Get table length (works for non-sequential tables)
---@param t table Table to measure
---@return integer Count of elements
function M.table_len(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

--- Safe string formatting (returns empty string on error)
---@param fmt string Format string
---@param ... any Format arguments
---@return string Formatted string or empty string on error
function M.safe_format(fmt, ...)
	local ok, result = pcall(string.format, fmt, ...)
	return ok and result or ""
end

--- Clamp value between min and max
---@param value number Value to clamp
---@param min number Minimum value
---@param max number Maximum value
---@return number Clamped value
function M.clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

--- Round number to specified decimal places
---@param num number Number to round
---@param decimals? integer Number of decimal places (default: 0)
---@return number Rounded number
function M.round(num, decimals)
	decimals = decimals or 0
	local mult = 10 ^ decimals
	return math.floor(num * mult + 0.5) / mult
end

--- Check if value is in table
---@param tbl table Table to search
---@param value any Value to find
---@return boolean True if value exists in table
function M.contains(tbl, value)
	for _, v in pairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

--- Get first element that matches predicate
---@param tbl table Table to search
---@param predicate function Function that returns true for matching element
---@return any|nil First matching element or nil
function M.find(tbl, predicate)
	for _, v in pairs(tbl) do
		if predicate(v) then
			return v
		end
	end
	return nil
end

--- Map table elements through function
---@param tbl table Table to map
---@param fn function Mapping function
---@return table New table with mapped values
function M.map(tbl, fn)
	local result = {}
	for k, v in pairs(tbl) do
		result[k] = fn(v, k)
	end
	return result
end

--- Filter table elements
---@param tbl table Table to filter
---@param predicate function Function that returns true for elements to keep
---@return table New table with filtered values
function M.filter(tbl, predicate)
	local result = {}
	for k, v in pairs(tbl) do
		if predicate(v, k) then
			result[k] = v
		end
	end
	return result
end

return M
