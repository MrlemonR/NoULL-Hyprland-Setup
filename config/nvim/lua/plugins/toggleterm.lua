return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      open_mapping = [[<c-\>]], -- Veya tercih ettiğiniz başka bir tuş
      direction = "float",
      float_opts = { border = "curved" },
    })
  end,
}
