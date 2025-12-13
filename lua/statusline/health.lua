---@module "custom.statusline.health"
--- Health check for the custom statusline plugin
--- Usage: :checkhealth statusline

local M = {}

--- Perform comprehensive health checks
function M.check()
	vim.health.start("Statusline Health Check")

	if vim.fn.has("nvim-0.8") == 1 then
		vim.health.ok("Neovim version >= 0.8")
	else
		vim.health.error("Neovim version < 0.8", {
			"This plugin requires Neovim 0.8 or higher",
			"Please upgrade your Neovim installation",
		})
	end

	if vim.fn.has("termguicolors") == 1 and vim.o.termguicolors then
		vim.health.ok("True color support enabled")
	else
		vim.health.warn("True color support not enabled", {
			"Add 'set termguicolors' to your config for better colors",
		})
	end

	local has_devicons, devicons = pcall(require, "nvim-web-devicons")
	if has_devicons then
		vim.health.ok("nvim-web-devicons found")
		if pcall(devicons.get_icon, "test.lua") then
			vim.health.ok("nvim-web-devicons is properly configured")
		else
			vim.health.warn("nvim-web-devicons not configured", { "Run require('nvim-web-devicons').setup()" })
		end
	else
		vim.health.warn("nvim-web-devicons not found", {
			"File icons will use fallback symbols",
			"Install nvim-web-devicons for better icons",
		})
	end

	if vim.fn.exists("*gitsigns#statusline") == 1 or package.loaded["gitsigns"] then
		vim.health.ok("Gitsigns integration available")
	else
		vim.health.warn("Gitsigns not detected", { "Install lewis6991/gitsigns.nvim for git status" })
	end

	local clients = vim.lsp.get_clients()
	if #clients > 0 then
		vim.health.ok(string.format("LSP active (%d client(s))", #clients))
	else
		vim.health.info("No active LSP clients – diagnostics shown when LSP attaches")
	end

	if vim.o.laststatus >= 2 then
		vim.health.ok("Statusline is enabled (laststatus=" .. vim.o.laststatus .. ")")
	else
		vim.health.warn("Statusline may not be visible", { "Set 'laststatus=2' or '3'" })
	end

	-- Simplified Nerd Font check
	local font_ok = vim.fn.strwidth("󰒉") == 2
	if font_ok then
		vim.health.ok("Nerd Font detected")
	else
		vim.health.warn("Nerd Font may not be installed", {
			"Install a Nerd Font or set icon_set = 'ascii'",
		})
	end

	local statusline = package.loaded["statusline"]
	if statusline and statusline.config then
		vim.health.ok("Statusline is configured")
		vim.health.info("Icon set: " .. (statusline.config.icon_set or "nerd_v3"))
	else
		vim.health.warn("Statusline not configured", { "Call require('statusline').setup()" })
	end

	vim.health.start("Performance")
	local start_time = vim.loop.hrtime()
	if statusline and statusline.Status_line then
		local ok, _ = pcall(statusline.Status_line)
		local elapsed = (vim.loop.hrtime() - start_time) / 1e6
		if ok then
			if elapsed < 5 then
				vim.health.ok(string.format("Statusline renders in %.2fms", elapsed))
			elseif elapsed < 10 then
				vim.health.warn(string.format("Statusline renders in %.2fms (acceptable)", elapsed))
			else
				vim.health.error(string.format("Statusline renders slowly: %.2fms", elapsed))
			end
		else
			vim.health.error("Error rendering statusline")
		end
	end
end

return M
