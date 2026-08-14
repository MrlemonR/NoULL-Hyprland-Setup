-- File: lua/lemon/palette.lua
--
-- The editor's half of the system palette. Reads the same single source of
-- truth every other target reads: ~/.config/quickshell/lemonrice.json — the
-- palettes, the active theme name and everything else live in it (see
-- `qs-config`, the only thing that writes it).
--
-- Nothing is generated into the nvim config: adding a theme is still one block
-- in that file's `palettes` section and nothing else, exactly as it is for
-- kitty, dunst, btop and the bar itself.

local M = {}

M.config_path = vim.fn.expand("~/.config/quickshell/lemonrice.json")

-- Kept as aliases so the watcher in lua/plugins/colorscheme.lua keeps working;
-- both used to be separate files.
M.palettes_path = M.config_path
M.state_path = M.config_path

-- Written by `qs-theme`; only consulted when theme.txt cannot be read.
local generated_path = vim.fn.stdpath("config") .. "/lua/qs-theme.lua"

-- Inline fallback, for the same reason Theme.qml keeps one: a missing or
-- broken palettes.json must not leave the editor colorless.
local FALLBACK = {
  label = "Catppuccin Mocha",
  base = "#1e1e2e",
  mantle = "#181825",
  crust = "#11111b",
  surface0 = "#313244",
  surface1 = "#45475a",
  surface2 = "#585b70",
  overlay0 = "#6c7086",
  subtext0 = "#a6adc8",
  subtext1 = "#bac2de",
  text = "#cdd6f4",
  mauve = "#cba6f7",
  blue = "#89b4fa",
  red = "#f38ba8",
  green = "#a6e3a1",
  yellow = "#f9e2af",
  peach = "#fab387",
  pink = "#f5c2e7",
  cyan = "#94e2d5",
  hover = "#232336",
  selected = "#2a2b3d",
  divider = "#292a3d",
  dangerBg = "#45293a",
}

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local body = fd:read("*a")
  fd:close()
  return body
end

---All themes in palettes.json, keyed by name. Empty table when unreadable.
---@return table<string, table>
local function document()
  local body = read_file(M.config_path)
  if not body or body == "" then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, body)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

function M.themes()
  local doc = document()
  if not doc or type(doc.palettes) ~= "table" then
    return {}
  end
  return doc.palettes
end

---Theme names in the order palettes.json lists them.
---@return string[]
function M.names()
  local body = read_file(M.config_path) or ""
  -- json.decode loses key order, and the picker's order is the file's. Scoped
  -- to the palettes block: the document holds settings and the bar's state too
  -- now, and their keys would otherwise be listed as themes.
  local block = body:match('"palettes"%s*:%s*(%b{})') or ""
  -- Filtered against the decoded set: the pattern cannot tell a theme from a
  -- nested object, so a palette's own `"style": {` was being listed as a theme.
  local known = M.themes()
  local seen, order = {}, {}
  for name in block:gmatch('\n%s*"([%w%-_%.]+)"%s*:%s*{') do
    if known[name] and not seen[name] then
      seen[name] = true
      order[#order + 1] = name
    end
  end
  if #order > 0 then
    return order
  end
  return vim.tbl_keys(M.themes())
end

---The active theme name, with the generated qs-theme.lua as a backstop.
---@return string
function M.current_name()
  local doc = document()
  if doc and type(doc.theme) == "string" and doc.theme ~= "" then
    return doc.theme
  end

  local ok, generated = pcall(dofile, generated_path)
  if ok and type(generated) == "table" and type(generated.theme) == "string" then
    return generated.theme
  end

  return "catppuccin-mocha"
end

---A complete palette for `name` (the active theme when omitted).
---Missing keys fall back to the inline palette, so a half-written theme block
---still produces a usable editor instead of an nvim_set_hl error.
---@param name string|nil
---@return table
function M.get(name)
  name = name or M.current_name()

  local palette = vim.deepcopy(FALLBACK)
  local block = M.themes()[name]
  if type(block) == "table" then
    for key, value in pairs(block) do
      if type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then
        palette[key] = value
      end
    end
    if type(block.label) == "string" then
      palette.label = block.label
    end
  end

  palette.name = name
  return palette
end

-- ── Color math ───────────────────────────────────────────────────────────────
-- Only used to derive shades the palette does not carry (diff backgrounds,
-- selection tints). Everything else is a palette key verbatim.

---@param hex string "#rrggbb"
---@return integer, integer, integer
local function to_rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

---Mix `fg` into `bg`. `alpha` 0 = pure bg, 1 = pure fg.
---@param fg string
---@param bg string
---@param alpha number
---@return string
function M.blend(fg, bg, alpha)
  local fr, fg_, fb = to_rgb(fg)
  local br, bg_, bb = to_rgb(bg)
  local mix = function(a, b)
    return math.floor(a * alpha + b * (1 - alpha) + 0.5)
  end
  return string.format("#%02x%02x%02x", mix(fr, br), mix(fg_, bg_), mix(fb, bb))
end

---Relative luminance, 0..1. Used to tell light palettes from dark ones.
---@param hex string
---@return number
function M.luminance(hex)
  local r, g, b = to_rgb(hex)
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
end

return M
