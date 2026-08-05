-- Dosya: lua/plugins/colorscheme.lua
-- Ayu Red temasını etkinleştirir (colors/ayu-red.lua)

return {
  {
    -- Yerel tema: ~/.config/nvim/colors/ayu-red.lua
    dir = vim.fn.stdpath("config"),
    name = "lemon-ayu-red",
    lazy = false,
    priority = 1000,
    config = function()
      local ok, err = pcall(vim.cmd.colorscheme, "ayu-red")
      if not ok then
        vim.notify("ayu-red teması yüklenemedi: " .. err, vim.log.levels.WARN)
        vim.cmd.colorscheme("habamax")
      end
    end,
  },
}
