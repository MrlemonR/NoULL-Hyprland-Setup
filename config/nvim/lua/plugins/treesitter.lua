-- File: lua/plugins/treesitter.lua
--
-- nvim-treesitter, `main` branch. The rewrite dropped the old option table
-- entirely: `setup()` now takes only `install_dir`, and `ensure_installed`,
-- `auto_install`, `highlight` and `indent` are not options any more — passing
-- them is accepted silently and does nothing, which is how this config ended
-- up with no parsers installed and treesitter highlighting off everywhere
-- except the handful of parsers Neovim ships itself.
--
-- On main, the three jobs are separate calls:
--   parsers      require("nvim-treesitter").install(langs)
--   highlight    vim.treesitter.start() per buffer
--   indent       'indentexpr'
--
-- NOTE: `main` builds every parser with the tree-sitter CLI, so
-- `tree-sitter-cli` is a hard requirement:  sudo pacman -S tree-sitter-cli
-- Without it nothing installs; the check below says so once instead of
-- failing per file.

local ENSURE = {
  "bash",
  "c",
  "cpp",
  "css",
  "diff",
  "html",
  "javascript",
  "json",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "python",
  "query",
  "rust",
  "toml",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

local warned = false

---@return boolean
local function have_cli()
  if vim.fn.executable("tree-sitter") == 1 then
    return true
  end
  if not warned then
    warned = true
    vim.schedule(function()
      vim.notify(
        "tree-sitter CLI not found — nvim-treesitter (main) cannot build parsers.\n"
          .. "Install it with:  sudo pacman -S tree-sitter-cli",
        vim.log.levels.WARN,
        { title = "treesitter" }
      )
    end)
  end
  return false
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")
      ts.setup()

      local config = require("nvim-treesitter.config")

      local function installed()
        local set = {}
        for _, lang in ipairs(config.get_installed("parsers")) do
          set[lang] = true
        end
        return set
      end

      -- What `ensure_installed` used to do.
      local present = installed()
      local missing = vim.tbl_filter(function(lang)
        return not present[lang]
      end, ENSURE)

      if #missing > 0 and have_cli() then
        ts.install(missing)
      end

      -- What `highlight`, `indent` and `auto_install` used to do. One autocmd,
      -- because on main every buffer has to be started by hand.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("LemonTreesitter", { clear = true }),
        callback = function(event)
          local lang = vim.treesitter.language.get_lang(event.match) or event.match
          if lang == "" then
            return
          end

          -- `add` returns nil + a message for a missing parser, but throws for
          -- a corrupt one, so both paths have to be caught here.
          local ok, added = pcall(vim.treesitter.language.add, lang)
          if not (ok and added) then
            -- auto_install: fetch it in the background, this buffer keeps its
            -- regex highlighting until the next time it is opened.
            if vim.tbl_contains(config.get_available(), lang) and have_cli() then
              ts.install({ lang })
            end
            return
          end

          if not pcall(vim.treesitter.start, event.buf, lang) then
            return
          end

          -- Treesitter indentation is opt-in per buffer on main.
          vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },

  -- Comment.nvim reads this to pick the right commentstring in embedded
  -- languages (JSX in JS, script blocks in HTML).
  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      enable_autocmd = false,
    },
  },
}
