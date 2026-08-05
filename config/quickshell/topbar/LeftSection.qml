import QtQuick
import QtQuick.Layouts
import Quickshell.Io

RowLayout {
    id: root
    spacing: 10

    // Tarihe sol tıklayınca takvim açılıyor
    Rectangle {
        id: dateButton

        implicitWidth: dateText.implicitWidth + 10
        implicitHeight: 22
        radius: 0
        color: dateArea.containsMouse || calendarWindow.shown ? Theme.surface0 : "transparent"

        Text {
            id: dateText
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
        }

        MouseArea {
            id: dateArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarWindow.toggle()
        }
    }

    CalendarWindow {
        id: calendarWindow
    }

    Rectangle {
        width: 1
        height: 14
        color: Theme.surface1
    }

    Text {
        id: timeText
        color: Theme.text
        font.pixelSize: 13
        font.bold: true
        font.family: "JetBrainsMono Nerd Font"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date()
            dateText.text = Qt.formatDateTime(now, "dddd d MMMM yyyy")
            timeText.text = Qt.formatDateTime(now, "HH:mm")
        }
    }

    Rectangle {
        width: 1
        height: 14
        color: Theme.surface1
    }

    Text {
        id: focusedAppText
        color: Theme.text
        font.pixelSize: 13
        font.family: "JetBrainsMono Nerd Font"
        text: ""

        // Odakta uygulama yoksa metni de boşluğunu da tamamen kaldır
        visible: text.length > 0

        Process {
            id: activeWindowProc
            command: ["hyprctl", "-j", "activewindow"]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        let win = JSON.parse(text)
                        focusedAppText.text = win.class && win.class.length > 0 ? win.class : ""
                    } catch (e) {
                        focusedAppText.text = ""
                    }
                }
            }
        }

        // Odaklı pencere adı. Performans modunda saniyede 2 kez hyprctl
        // açmanın anlamı yok, aralık uzuyor (bkz. PerfMode).
        Timer {
            interval: PerfMode.every(500)
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: activeWindowProc.running = true
        }
    }

    // Uygulama adının sağındaki ayırıcı — ad boşken görünmesin
    Rectangle {
        width: 1
        height: 14
        color: Theme.surface1
        visible: focusedAppText.visible
    }

    Rectangle {
        id: catContainer
        width: 40
        height: 30
        color: "transparent"
        property var icons: ["", "", "", "", ""]
        property int currentIconIndex: 0
        Text {
            id: catText
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 30
            font.family: "runcat"
            text: catContainer.icons[catContainer.currentIconIndex]
        }
        // Koşan kedi. Performans modunda yavaşlıyor ama durmuyor —
        // durursa bar donmuş gibi görünüyor.
        Timer {
            interval: PerfMode.every(100)
            running: true
            repeat: true
            onTriggered: {
                catContainer.currentIconIndex = (catContainer.currentIconIndex + 1) % catContainer.icons.length
            }
        }
    }
}
