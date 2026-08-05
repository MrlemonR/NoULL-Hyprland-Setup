-- Dosya: lua/plugins/notify.lua
-- nvim-notify: modern bildirim sistemi (noice.nvim için temel)

return {
  "rcarriga/nvim-notify",
  lazy = false,
  priority = 900,
  opts = {
    stages = "fade_in_slide_out",
    timeout = 3000,
    max_height = function()
      return math.floor(vim.o.lines * 0.75)
    end,
    max_width = function()
      return math.floor(vim.o.columns * 0.75)
    end,
    render = "default",
    top_down = false,
  },
  config = function(_, opts)
    local notify = require("notify")
    notify.setup(opts)
    vim.notify = notify
  end,
}
