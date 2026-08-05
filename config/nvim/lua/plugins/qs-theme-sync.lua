-- Dosya: lua/plugins/qs-theme-sync.lua
--
-- quickshell tema seçicisiyle (Super+Ctrl+Z) senkron nvim teması.
-- Etkin tema ~/.config/quickshell/theme.txt dosyasından okunuyor.
--
-- Eşleme:
--   catppuccin-mocha -> catppuccin-mocha (catppuccin/nvim eklentisi)
--   monochrome       -> quiet            (nvim'in yerleşik gri tema)
--
-- Mevcut ayu-red teması dosyası duruyor; bu spec daha sonra çalıştığı için
-- kazanır. Eski davranışa dönmek istersen bu dosyayı sil.

local STATE = vim.fn.expand("~/.config/quickshell/theme.txt")

local MAP = {
  ["catppuccin-mocha"] = "catppuccin-mocha",
  ["monochrome"] = "quiet",
}

local function current_theme()
  local ok, lines = pcall(vim.fn.readfile, STATE)
  if not ok or not lines or not lines[1] then
    return nil
  end
  return (lines[1]:gsub("%s+", ""))
end

local function apply()
  local theme = current_theme()
  local scheme = theme and MAP[theme] or nil
  if not scheme then
    return
  end

  local ok = pcall(vim.cmd.colorscheme, scheme)
  if not ok then
    -- Eklenti henüz kurulmadıysa sessizce geç
    pcall(vim.cmd.colorscheme, "quiet")
  end
end

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1001,
    opts = {
      flavour = "mocha",
      transparent_background = false,
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)

      -- Diğer tema specleri yüklendikten sonra son sözü biz söyleyelim
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = apply,
      })

      -- Tema değişince elle yenilemek için
      vim.api.nvim_create_user_command("QsTheme", apply, {
        desc = "quickshell temasını yeniden uygula",
      })
    end,
  },
}
