-- Program Resume (OSC 7577): Rex starts `nvim -S <session>` again after a
-- server restart. A few seconds after you switch buffers, persistence.nvim's
-- session is saved, and each save reports the command to the terminal. Rex
-- resumes it only with the resume.trust.nvim rule in ~/.config/rex/init.lua,
-- which trusts sessions in persistence's folder (~/.local/state/nvim/sessions).
local token = vim.env.OSC7577_TOKEN
if not token then
  return
end
-- Programs nvim starts, such as a :terminal, don't get this pane's token.
vim.env.OSC7577_TOKEN = nil

local group = vim.api.nvim_create_augroup("rex_resume", { clear = true })

-- Whether a file worth coming back to is open, as persistence's own check.
local function has_files()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].buftype == ""
      and not vim.tbl_contains({ "gitcommit", "gitrebase", "jj" }, vim.bo[b].filetype)
      and vim.api.nvim_buf_get_name(b) ~= "" then
      return true
    end
  end
  return false
end

local timer = vim.uv.new_timer()
vim.api.nvim_create_autocmd({ "BufEnter", "VimResized" }, {
  group = group,
  callback = function()
    timer:stop()
    timer:start(3000, 0, vim.schedule_wrap(function()
      local ok, persistence = pcall(require, "persistence")
      if ok and persistence.active() and has_files() then
        persistence.save()
      end
    end))
  end,
})

vim.api.nvim_create_autocmd("SessionWritePost", {
  group = group,
  callback = function()
    local file = vim.v.this_session
    if file == "" then
      return
    end
    local argv = { "nvim", "-S", file }
    for i, arg in ipairs(argv) do
      argv[i] = vim.base64.encode(arg)
    end
    -- This process is Neovim's server; the terminal runs its parent, the TUI.
    local body = ("pid=%d:time=%d:argv=%s:cwd=%s"):format(
      vim.uv.os_getppid(), os.time(), table.concat(argv, ","), vim.base64.encode(vim.fn.getcwd()))
    io.stderr:write("\27]7577;", body, ":mac=", vim.fn.sha256(body .. ":" .. token), "\27\\")
  end,
})
