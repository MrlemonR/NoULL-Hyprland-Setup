-- Temel ayarları yükle
vim.g.mapleader = " "
vim.g.localleader = " "

require("core.options")
require("core.keymaps")

-- Lazy.nvim (Plugin yöneticisi) kurulumu
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Pluginleri yükle
require("lazy").setup("plugins")
