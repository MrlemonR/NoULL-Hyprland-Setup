hl.config({
    dwindle = {
	preserve_split = true,
    },
    misc = {
	col = {
	    splash = CACHYLGREEN,
	},
	-- Duvar kağıdının altında kalan Hyprland sürüm yazısı ve logosu
	disable_splash_rendering = true,
	disable_hyprland_logo = true,
	middle_click_paste = false,
	enable_swallow = true,
	swallow_regex = "(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)",
	vrr = 3,
    },
    xwayland = {
	force_zero_scaling = true
    },
    ecosystem = {
	no_update_news = true,
	no_donation_nag = true,
    },
})

