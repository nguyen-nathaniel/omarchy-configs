return {
	-- add tokyonight
	{
		"folke/tokyonight.nvim",
		lazy = true,
		opts = {
			style = "moon",
		},
	},

	-- Configure LazyVim to load gruvbox
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "tokyonight-moon",
		},
	},
}
