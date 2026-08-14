
require("config.animations")
require("config.autostart")
require("config.colors")
require("config.cursor")
require("config.decorations")
require("config.defaults")
require("config.environment")
require("config.input")
require("config.keybinds")
require("config.misc")
require("config.monitors")
require("config.windowrules")
require("config.keyring")

-- Control centre toggles override the values above; runs after them so a
-- EN SONDA: performans modu açıksa yukarıdaki değerleri eziyor.

-- Efektler EN SONDA ve TEK dosyada: blur, opaklık, gölge, animasyon açma,
-- boşluk, yuvarlaklık, kenarlık. Kendinden önceki her şeyi bilerek eziyor —
-- `hyprctl reload` decorations/animations'ı geri yüklediğinde kullanıcının
-- kapattıkları ve performans modu sessizce geri açılmasın diye.
require("config.effects")
