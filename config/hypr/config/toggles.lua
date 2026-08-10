-- Control centre toggles (the cat menu in the bar, written by qs-settings).
--
-- Required from hyprland.lua just before perfmode.lua, for the same reason that
-- one exists: `hyprctl reload` re-runs animations.lua and decorations.lua, so
-- without this file a reload would quietly switch every effect back on while
-- the menu still showed it off. qs-mode normal reloads, so this is not a corner
-- case.
--
-- Source of truth: ~/.config/quickshell/settings.json. Only "off" is acted on —
-- a key that is missing, true, or unparseable leaves the config alone, so a
-- damaged file degrades to the normal look instead of a broken session.

local path = (os.getenv("HOME") or "") .. "/.config/quickshell/settings.json"

local file = io.open(path, "r")
if not file then
    return
end

local text = file:read("*a")
file:close()

-- A flat object of booleans, written only by qs-settings; a pattern match beats
-- pulling a JSON library into the compositor config for five keys.
local function disabled(key)
    return text:match('"' .. key .. '"%s*:%s*false') ~= nil
end

local cfg = {}

if disabled("animations") then
    cfg.animations = { enabled = false }
end

-- NOTE: keys that do not exist in this Hyprland version make the whole hl.config
-- call fail, not just the offending line — that is what left performance mode
-- half applied for months. Everything below is already used by perfmode.lua or
-- decorations.lua on 0.56, so it is known to resolve.
local decoration = {}

if disabled("blur") then
    decoration.blur = { enabled = false }
end

if disabled("shadows") then
    decoration.shadow = { enabled = false }
end

if disabled("transparency") then
    decoration.active_opacity = 1
    decoration.inactive_opacity = 1
    decoration.fullscreen_opacity = 1
end

if next(decoration) ~= nil then
    cfg.decoration = decoration
end

if disabled("gaps") then
    cfg.general = { gaps_in = 0, gaps_out = 0 }
end

if next(cfg) ~= nil then
    hl.config(cfg)
end
