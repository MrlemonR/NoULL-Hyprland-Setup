import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
    id: root
    spacing: 10

    // Tarihe sol tıklayınca takvim açılıyor
    Rectangle {
        id: dateButton

        // Hidden from the control centre's Topbar page. A RowLayout collapses
        // an invisible child on its own; the separators around it are the part
        // that needs saying out loud.
        visible: BarSettings.enabled("date")

        implicitWidth: dateText.implicitWidth + 10
        implicitHeight: 22
        radius: Theme.radius
        color: dateArea.containsMouse || calendarWindow.shown ? Theme.surface0 : "transparent"

        Text {
            id: dateText
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 13
            font.family: Theme.fontMono
            font.weight: Theme.fontWeight
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
        visible: dateButton.visible && timeText.visible
    }

    Text {
        id: timeText
        visible: BarSettings.enabled("clock")
        color: Theme.text
        font.pixelSize: 13
        font.bold: true
        font.family: Theme.fontMono
        font.weight: Theme.fontWeight
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
        visible: (dateButton.visible || timeText.visible) && focusedAppText.visible
    }

    Text {
        id: focusedAppText
        color: Theme.text
        font.pixelSize: 13
        font.family: Theme.fontMono
        font.weight: Theme.fontWeight
        text: ""

        // Odakta uygulama yoksa metni de boşluğunu da tamamen kaldır
        visible: BarSettings.enabled("focusedApp") && text.length > 0

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
        // açmanın anlamı yok, aralık uzuyor (bkz. PerfMode). Switched off in
        // the Topbar page it stops entirely — two processes a second for
        // something nobody is looking at.
        Timer {
            interval: PerfMode.every(500)
            running: BarSettings.enabled("focusedApp")
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

    // The cat doubles as the control centre handle — click it for the panel
    // below (see ControlCenterPopup). It keeps running either way.
    Rectangle {
        id: catContainer
        width: 40
        height: 30
        color: catArea.containsMouse || controlCenter.shown ? Theme.surface0 : "transparent"
        property var icons: ["", "", "", "", ""]
        property int currentIconIndex: 0
        Text {
            id: catText
            anchors.centerIn: parent
            color: controlCenter.shown ? Theme.mauve : Theme.text
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

        MouseArea {
            id: catArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: controlCenter.toggle()
        }
    }

    ControlCenterPopup {
        id: controlCenter

        // The bar's inner Item carries a 12px left margin, and the cat's own x
        // moves as the focused-app name comes and goes — so the panel is told
        // where to sit rather than anchored to a fixed offset.
        anchorX: 12 + catContainer.x
    }
}
