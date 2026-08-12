-- Dosya: lua/plugins/mason.lua
-- Mason: LSP sunucuları, DAP ve linter kurulum yöneticisi

return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      -- C/C++, Lua ve Rust için LSP sunucuları
      ensure_installed = {
        "clangd",        -- C/C++
        "lua_ls",        -- Lua
        "rust_analyzer", -- Rust
      },
      -- mason-lspconfig v2 dropped `handlers` and `automatic_installation`:
      -- they are merged into the settings table without complaint and then
      -- ignored. `automatic_enable` is the replacement and does the
      -- vim.lsp.enable() call the old handler did by hand.
      automatic_enable = true,
    },
  },
}
