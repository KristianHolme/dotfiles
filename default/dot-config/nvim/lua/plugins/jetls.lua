return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Disable LanguageServer.jl from the Julia extra
        julials = {
          enabled = false,
        },
        -- JETLS: reference code lens needs editor.action.showReferences (2026-04-28+)
        jetls = {
          cmd = { "jetls", "serve" },
          filetypes = { "julia" },
          root_markers = { "Project.toml", ".git" },
          settings = {
            jetls = {
              code_lens = {
                references = true,
                testrunner = true,
              },
            },
          },
          commands = {
            ["editor.action.showReferences"] = function(command, ctx)
              local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
              local file_uri, position, references = unpack(command.arguments)
              local items = vim.lsp.util.locations_to_items(
                references,
                client.offset_encoding
              )
              vim.fn.setqflist({}, " ", {
                title = command.title,
                items = items,
              })
              vim.lsp.util.show_document({
                uri = file_uri,
                range = { start = position, ["end"] = position },
              }, client.offset_encoding)
              vim.cmd("botright copen")
            end,
          },
        },
      },
    },
  },
}
