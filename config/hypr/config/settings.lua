-- Reads ~/.config/quickshell/lemonrice.json for the compositor config.
--
-- The control centre / settings screen stores two kinds of value there:
-- booleans (animations, blur, shadows, transparency, gaps, aeroGlass) and
-- numbers (animationSpeed, blurAmount, transparencyAmount, gapsAmount).
--
-- The booleans are acted on by toggles.lua, which only ever turns things OFF.
-- The numbers are different: they change what "on" *means*, so they belong in
-- the files that define the on-values — animations.lua and decorations.lua —
-- rather than being re-applied on top afterwards. That keeps one definition of
-- each setting instead of a config value and a shadow copy in toggles.lua.
--
-- Deliberately a pattern match, not a JSON library: the compositor config has
-- no package path to speak of, and a missing or damaged file has to degrade to
-- the configured defaults rather than break the session.
--
-- The file holds the palettes too, so the match is SCOPED to the "settings"
-- block first. Without that, a key that happens to appear in a palette or in
-- the bar section would answer for a setting that is not there.

local M = {}

local path = (os.getenv("HOME") or "") .. "/.config/quickshell/lemonrice.json"

local text = ""
local file = io.open(path, "r")
if file then
    local whole = file:read("*a") or ""
    file:close()
    -- Everything from `"settings": {` up to its closing brace. The block has no
    -- nested objects, so the first `}` is the right one.
    text = whole:match('"settings"%s*:%s*(%b{})') or ""
end

---True only when the key is explicitly `false`. Missing means on, so a fresh
---install with no settings.json looks normal instead of switched off.
---@param key string
---@return boolean
function M.disabled(key)
    return text:match('"' .. key .. '"%s*:%s*false') ~= nil
end

---True when the key is present AND true. `disabled` answers "explicitly
---false"; this answers "explicitly on", which is what an opt-in effect needs —
---absent must not read as enabled.
---@param key string
---@return boolean
function M.explicit(key)
    return text:match('"' .. key .. '"%s*:%s*true') ~= nil
end

---A stored number, or `fallback` when absent or unparseable.
---@param key string
---@param fallback number
---@param min number
---@param max number
---@return number
function M.number(key, fallback, min, max)
    local raw = text:match('"' .. key .. '"%s*:%s*(-?%d+%.?%d*)')
    local value = tonumber(raw)
    if not value then
        return fallback
    end
    -- Clamped here rather than trusted: this file runs inside the compositor,
    -- and a hand-edited 500 for gaps would leave a session with no usable
    -- window area and no obvious way back.
    if value < min then return min end
    if value > max then return max end
    return value
end

return M
