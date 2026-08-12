-- File: lua/plugins/colorscheme.lua
--
-- Colors come from the system palette (~/.config/quickshell/palettes.json) via
-- colors/lemon.lua, and follow the theme picker live: the two files are
-- watched, so Super+Ctrl+Z restyles every open nvim without a restart, the
-- same way it restyles the bar, kitty and dunst.
--
--   :LemonTheme <name>   pin one theme in this instance only
--   :LemonTheme          release the pin, follow the system again
--
-- colors/ayu-red.lua is still here and still selectable (`:colorscheme
-- ayu-red`); it just is not the default any more.

local Palette = require("lemon.palette")

local function apply()
  local ok, err = pcall(vim.cmd.colorscheme, "lemon")
  if not ok then
    vim.notify("lemon colorscheme failed: " .. tostring(err), vim.log.levels.WARN)
    pcall(vim.cmd.colorscheme, "habamax")
  end
end

-- One watcher per file. Re-armed after every event because a theme switch can
-- replace the file rather than truncate it, and a stale handle then watches an
-- inode nothing writes to any more.
local function watch(path, on_change)
  local handle
  local timer = vim.uv.new_timer()

  local function arm()
    if handle then
      handle:stop()
    end
    handle = vim.uv.new_fs_event()
    if not handle then
      return
    end
    handle:start(path, {}, function()
      -- Coalesce the burst a single write produces.
      timer:stop()
      timer:start(60, 0, vim.schedule_wrap(on_change))
      vim.schedule(arm)
    end)
  end

  arm()
end

return {
  {
    -- Not a real plugin: the config dir is already on the runtimepath, this
    -- spec only gives the colorscheme a load order among the other specs.
    dir = vim.fn.stdpath("config"),
    name = "lemon-theme",
    lazy = false,
    priority = 1000,
    config = function()
      apply()

      vim.api.nvim_create_user_command("LemonTheme", function(opts)
        local name = vim.trim(opts.args)
        if name == "" then
          vim.g.lemon_theme_override = nil
        else
          if not Palette.themes()[name] then
            vim.notify("no theme named '" .. name .. "' in palettes.json", vim.log.levels.ERROR)
            return
          end
          vim.g.lemon_theme_override = name
        end
        apply()
        vim.notify("theme: " .. (vim.g.lemon_palette and vim.g.lemon_palette.label or "?"))
      end, {
        nargs = "?",
        desc = "Pin a palettes.json theme (no argument follows the system theme)",
        complete = function(lead)
          return vim.tbl_filter(function(n)
            return n:find(lead, 1, true) == 1
          end, Palette.names())
        end,
      })

      -- Kept for muscle memory from the old theme-sync plugin.
      vim.api.nvim_create_user_command("QsTheme", apply, {
        desc = "Re-apply the system theme",
      })

      local function follow()
        if vim.g.lemon_theme_override then
          return -- pinned by :LemonTheme, a system switch must not override it
        end
        apply()
      end

      watch(Palette.state_path, follow)
      watch(Palette.palettes_path, apply)
    end,
  },

  {
    -- Left installed but never loaded: `:colorscheme catppuccin-mocha` still
    -- works if you want the upstream flavour instead of the generated one.
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = { flavour = "mocha" },
  },
}
