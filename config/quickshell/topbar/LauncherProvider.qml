import QtQuick

// Başlatıcı sekmelerinin ortak arayüzü.
//
// Her sağlayıcı bir sekmeye karşılık geliyor. Sorgu `query` üzerinden gelir,
// sonuçlar `results` üzerinden verilir. Senkron sağlayıcılar results'ı bir
// binding ile hesaplar, asenkron olanlar (dosya arama gibi) bir Process
// bitince doldurur.
//
// Sonuç öğesi: { title, subtitle, icon, score, data }
//   icon: dosya yolu ya da "" (yoksa arayüz simge/harf gösterir)
QtObject {
    id: root

    // Sekme kimliği ve etiketi
    property string providerId: ""
    property string label: ""

    // Sonuç satırlarında gösterilecek nerd font simgesi (ikon bulunamazsa)
    property string glyph: "󰀻"

    // Sorgu boşken de sonuç göstersin mi
    property bool showsEmptyQuery: true

    // Sağ tarafta önizleme paneli olsun mu (Files sekmesi için)
    property bool hasPreview: false

    property string query: ""

    property var results: []

    // Bir sonucu çalıştır; true dönerse pencere kapanır
    property var activate: function (item) {
        return true
    }
}
