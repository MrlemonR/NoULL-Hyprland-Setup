pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Takvim notları ve hatırlatmaları.
// Notlar diske JSON olarak yazılıyor, hatırlatma zamanı gelince dunst'a
// tıklanana kadar kapanmayan bir bildirim gönderiliyor.
Singleton {
    id: root

    // { id, date: "YYYY-MM-DD", hour: 0-23, minute: 0-59, text, images: [], fired: bool }
    property var notes: []

    readonly property string reminderScript: Quickshell.env("HOME") + "/.local/bin/qs-note-reminder"

    readonly property string notesPath: Quickshell.env("HOME") + "/.local/share/quickshell/calendar-notes.json"

    // Quickshell kapalıyken geçmiş bir hatırlatma varsa, çok eskiyse sessizce
    // geçilmiş sayıyoruz; bu süre içindekiler açılışta bildirim olarak gelir.
    readonly property int lateToleranceMs: 12 * 60 * 60 * 1000

    // ---------------- Tarih yardımcıları ----------------

    function dateKey(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    function keyToDate(key) {
        const parts = key.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    function noteTime(note) {
        const d = keyToDate(note.date);
        d.setHours(note.hour, note.minute || 0, 0, 0);
        return d.getTime();
    }

    function noteClock(note) {
        const h = note.hour;
        const m = note.minute || 0;
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    // ---------------- Sorgular ----------------

    function notesForDate(key) {
        return root.notes
            .filter(n => n.date === key)
            .sort((a, b) => (a.hour - b.hour) || ((a.minute || 0) - (b.minute || 0)));
    }

    function noteById(id) {
        for (let i = 0; i < root.notes.length; i++) {
            if (root.notes[i].id === id)
                return root.notes[i];
        }
        return null;
    }

    function countForDate(key) {
        let n = 0;
        for (let i = 0; i < root.notes.length; i++) {
            if (root.notes[i].date === key)
                n++;
        }
        return n;
    }

    // ---------------- Değiştirme ----------------

    function addNote(key, hour, minute, text, images) {
        const trimmed = String(text || "").trim();
        const pictures = images || [];
        if (trimmed.length === 0 && pictures.length === 0)
            return;

        const note = {
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 100000),
            date: key,
            hour: hour,
            minute: minute,
            text: trimmed,
            images: pictures,
            // Geçmiş bir saate not eklenirse hemen bildirim yağmasın
            fired: root.noteTime({ date: key, hour: hour, minute: minute }) <= Date.now()
        };

        root.notes = root.notes.concat([note]);
        root.save();
    }

    function removeNote(id) {
        root.notes = root.notes.filter(n => n.id !== id);
        root.save();
    }

    function removeDate(key) {
        root.notes = root.notes.filter(n => n.date !== key);
        root.save();
    }

    // ---------------- Toplu silme (sağ tık) ----------------

    function monthPrefix(year, month) {
        return year + "-" + (month + 1 < 10 ? "0" : "") + (month + 1);
    }

    function countForMonth(year, month) {
        const prefix = root.monthPrefix(year, month);
        return root.notes.filter(n => n.date.startsWith(prefix)).length;
    }

    function countForYear(year) {
        const prefix = String(year) + "-";
        return root.notes.filter(n => n.date.startsWith(prefix)).length;
    }

    function removeMonth(year, month) {
        const prefix = root.monthPrefix(year, month);
        root.notes = root.notes.filter(n => !n.date.startsWith(prefix));
        root.save();
    }

    function removeYear(year) {
        const prefix = String(year) + "-";
        root.notes = root.notes.filter(n => !n.date.startsWith(prefix));
        root.save();
    }

    // ---------------- Kalıcılık ----------------

    function save() {
        notesFile.setText(JSON.stringify({ notes: root.notes }, null, 2));
    }

    FileView {
        id: notesFile

        path: root.notesPath
        // preload olmadan FileView tembel davranıp dosyayı hiç okumuyor
        preload: true
        watchChanges: false
        printErrors: false

        onLoaded: {
            try {
                const payload = JSON.parse(notesFile.text());
                if (payload && Array.isArray(payload.notes))
                    root.notes = payload.notes;
            } catch (e) {
                console.warn("Takvim notları okunamadı:", e);
            }
            reminderTimer.triggered();
        }

        onLoadFailed: {
            // Dosya henüz yok — ilk not kaydedildiğinde oluşacak
            root.notes = [];
        }
    }

    // ---------------- Hatırlatmalar ----------------

    // Bildirimi script gönderiyor: not defteri ikonlu, tıklanana kadar kalan ve
    // "Önizle" eylemiyle not önizleme penceresini açan bir bildirim.
    function fire(note) {
        const when = Qt.formatDateTime(new Date(root.noteTime(note)), "d MMMM, HH:mm");
        Quickshell.execDetached([
            root.reminderScript,
            note.id,
            when,
            note.text,
            String((note.images || []).length)
        ]);
    }

    Timer {
        id: reminderTimer

        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const now = Date.now();
            let changed = false;

            const updated = root.notes.map(note => {
                if (note.fired)
                    return note;

                const due = root.noteTime(note);
                if (due > now)
                    return note;

                // Çok geç kalınmış hatırlatmaları sessizce geçmiş say
                if (now - due <= root.lateToleranceMs)
                    root.fire(note);

                changed = true;
                return Object.assign({}, note, { fired: true });
            });

            if (changed) {
                root.notes = updated;
                root.save();
            }
        }
    }
}
