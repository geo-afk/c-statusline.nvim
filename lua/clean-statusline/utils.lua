---@module "custom.statusline.utils"

local M = {}

--- Highlight string helper
function M.hl_str(group, str)
	return "%#" .. group .. "#" .. str .. "%*"
end

return M
