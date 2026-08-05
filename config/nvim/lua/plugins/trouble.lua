-- Dosya: lua/plugins/trouble.lua
-- trouble.nvim: tanılar, LSP referansları ve sembol listesi

return {
  "folke/trouble.nvim",
  cmd = { "Trouble", "TroubleToggle" },
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
    { "<leader>xw", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics" },
    { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols (Trouble)" },
    { "gR", "<cmd>Trouble lsp_references toggle<cr>", desc = "LSP References" },
  },
  opts = {
    focus = true,
    auto_open = false,
    auto_close = false,
    use_diagnostic_signs = true,
  },
}
