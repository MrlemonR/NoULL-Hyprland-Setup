-- Dosya: lua/plugins/todo-comments.lua
-- todo-comments.nvim: TODO, FIXME, HACK gibi etiketleri vurgular

return {
  "folke/todo-comments.nvim",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "Todo (Trouble)" },
    { "<leader>xT", "<cmd>TodoTrouble keywords<cr>", desc = "Todo Keywords (Trouble)" },
    { "]t", function() require("todo-comments").jump_next() end, desc = "Next Todo" },
    { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev Todo" },
  },
  opts = {
    signs = true,
    highlight = {
      before = "",
      after = "",
      pattern = [[.*<(KEYWORDS)\s*:]],
      comments_only = true,
    },
  },
}
