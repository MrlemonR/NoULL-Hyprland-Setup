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
      automatic_installation = true,
      handlers = {
        -- Neovim 0.12 native LSP API: vim.lsp.enable()
        function(server_name)
          vim.lsp.enable(server_name)
        end,
      },
    },
  },
}
