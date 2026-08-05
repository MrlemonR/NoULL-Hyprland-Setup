pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Performans modu (Super+Shift+P -> qs-mode) bar tarafında.
//
// Bar bilerek açık kalıyor — kaynak kullanımı oradan izleniyor — ama tam
// hızda yoklamaya devam etmesi için bir sebep yok. Normalde saniyede ~4-5
// süreç açılıyor (hyprctl activewindow 2/sn, sistem istatistikleri 5 süreç
// /2sn — ddcutil dahil, dunstctl, hyprctl clients). Performans modunda bu
// aralıklar `factor` katına çıkıyor.
//
// Durum IPC ile geliyor (qs-mode çağırıyor); shell yeniden başlarsa bayrak
// dosyasından bir kez okunuyor.
//
//   qs -c topbar ipc call mode performance | normal | status
Singleton {
    id: root

    property bool active: false

    readonly property int factor: root.active ? 4 : 1

    readonly property string flagPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/qs-mode.performance"

    // Yoklama aralığını moda göre uzat. Saatte KULLANILMIYOR — o her saniye
    // güncellenmeye devam etmeli, yoksa bar durmuş gibi görünüyor.
    function every(ms) {
        return ms * root.factor
    }

    IpcHandler {
        target: "mode"

        function performance(): void {
            root.active = true
        }

        function normal(): void {
            root.active = false
        }

        function status(): string {
            return root.active ? "performance" : "normal"
        }
    }

    // Bar yeniden yüklendiğinde mod bilgisi IPC ile gelmeyeceği için
    // bayrak dosyasına bakıyoruz
    Process {
        id: probe

        running: true
        command: ["sh", "-c", "[ -e \"" + root.flagPath + "\" ] && echo performance || echo normal"]

        stdout: StdioCollector {
            id: probeCollector

            onStreamFinished: root.active = probeCollector.text.trim() === "performance"
        }
    }
}
