-- File: lua/lualine/themes/lemon.lua
--
-- lualine theme built from the active system palette, so the statusline moves
-- with the rest of the desktop instead of guessing colors off the highlight
-- groups. colors/lemon.lua drops this module from package.loaded on every
-- theme switch, which is what makes lualine pick the new colors up.

local palette = vim.g.lemon_palette or require("lemon.palette").get()

local bg = palette.base
local bar = palette.mantle
local dim = palette.subtext0
local faint = palette.overlay0

-- Mode colors have to differ from each other or the whole point is lost, and
-- some palettes spend one hex on two keys — Everforest's `mauve` and `green`
-- are both #a7c080, which put normal and insert in the same green (see
-- PROJECT.md gotcha #40). Each mode takes its preferred accent, or the first
-- of its alternatives nothing has claimed yet. Normal is served first so it
-- always keeps the palette accent the bar uses.
local taken = {}

---@param preferred string
---@param alternatives string[]
---@return string
local function claim(preferred, alternatives)
  for _, color in ipairs(vim.list_extend({ preferred }, alternatives)) do
    if not taken[color:lower()] then
      taken[color:lower()] = true
      return color
    end
  end
  return preferred
end

---Section a/b/c for one mode, given its accent.
---@param accent string
local function mode(accent)
  return {
    a = { fg = bg, bg = accent, gui = "bold" },
    b = { fg = accent, bg = palette.surface0 },
    c = { fg = dim, bg = bar },
  }
end

return {
  normal = mode(claim(palette.mauve, {})),
  insert = mode(claim(palette.green, { palette.blue, palette.cyan, palette.yellow })),
  visual = mode(claim(palette.peach, { palette.yellow, palette.pink, palette.cyan })),
  replace = mode(claim(palette.red, { palette.peach, palette.pink })),
  command = mode(claim(palette.yellow, { palette.peach, palette.cyan })),
  terminal = mode(claim(palette.cyan, { palette.blue, palette.green })),
  inactive = {
    a = { fg = faint, bg = bar },
    b = { fg = faint, bg = bar },
    c = { fg = faint, bg = bar },
  },
}
-- NB: every key in this table has to be a mode holding {a,b,c}. lualine walks
-- it with a nested pairs() and does not check — one extra scalar field here
-- (a theme name, a stray color) throws "bad argument #1 to 'pairs'" out of
-- lualine/highlight.lua before the statusline is ever drawn.
