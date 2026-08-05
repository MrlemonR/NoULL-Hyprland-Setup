import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    width: 30
    height: 30
    color: "transparent"
    
    property real fps_l: 6
    property real fps_h: 90
    property real sample_rate: 100
    property real update_interval: 1000  // ms
    property var cpuStates: ({
        "high": 90,
        "medium": 40,
        "low": 10
    })
    property string icons: "🐱🐱🐱🐱🐱🐱🐱🐱🐱🐱🐱🐱🐱🐱🐱"  // veya runcat.ttf karakterleri
    
    property int currentIconIndex: 0
    property int cpuPercent: 0
    property string cpuState: ""
    
    Text {
        id: catText
        anchors.centerIn: parent
        color: {
            if (root.cpuState === "high") return Theme.red  // red
            else if (root.cpuState === "medium") return Theme.blue  // blue
            else if (root.cpuState === "low") return Theme.green  // green
            else return Theme.text  // default
        }
        font.pixelSize: 18
        font.family: "JetBrainsMono Nerd Font"
        text: root.icons[root.currentIconIndex]
    }
    
    // CPU okuma timer
    Timer {
        id: cpuTimer
        interval: root.update_interval
        running: true
        repeat: true
        onTriggered: {
            readCPU()
        }
    }
    
    // Animation timer
    Timer {
        id: animationTimer
        running: true
        repeat: true
        onTriggered: {
            root.currentIconIndex = (root.currentIconIndex + 1) % root.icons.length
            
            // FPS hızını CPU'ya göre ayarla
            let diff = ((1 / root.fps_l - 1 / root.fps_h) / root.sample_rate) * root.cpuPercent
            let time = 1 / root.fps_l - diff
            animationTimer.interval = time * 1000  // ms'ye çevir
        }
    }
    
    function readCPU() {
        let proc = exec(["sh", "-c", "head -n1 /proc/stat | awk '{print $2+$3+$4}'"], true)
        
        // CPU state hesapla
        let states = Object.entries(root.cpuStates).sort((a, b) => a[1] - b[1])
        root.cpuState = ""
        for (let [key, value] of states) {
            if (value <= root.cpuPercent) {
                root.cpuState = key
            }
        }
    }
}
