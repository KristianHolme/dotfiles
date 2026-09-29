return {
  "chomosuke/typst-preview.nvim",
  keys = {
    { "<leader>cj", "<cmd>TypstPreviewSyncCursor<cr>", ft = "typst", desc = "Typst: jump preview to cursor" },
    { "<leader>ct", "<cmd>TypstPreviewFollowCursorToggle<cr>", ft = "typst", desc = "Typst: toggle follow cursor" },
  },
  opts = {
    open_cmd = "omarchy-launch-webapp %s", -- borderless app window instead of a browser tab
    -- follow_cursor = false, -- use <leader>cj to sync on demand
  },
}
