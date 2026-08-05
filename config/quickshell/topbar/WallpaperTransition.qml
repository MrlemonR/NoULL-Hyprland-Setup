import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Duvar kağıdı değişim animasyonu.
//
// Bottom katmanında duruyor: hyprpaper'ın (background) üstünde ama normal
// pencerelerin altında, böylece sadece masaüstü kısmı animasyonlu değişiyor.
// Girdi bölgesi boş, tıklamalar altına geçiyor.
//
// Akış: yeni resmi göster -> rastgele bir efektle aç -> hyprpaper'a uygula
// -> katmanı gizle. Sıra bu olduğu için geçişte boşluk/flaş görünmüyor.
PanelWindow {
    id: root

    // Uygulanacak resmin yolu
    property string pendingPath: ""

    // FileView açılışta da yükleniyor; istenmeden animasyon oynamasın
    property bool playRequested: false

    // 0 = daire, 1 = bloklar (pikselleşme), 2 = çapraz geçiş
    property int effect: 0

    // DİKKAT: pencere görünmezken width/height 100x100 raporluyor, bu yüzden
    // animasyon geometrisini ekrandan alıyoruz.
    readonly property real screenW: root.screen ? root.screen.width : root.width
    readonly property real screenH: root.screen ? root.screen.height : root.height

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-wallpaper"
    readonly property string handoffPath: Quickshell.env("HOME") + "/.cache/qs-wallpaper-pending"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    // DİKKAT: exclusiveZone'a değer atamak exclusionMode'u Normal'a çeviriyor;
    // pencere bar'ın 30px exclusive zone'u kadar aşağı iniyor ve tam ekran
    // olmuyordu. Sadece Ignore bırakıyoruz.
    exclusionMode: ExclusionMode.Ignore
    visible: false

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-wallpaper-fx"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Tıklamalar masaüstüne geçsin
    mask: Region {}

    function play(path) {
        if (!path || path.length === 0)
            return

        root.pendingPath = path
        root.effect = Math.floor(Math.random() * 3)
        newImage.source = "file://" + path

        // Resim yüklenmeden animasyona başlamak boş bir açılma gösteriyor
        if (newImage.status === Image.Ready)
            root.start()
    }

    function start() {
        root.visible = true
        circleAnim.stop()
        blocksAnim.stop()
        fadeAnim.stop()

        // Başlangıç durumları
        revealRadius = 0
        blocksProgress = 0
        crossOpacity = 0

        if (root.effect === 0)
            circleAnim.restart()
        else if (root.effect === 1)
            blocksAnim.restart()
        else
            fadeAnim.restart()
    }

    // Animasyon bitince gerçek duvar kağıdını uygula, sonra katmanı kaldır
    function finish() {
        applyProc.command = [root.script, "set", root.pendingPath]
        applyProc.running = true
    }

    property real revealRadius: 0
    property real blocksProgress: 0
    property real crossOpacity: 0

    IpcHandler {
        target: "wallpaperFx"

        // Yol ~/.cache/qs-wallpaper-pending dosyasından okunuyor
        // (quickshell 0.3.0 ipc call argüman almıyor)
        function play(): void {
            // DİKKAT: reload() eşzamansız; hemen text() okumak önceki değeri
            // veriyordu. Yolu FileView.onLoaded içinde alıyoruz.
            root.playRequested = true
            handoffFile.reload()
        }
    }

    FileView {
        id: handoffFile

        path: root.handoffPath
        blockLoading: false
        printErrors: false

        onLoaded: {
            if (!root.playRequested)
                return
            root.playRequested = false
            root.play(handoffFile.text().trim())
        }
    }

    Process {
        id: applyProc

        running: false
        onExited: hideTimer.restart()
    }

    // hyprpaper resmi yükleyip çizsin, sonra katmanı gizle
    Timer {
        id: hideTimer

        interval: 260
        repeat: false
        onTriggered: {
            root.visible = false
            root.revealRadius = 0
            root.blocksProgress = 0
            root.crossOpacity = 0
        }
    }

    // ---------------- Yeni duvar kağıdı ----------------
    Image {
        id: newImage

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false

        onStatusChanged: {
            // play() çağrıldıysa ve resim şimdi hazırsa animasyonu başlat
            if (status === Image.Ready && root.pendingPath.length > 0 && !root.visible)
                root.start()
        }
    }

    // ---------------- Efekt 0: daire ----------------
    //
    // Qt5Compat.GraphicalEffects (OpacityMask) bu quickshell örneğinde
    // yüklenmiyor — import edildiğinde bileşen sessizce kaydolmuyor.
    // Bu yüzden daireyi yatay şeritlerle çiziyoruz: her şerit dairenin o
    // yükseklikteki genişliği kadar açılıyor ve resmin ilgili parçasını
    // kırpılmış olarak gösteriyor.
    Item {
        id: circleLayer

        readonly property int bands: 80
        readonly property real bandHeight: root.screenH / bands

        anchors.fill: parent
        visible: root.visible && root.effect === 0

        Repeater {
            model: circleLayer.bands

            delegate: Item {
                id: band

                required property int index

                // Şeridin merkezinin daire merkezine dikey uzaklığı
                readonly property real dy: Math.abs(
                    (band.index + 0.5) * circleLayer.bandHeight - root.screenH / 2)

                readonly property real halfWidth: {
                    const r = root.revealRadius
                    if (r <= band.dy)
                        return 0
                    return Math.sqrt(r * r - band.dy * band.dy)
                }

                x: root.screenW / 2 - band.halfWidth
                y: band.index * circleLayer.bandHeight
                width: band.halfWidth * 2
                // Şeritler arasında ince boşluk kalmasın
                height: circleLayer.bandHeight + 1
                clip: true
                visible: width > 0

                Image {
                    x: -band.x
                    y: -band.y
                    width: root.screenW
                    height: root.screenH
                    source: newImage.source
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    cache: true
                }
            }
        }
    }

    NumberAnimation {
        id: circleAnim

        target: root
        property: "revealRadius"
        from: 0
        // Köşelere ulaşmak için ekran köşegeninin yarısı
        to: Math.sqrt(root.screenW * root.screenW + root.screenH * root.screenH) / 2
        duration: 700
        easing.type: Easing.InOutCubic
        onFinished: root.finish()
    }

    // ---------------- Efekt 1: bloklar (pikselleşme) ----------------
    Item {
        id: blocksLayer

        readonly property int columns: 26
        readonly property int rows: 15

        anchors.fill: parent
        visible: root.visible && root.effect === 1

        Image {
            anchors.fill: parent
            source: newImage.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
        }

        // Üstteki opak karolar rastgele sırayla soluyor
        Grid {
            anchors.fill: parent
            columns: blocksLayer.columns
            rows: blocksLayer.rows

            Repeater {
                model: blocksLayer.columns * blocksLayer.rows

                delegate: Rectangle {
                    id: tile

                    required property int index

                    // Her karoya sabit bir rastgele eşik ver
                    readonly property real threshold: Math.random()

                    width: root.screenW / blocksLayer.columns
                    height: root.screenH / blocksLayer.rows
                    color: Theme.crust
                    opacity: root.blocksProgress > tile.threshold ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation { duration: 180 }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: blocksAnim

        target: root
        property: "blocksProgress"
        from: 0
        to: 1.05
        duration: 750
        easing.type: Easing.Linear
        onFinished: root.finish()
    }

    // ---------------- Efekt 2: çapraz geçiş ----------------
    Image {
        anchors.fill: parent
        source: newImage.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: root.visible && root.effect === 2
        opacity: root.crossOpacity
    }

    NumberAnimation {
        id: fadeAnim

        target: root
        property: "crossOpacity"
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.InOutQuad
        onFinished: root.finish()
    }
}
