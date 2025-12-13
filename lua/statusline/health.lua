---@module "custom.statusline.health"
--- Health check for statusline plugin
--- Run with :checkhealth statusline

local M = {}

function M.check()
	vim.health.start("Statusline Health Check")

	-- Check Neovim version
	if vim.fn.has("nvim-0.8") == 1 then
		vim.health.ok("Neovim version >= 0.8")
	else
		vim.health.error("Neovim version < 0.8", {
			"This plugin requires Neovim 0.8 or higher",
			"Please upgrade your Neovim installation",
		})
	end

	-- Check for true color support
	if vim.fn.has("termguicolors") == 1 and vim.o.termguicolors then
		vim.health.ok("True color support enabled")
	else
		vim.health.warn("True color support not enabled", {
			"Add 'set termguicolors' to your config for better colors",
		})
	end

	-- Check for nvim-web-devicons
	local has_devicons, devicons = pcall(require, "nvim-web-devicons")
	if has_devicons then
		vim.health.ok("nvim-web-devicons found")
		local setup_ok = pcall(devicons.get_icon, "test.lua")
		if setup_ok then
			vim.health.ok("nvim-web-devicons is properly configured")
		else
			vim.health.warn("nvim-web-devicons not configured", {
				"Run require('nvim-web-devicons').setup() in your config",
			})
		end
	else
		vim.health.warn("nvim-web-devicons not found", {
			"File icons will use fallback symbols",
			"Install nvim-web-devicons for better file type icons",
		})
	end

	-- Check for Gitsigns
	local has_gitsigns = vim.fn.exists("*gitsigns#statusline") == 1 or package.loaded["gitsigns"]
	if has_gitsigns then
		vim.health.ok("Gitsigns integration available")
	else
		vim.health.warn("Gitsigns not detected", {
			"Git status will not be shown",
			"Install lewis6991/gitsigns.nvim for git integration",
		})
	end

	-- Check LSP and diagnostics
	local clients = vim.lsp.get_clients()
	if #clients > 0 then
		vim.health.ok(string.format("LSP active (%d client(s))", #clients))
	else
		vim.health.info("No active LSP clients, Diagnostic counts will be shown when LSP is active")
	end

	-- Check statusline configuration
	if vim.o.laststatus >= 2 then
		vim.health.ok("Statusline is enabled (laststatus=" .. vim.o.laststatus .. ")")
	else
		vim.health.warn("Statusline may not be visible", {
			"Set 'laststatus' to 2 or 3 in your config",
		})
	end

	-- Check for Nerd Font
	local test_icons = { "", "", "", "󰒉", "" }
	local font_ok = true
	for _, icon in ipairs(test_icons) do
		if vim.fn.strwidth(icon) ~= 2 then
			font_ok = false
			break
		end
	end

	if font_ok then
		vim.health.ok("Nerd Font detected")
	else
		vim.health.warn("Nerd Font may not be installed", {
			"Some icons may not display correctly",
			"Install a Nerd Font from https://www.nerdfonts.com/",
			"Or set icon_set = 'ascii' in config",
		})
	end

	-- Check configuration
	local statusline = package.loaded["statusline"]
	if statusline and statusline.config then
		vim.health.ok("Statusline is configured")

		-- Check icon set
		local icon_set = statusline.config.icon_set or "nerd_v3"
		vim.health.info("Icon set: " .. icon_set)

		-- Check enabled components
		local components = statusline.config.components or {}
		vim.health.info("Enabled components:")
		for name, config in pairs(components) do
			if config.enabled then
				vim.health.info("  • " .. name)
			end
		end
	else
		vim.health.warn("Statusline not configured", {
			"Call require('statusline').setup() in your config",
		})
	end

	-- Performance check
	vim.health.start("Performance")

	local start_time = vim.loop.hrtime()
	if statusline and statusline.Status_line then
		local ok, result = pcall(statusline.Status_line)
		if ok then
			local elapsed = (vim.loop.hrtime() - start_time) / 1e6
			if elapsed < 5 then
				vim.health.ok(string.format("Statusline renders in %.2fms", elapsed))
			elseif elapsed < 10 then
				vim.health.warn(string.format("Statusline renders in %.2fms (acceptable)", elapsed))
			else
				vim.health.error(string.format("Statusline renders slowly: %.2fms", elapsed), {
					"Consider disabling some components",
					"Check for large files or slow git operations",
				})
			end
		else
			vim.health.error("Error rendering statusline: " .. tostring(result))
		end
	end
end

return M
