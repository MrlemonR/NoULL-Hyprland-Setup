pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// İkon adı -> gerçek dosya yolu önbelleği.
//
// Neden gerekli: bu oturumda QT_QPA_PLATFORMTHEME=qt6ct ayarlı ama qt6ct
// yapılandırılmadığı için Qt'nin ikon teması çözümlemesi çalışmıyor;
// Quickshell.iconPath() hicolor'daki ikonlara (Claude gibi) boş dönüyor,
// kontrolsüz kullanıldığında da yüklenemeyen bir URL veriyor.
// Bu yüzden yolları qs-icon-resolve ile dosya sisteminden buluyoruz.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-icon-resolve"

    // ad -> yol ("" = arandı, bulunamadı)
    property var cache: ({})

    property var queue: []

    // İstenen ikonun yolunu döndürür. Henüz çözülmemişse kuyruğa alıp boş
    // döner; çözüldüğünde cache değiştiği için bindingler kendini yeniler.
    function iconFor(name) {
        if (!name || name.length === 0)
            return ""

        if (String(name).startsWith("/"))
            return "file://" + name

        const hit = root.cache[name]
        if (hit !== undefined)
            return hit.length > 0 ? "file://" + hit : ""

        // DİKKAT: kuyruğu doğrudan burada değiştirmek binding döngüsü
        // uyarısı üretiyordu (results -> cache -> results). Kuyruğa eklemeyi
        // bir sonraki olay döngüsüne bırakıyoruz.
        Qt.callLater(root.request, name)
        return ""
    }

    // Bir .desktop kaydının ikon yolu ("" = kaydın ikonu yok/çözülemedi)
    function iconForEntry(entry) {
        if (!entry || !entry.icon || entry.icon.length === 0)
            return ""
        return root.iconFor(entry.icon)
    }

    // Hyprland'in verdiği pencere sınıfı (appId) -> ikon yolu.
    // Bulunamazsa "" döner; çağıran taraf harf döşemesi çiziyor.
    //
    // Sırayla: StartupWMClass, .desktop kimliği/adı, appId'nin kendisi bir
    // ikon adı olabilir, son çare uygulama adının appId içinde geçmesi.
    function iconForApp(appId) {
        // DİKKAT: bu okuma bilinçli. DesktopEntries açılışta boş geliyor ve
        // sonradan doluyor; burada okuyunca binding veritabanı yüklendiğinde
        // kendini yeniden hesaplıyor. Yoksa erken çözülen ikonlar (Claude gibi)
        // sonsuza kadar boş kalıyor.
        const apps = DesktopEntries.applications.values

        if (!appId || appId.length === 0)
            return ""

        if (apps.length === 0)
            return ""

        const lower = appId.toLowerCase()
        const lastSegment = appId.includes(".") ? appId.split(".").pop().toLowerCase() : lower

        // 1) StartupWMClass tam eşleşmesi — appId ile .desktop dosyasını
        //    eşleştirmenin doğru yolu bu
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i]
            if (e.startupClass && e.startupClass.toLowerCase() === lower) {
                const icon = root.iconForEntry(e)
                if (icon.length > 0)
                    return icon
            }
        }

        // 2) .desktop kimliği / adı tam eşleşmesi
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i]
            const id = (e.id || "").toLowerCase().replace(/\.desktop$/, "")
            const name = (e.name || "").toLowerCase()
            if (id === lower || name === lower || id === lastSegment) {
                const icon = root.iconForEntry(e)
                if (icon.length > 0)
                    return icon
            }
        }

        // 3) appId'nin kendisi bir ikon adı olabilir
        const candidates = [appId, lower, lastSegment]
        for (let i = 0; i < candidates.length; i++) {
            const path = root.iconFor(candidates[i])
            if (path.length > 0)
                return path
        }

        // 4) Son çare: uygulama adı appId içinde geçiyor mu
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i]
            if (e.name && e.name.length > 2 && lower.includes(e.name.toLowerCase())) {
                const icon = root.iconForEntry(e)
                if (icon.length > 0)
                    return icon
            }
        }

        return ""
    }

    function request(name) {
        if (root.queue.indexOf(name) >= 0)
            return

        root.queue = root.queue.concat([name])
        batchTimer.restart()
    }

    // .desktop veritabanı yüklendiğinde tüm ikon adlarını tek seferde çöz
    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            const apps = DesktopEntries.applications.values
            let names = []
            for (let i = 0; i < apps.length; i++) {
                const icon = apps[i].icon
                if (icon && icon.length > 0 && root.cache[icon] === undefined && names.indexOf(icon) < 0)
                    names.push(icon)
            }
            if (names.length > 0) {
                root.queue = root.queue.concat(names)
                batchTimer.restart()
            }
        }
    }

    Timer {
        id: batchTimer

        interval: 80
        repeat: false
        onTriggered: {
            if (root.queue.length === 0 || resolveProc.running)
                return

            const batch = root.queue
            root.queue = []
            resolveProc.pendingNames = batch
            resolveProc.command = [root.script].concat(batch)
            resolveProc.running = true
        }
    }

    Process {
        id: resolveProc

        property var pendingNames: []

        running: false
        onExited: {
            // Kuyrukta yeni istek biriktiyse devam et
            if (root.queue.length > 0)
                batchTimer.restart()
        }

        stdout: StdioCollector {
            id: resolveCollector

            onStreamFinished: {
                let next = Object.assign({}, root.cache)

                // Bulunamayanları da işaretle, sonsuz istek olmasın
                for (let i = 0; i < resolveProc.pendingNames.length; i++)
                    next[resolveProc.pendingNames[i]] = ""

                const lines = resolveCollector.text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t")
                    if (parts.length === 2 && parts[0].length > 0 && parts[1].length > 0)
                        next[parts[0]] = parts[1]
                }

                root.cache = next
            }
        }
    }
}
