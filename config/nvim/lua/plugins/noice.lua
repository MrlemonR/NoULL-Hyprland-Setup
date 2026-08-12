-- Dosya: lua/plugins/noice.lua
-- noice.nvim: cmdline, mesaj ve LSP ilerleme çubuğu görselleştirmesi

return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  opts = {
    lsp = {
      override = {
        -- vim.lsp.util.convert_to_markdown_table was removed in Neovim 0.11;
        -- overriding a function that no longer exists is a no-op at best.
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
      progress = {
        enabled = true,
        format = "lsp_progress",
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = true,
    },
    routes = {
      {
        filter = {
          event = "msg_show",
          any = {
            { find = "%d+L, %d+B" },
            { find = "; after #%d+" },
            { find = "; before #%d+" },
            { find = "%d fewer lines" },
            { find = "%d more lines" },
          },
        },
        opts = { skip = true },
      },
    },
  },
}
