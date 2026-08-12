-- File: colors/lemon.lua
--
-- The LemonRice colorscheme. There is one file for every system theme because
-- the colors do not live here — they live in ~/.config/quickshell/palettes.json,
-- the same file the bar, kitty, dunst, btop, GTK and Kvantum read. Switching
-- the system theme (Super+Ctrl+Z) switches this one too; see
-- lua/plugins/colorscheme.lua for the watcher that makes it live.
--
--   :colorscheme lemon        follow the active system theme
--   :LemonTheme <name>        preview one theme without changing the system
--   :LemonTheme               back to the system theme
--
-- Adding a theme is still one block in palettes.json and nothing else.

-- Re-read on every load: this file is re-sourced on a theme switch and on a
-- palettes.json edit, and a cached module would hand back the old colors.
package.loaded["lemon.palette"] = nil
package.loaded["lemon.highlights"] = nil

local Palette = require("lemon.palette")
local Highlights = require("lemon.highlights")

local name = vim.g.lemon_theme_override or Palette.current_name()
local palette = Palette.get(name)
local background = Palette.luminance(palette.base) > 0.5 and "light" or "dark"

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.o.termguicolors = true
-- Changing 'background' re-sources whatever `g:colors_name` names (measured:
-- the colorscheme file runs a second time). Clearing the name first turns that
-- re-source into a no-op — this file is already running, and the second pass
-- would only repeat the work it is about to do.
if vim.o.background ~= background then
  vim.g.colors_name = nil
  vim.o.background = background
end
vim.g.colors_name = "lemon"

local groups, colors = Highlights.build(palette)
for group, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, group, spec)
end

for key, value in pairs(Highlights.terminal(palette)) do
  vim.g[key] = value
end

-- Published so other config can theme itself without re-deriving anything.
vim.g.lemon_palette = palette
vim.g.lemon_colors = colors

-- lualine caches its theme module; drop it so the statusline follows along.
package.loaded["lualine.themes.lemon"] = nil
