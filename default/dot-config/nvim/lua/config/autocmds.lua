-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Lazy reloads plugins.theme when Omarchy's neovim.lua changes, but does not
-- load the new colorscheme plugin or flip background. Do not `highlight clear`
-- first: if colorscheme fails you get a stripped default palette.
vim.api.nvim_create_autocmd("User", {
	pattern = "LazyReload",
	callback = function()
		local path = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")
		if vim.fn.filereadable(path) == 0 then
			return
		end
		local chunk = loadfile(path)
		if not chunk then
			return
		end
		local ok, spec = pcall(chunk)
		if not ok or type(spec) ~= "table" then
			return
		end

		local cs ---@type string|function|nil
		local names = {}
		for _, item in ipairs(spec) do
			if type(item) == "table" and item[1] then
				if item[1] == "LazyVim/LazyVim" then
					cs = item.opts and item.opts.colorscheme
				else
					names[#names + 1] = item.name or item[1]:match("([^/]+)$")
				end
			end
		end
		if not cs then
			return
		end

		pcall(function()
			require("lazy").load({ plugins = names, wait = true })
		end)

		local light = vim.fn.expand("~/.local/state/omarchy/current/theme/light.mode")
		vim.o.background = (vim.fn.filereadable(light) == 1) and "light" or "dark"
		if type(cs) == "function" then
			pcall(cs)
		else
			pcall(vim.cmd.colorscheme, cs)
		end
	end,
})
