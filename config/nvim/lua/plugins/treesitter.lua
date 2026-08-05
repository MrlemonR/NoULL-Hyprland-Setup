-- Dosya: lua/plugins/treesitter.lua
-- nvim-treesitter: sözdizimi vurgulama, girinti ve ayrıştırıcı yönetimi

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter").setup({
        -- C/C++, Lua, Rust ve Neovim yapılandırması için gerekli ayrıştırıcılar
        ensure_installed = {
          "bash",
          "c",
          "cpp",
          "css",
          "html",
          "javascript",
          "json",
          "lua",
          "markdown",
          "markdown_inline",
          "python",
          "query",
          "rust",
          "toml",
          "typescript",
          "vim",
          "vimdoc",
        },
        -- Eksik ayrıştırıcıları dosya açıldığında otomatik kur
        auto_install = true,
        -- Sözdizimi vurgulama (Neovim 0.12 native entegrasyonu)
        highlight = { enable = true },
        -- Treesitter tabanlı girinti
        indent = { enable = true },
        -- Büyük dosyalarda performans koruması
        sync_install = false,
      })
    end,
  },
  -- Yorum satırları için treesitter desteği (comment.nvim ile birlikte kullanılır)
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      enable_autocmd = false,
    },
  },
}
