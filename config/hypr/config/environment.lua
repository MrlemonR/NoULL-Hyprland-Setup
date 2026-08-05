hl.env("HYPRCURSOR_THEME", "breeze_cursors")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
-- GTK_THEME BİLEREK YOK.
-- Dolu olduğunda settings.ini'yi de gsettings'i de ~/.config/gtk-*/gtk.css'i
-- de eziyor; sabit catppuccin yazılıydı ve tema değiştirince GTK uygulamaları
-- (pavucontrol, gnome-calculator, gnome-characters, renk seçici) hiç
-- değişmiyordu. Tema adını artık qs-theme-gtk yönetiyor.
hl.env("XDG_MENU_PREFIX", "arch-")
