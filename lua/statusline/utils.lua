---@module "custom.statusline.utils"

local M = {}

--- Highlight string helper with error handling
function M.hl_str(group, str)
	if not group or not str then
		return str or ""
	end
	return "%#" .. group .. "#" .. str .. "%*"
end

--- Safe color conversion
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

--- RGB to hex conversion
function M.rgb_to_hex(r, g, b)
	return string.format("#%02x%02x%02x", r, g, b)
end

--- Blend two colors (useful for gradients)
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

--- Truncate string to width with ellipsis
function M.truncate(str, max_width, ellipsis)
	ellipsis = ellipsis or "…"
	if vim.fn.strwidth(str) <= max_width then
		return str
	end

	local truncated = ""
	local width = 0

	for char in str:gmatch(".") do
		local char_width = vim.fn.strwidth(char)
		if width + char_width + vim.fn.strwidth(ellipsis) > max_width then
			break
		end
		truncated = truncated .. char
		width = width + char_width
	end

	return truncated .. ellipsis
end

--- Safe table merge (shallow)
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

--- Check if buffer is valid and loaded
function M.is_valid_buffer(bufnr)
	return bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)
end

--- Format file size
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

--- Get highlight group colors
function M.get_hl_colors(name)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name })
	if not ok or not hl then
		return nil, nil
	end

	local fg = hl.fg and string.format("#%06x", hl.fg) or nil
	local bg = hl.bg and string.format("#%06x", hl.bg) or nil

	return fg, bg
end

--- Debounce function calls
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

--- Throttle function calls
function M.throttle(fn, delay)
	local last_call = 0
	return function(...)
		local now = vim.loop.now()
		if now - last_call >= delay then
			last_call = now
			fn(...)
		end
	end
end

return M
