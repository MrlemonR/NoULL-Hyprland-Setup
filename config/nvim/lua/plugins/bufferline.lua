-- Dosya: lua/plugins/bufferline.lua
-- bufferline.nvim: sekme çubuğu ve buffer yönetimi

return {
  "akinsho/bufferline.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      mode = "buffers",
      separator_style = "thin",
      diagnostics = "nvim_lsp",
      always_show_bufferline = true,
      offsets = {
        {
          filetype = "neo-tree",
          text = "Explorer",
          highlight = "Directory",
          text_align = "left",
        },
      },
    },
  },
}
