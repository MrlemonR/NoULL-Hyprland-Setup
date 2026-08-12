-- Dosya: lua/plugins/lsp.lua
-- LSP yapılandırması: Neovim 0.12 vim.lsp.config / vim.lsp.enable API

return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      -- cmp entegrasyonu için yetenekler (tüm sunuculara uygulanır)
      local capabilities = require("cmp_nvim_lsp").default_capabilities(
        vim.lsp.protocol.make_client_capabilities()
      )
      vim.lsp.config("*", { capabilities = capabilities })

      -- ── Lua (Neovim yapılandırması) ──────────────────────────────────────
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              checkThirdParty = false,
              library = vim.api.nvim_get_runtime_file("", true),
            },
            hint = { enable = true },
          },
        },
      })

      -- ── C/C++ (clangd) ───────────────────────────────────────────────────
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
        },
        filetypes = { "c", "cpp", "objc", "objcpp" },
        root_markers = { ".clangd", "compile_commands.json", "compile_flags.txt", ".git" },
      })

      -- ── Rust (rust-analyzer) ─────────────────────────────────────────────
      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            cargo = { allFeatures = true },
            checkOnSave = true,
            procMacro = { enable = true },
          },
        },
        root_markers = { "Cargo.toml", "rust-project.json" },
      })

      -- LSP bağlandığında buffer-local kısayollar ve görsel ipuçları
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("LemonLspAttach", { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if not client then
            return
          end

          local bufmap = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, desc = desc })
          end

          -- Tanımlara git
          bufmap("n", "gd", vim.lsp.buf.definition, "Go to Definition")
          bufmap("n", "gD", vim.lsp.buf.declaration, "Go to Declaration")
          bufmap("n", "gi", vim.lsp.buf.implementation, "Go to Implementation")
          bufmap("n", "gr", vim.lsp.buf.references, "References")
          bufmap("n", "K", vim.lsp.buf.hover, "Hover Documentation")
          bufmap("n", "<leader>ds", vim.lsp.buf.document_symbol, "Document Symbols")
          bufmap("n", "<leader>ws", vim.lsp.buf.workspace_symbol, "Workspace Symbols")
          -- goto_prev/goto_next are deprecated since 0.11 and print a warning
          -- on every jump; vim.diagnostic.jump replaces both.
          bufmap("n", "[d", function()
            vim.diagnostic.jump({ count = -1, float = true })
          end, "Previous Diagnostic")
          bufmap("n", "]d", function()
            vim.diagnostic.jump({ count = 1, float = true })
          end, "Next Diagnostic")

          -- İmza yardımı (sadece destekleyen sunucularda)
          if client.server_capabilities.signatureHelpProvider then
            bufmap("i", "<C-h>", function()
              vim.lsp.buf.signature_help()
            end, "Signature Help")
          end
        end,
      })

      -- Tanı işaretleri ve yüzen tanı metni
      vim.diagnostic.config({
        virtual_text = { prefix = "●" },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })
    end,
  },
}
