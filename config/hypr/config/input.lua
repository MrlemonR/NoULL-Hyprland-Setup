hl.config({
    input = {
	sensitivity = 0.5,
        accel_profile = "flat",
        kb_layout = "us,tr",
        --kb_options = "caps:swapescape",
        -- Without this, a Super+arrow focus change gets undone by the next
        -- mouse jitter: cursor.no_warps (cursor.lua) leaves the pointer over
        -- the OLD window, and with mouse_refocus on, follow_mouse=1 refocuses
        -- whatever is under the cursor on ANY movement, not just when it
        -- crosses into a different window. false restricts hover-refocus to
        -- an actual window-boundary crossing, so a keybind-driven focus
        -- change sticks until you deliberately move the mouse onto something
        -- else.
        mouse_refocus = false,
    },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })
