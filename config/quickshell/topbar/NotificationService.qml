pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Dunst'ı veri kaynağı olarak kullanan bildirim merkezi durumu.
// Bildirim sunucusunu quickshell'e devretmiyoruz; dunst çalışmaya devam
// ediyor, biz sadece `dunstctl` üzerinden geçmişi ve duraklatma durumunu
// okuyup üstüne okunmamış sayacı ekliyoruz.
Singleton {
    id: root

    // ---------------- Durum ----------------

    // { id, appname, summary, body, icon, urgency, timestamp } listesi
    property var notifications: []
    property bool dnd: false

    // Bu id'den büyük id'ye sahip bildirimler "okunmamış" sayılır.
    property int lastSeenId: 0

    // /proc/uptime — dunst zaman damgaları monotonik saatten geliyor
    property real monotonicNow: 0

    readonly property int unreadCount: {
        let n = 0;
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id > root.lastSeenId)
                n++;
        }
        return n;
    }

    readonly property string badgeText: unreadCount > 9 ? "9+" : String(unreadCount)

    readonly property string seenFile: "$HOME/.cache/quickshell-notif-seen"

    // ---------------- Eylemler ----------------

    function refresh() {
        if (!pollProc.running)
            pollProc.running = true;
    }

    function markAllRead() {
        let maxId = root.lastSeenId;
        for (let i = 0; i < root.notifications.length; i++) {
            if (root.notifications[i].id > maxId)
                maxId = root.notifications[i].id;
        }
        if (maxId === root.lastSeenId)
            return;

        root.lastSeenId = maxId;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"" + root.seenFile + "\"", "sh", String(maxId)]);
    }

    function setDnd(value) {
        // Anında geri bildirim ver, bir sonraki yoklamada dunst ile senkronlanır
        root.dnd = value;
        Quickshell.execDetached(["dunstctl", "set-paused", value ? "true" : "false"]);
        syncTimer.restart();
    }

    function toggleDnd() {
        setDnd(!root.dnd);
    }

    function clearAll() {
        root.notifications = [];
        Quickshell.execDetached(["dunstctl", "history-clear"]);
        syncTimer.restart();
    }

    function dismiss(id) {
        root.notifications = root.notifications.filter(n => n.id !== id);
        Quickshell.execDetached(["dunstctl", "history-rm", String(id)]);
        syncTimer.restart();
    }

    // ---------------- Yardımcılar ----------------

    // Pango işaretlemesini, HTML kaçışlarını ve yön izolasyon karakterlerini temizler
    function cleanText(value) {
        if (!value)
            return "";

        return String(value)
            .replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&apos;/g, "'")
            .replace(/&#39;/g, "'")
            .replace(/&amp;/g, "&")
            .replace(new RegExp("[\\u2066-\\u2069]", "g"), "")
            .trim();
    }

    // dunst-notify gövdenin sonuna geri sayım çubuğu ekliyor, onu atıyoruz
    function cleanBody(value) {
        return cleanText(String(value || "").replace(/[█░]+/g, ""));
    }

    function iconSource(path) {
        if (!path)
            return "";
        if (path.startsWith("/"))
            return "file://" + path;
        return Quickshell.iconPath(path, "dialog-information");
    }

    function relativeTime(timestamp) {
        const age = Math.max(0, root.monotonicNow - timestamp);
        if (age < 60)
            return "now";
        if (age < 3600)
            return Math.floor(age / 60) + "m";
        if (age < 86400)
            return Math.floor(age / 3600) + "h";
        return Math.floor(age / 86400) + "d";
    }

    function urgencyColor(urgency) {
        if (urgency === "CRITICAL")
            return Theme.red;
        if (urgency === "LOW")
            return Theme.surface2;
        return Theme.mauve;
    }

    // ---------------- Yoklama ----------------

    Process {
        id: pollProc

        running: true
        command: ["sh", "-c", `u=$(cut -d' ' -f1 /proc/uptime); p=$(dunstctl is-paused 2>/dev/null); h=$(dunstctl history 2>/dev/null); [ -n "$p" ] || p=false; [ -n "$h" ] || h='{"data":[[]]}'; printf '{"uptime":%s,"paused":%s,"history":%s}' "$u" "$p" "$h"`]

        stdout: StdioCollector {
            id: pollCollector

            onStreamFinished: {
                let payload;
                try {
                    payload = JSON.parse(pollCollector.text);
                } catch (e) {
                    return;
                }

                root.monotonicNow = payload.uptime;
                root.dnd = payload.paused === true;

                const raw = (payload.history && payload.history.data && payload.history.data[0]) || [];
                root.notifications = raw.map(n => ({
                    id: n.id.data,
                    appname: n.appname.data,
                    summary: root.cleanText(n.summary.data),
                    body: root.cleanBody(n.body.data),
                    icon: n.icon_path.data,
                    urgency: n.urgency.data,
                    timestamp: n.timestamp.data / 1000000
                }));
            }
        }
    }

    // Kaydedilmiş "son görülen" id'yi geri yükle (quickshell yeniden başlasa da sayaç sıfırlanmasın)
    Process {
        id: seenProc

        running: true
        command: ["sh", "-c", "cat \"" + root.seenFile + "\" 2>/dev/null || echo 0"]

        stdout: StdioCollector {
            id: seenCollector

            onStreamFinished: {
                const value = parseInt(seenCollector.text.trim());
                if (!isNaN(value) && value > root.lastSeenId)
                    root.lastSeenId = value;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Bir eylemden sonra dunst'ın durumu işlemesini kısaca bekleyip senkronla
    Timer {
        id: syncTimer

        interval: 150
        repeat: false
        onTriggered: root.refresh()
    }
}
