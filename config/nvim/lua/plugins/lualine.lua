-- Dosya: lua/plugins/lualine.lua
-- lualine.nvim: durum çubuğu

return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      -- lua/lualine/themes/lemon.lua, built from the active system palette.
      -- "auto" guesses from the highlight groups and lands on the wrong
      -- accent for half the themes.
      theme = "lemon",
      globalstatus = true,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      disabled_filetypes = { statusline = { "alpha" } },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff", "diagnostics" },
      lualine_c = {
        {
          "filename",
          file_status = true,
          path = 1, -- Göreli yol
        },
      },
      lualine_x = { "encoding", "fileformat", "filetype" },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
    extensions = { "neo-tree", "lazy", "toggleterm", "trouble" },
  },
}
