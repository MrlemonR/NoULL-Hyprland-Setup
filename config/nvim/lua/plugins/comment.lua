-- Dosya: lua/plugins/comment.lua
-- comment.nvim: satır ve blok yorumlama

return {
  "numToStr/Comment.nvim",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = {
    "JoosepAlviste/nvim-ts-context-commentstring",
  },
  config = function()
    -- pre_hook, bağımlılık yüklendikten sonra config içinde tanımlanmalı
    require("Comment").setup({
      pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
    })
  end,
  keys = {
    {
      "<leader>/",
      function()
        require("Comment.api").toggle.linewise.current()
      end,
      desc = "Toggle Comment",
    },
  },
}
