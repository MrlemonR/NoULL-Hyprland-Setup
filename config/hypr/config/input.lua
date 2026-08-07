hl.config({
    input = {
	sensitivity = 0.5,
        accel_profile = "flat",
        kb_layout = "us,tr",
        --kb_options = "caps:swapescape",
        -- NOTE: mouse_refocus was set to false here for a while, to stop a
        -- Super+arrow focus change being undone by the next mouse jitter.
        -- That problem is solved differently now (cursor.no_warps left at its
        -- default so the pointer follows focus, and Alt+Tab going through
        -- qs-focus-keep-cursor instead), so the override is gone: leaving
        -- pointer focus stale is a good way to have a press and its release
        -- land on two different surfaces, which reads as a stuck drag.
    },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })
