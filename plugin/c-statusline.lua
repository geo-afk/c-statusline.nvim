-- Autoload setup via plugin managers
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		require("statusline").setup()
	end,
})
