-- Bilinen monitör için sabit ayar, geri kalan her çıkış için otomatik.
-- Sıra önemli: önce genel kural, sonra özel olan onu eziyor. Böylece config
-- başka bir makinede de (farklı çıkış adı/çözünürlük) doğru açılıyor.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

hl.monitor({
    output    = "HDMI-A-1",
    mode      = "1920x1080@180",
    position  = "0x0",
    scale     = "1",
})

