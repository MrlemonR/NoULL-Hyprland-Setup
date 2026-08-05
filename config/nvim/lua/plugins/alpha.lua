return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    -- Başlık (LEMON)
dashboard.section.header.val = {
"██╗     ███████╗███╗   ███╗ ██████╗ ███╗   ██╗",
"██║     ██╔════╝████╗ ████║██╔═══██╗████╗  ██║",
"██║     █████╗  ██╔████╔██║██║   ██║██╔██╗ ██║",
"██║     ██╔══╝  ██║╚██╔╝██║██║   ██║██║╚██╗██║",
"███████╗███████╗██║ ╚═╝ ██║╚██████╔╝██║ ╚████║",
"╚══════╝╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝",
"",
"L E M O N  N V I M",
}
-- butonlar kısmını şöyle değiştirin:
dashboard.section.buttons.val = {
  dashboard.button("n", "  New File", ":ene <BAR> startinsert <CR>"),
  dashboard.button("f", "󰈞  Find File", ":Telescope find_files <CR>"),
  dashboard.button("r", "󰄉  Recent Files", ":Telescope oldfiles <CR>"),
  -- Komutu güncelledik:
  dashboard.button("e", "  Explorer", ":Neotree toggle <CR>"), 
  dashboard.button("c", "  Config", ":e ~/.config/nvim/init.lua <CR>"),
  dashboard.button("p", "󰏖  Plugins", ":Lazy <CR>"),
  dashboard.button("q", "  Quit", ":qa <CR>"),
}
    -- Alt kısayollar
    dashboard.section.footer.val = "CachyOS + Neovim v0.12 Professional Setup"

    alpha.setup(dashboard.config)
  end,
}
