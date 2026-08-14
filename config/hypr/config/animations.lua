
-- Animation speed comes from the settings screen. Hyprland's `speed` is in
-- deciseconds and counts UP for slower, so the user-facing multiplier (higher =
-- snappier) is inverted here. Scaling in this file rather than re-emitting the
-- animations from effects.lua keeps one definition of each animation.
local settings = require("config.settings")
local speed_scale = settings.number("animationSpeed", 1, 0.25, 4)

local function ds(base)
    return math.max(1, math.floor(base / speed_scale + 0.5))
end

-- Default beziers
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("overshoot",      { type = "bezier", points = { {0.5, 0.9}, {0.1, 1.1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })
hl.curve("rubber",         { type = "spring", mass = 1, stiffness = 70,      dampening = 10         })

-- Animations
hl.animation({ leaf = "global",              enabled = true, speed = ds(2), bezier = "quick"                 })
hl.animation({ leaf = "workspaces",          enabled = true, speed = ds(2), bezier = "quick", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = ds(2), bezier = "quick", style = "slide top"})
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = ds(2), bezier = "quick", style = "slide bottom"})

