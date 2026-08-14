import QtQuick
import Quickshell
import Quickshell.Services.Mpris

PopupWindow {
    id: root

    // The window under the panel must not paint: a PopupWindow defaults to an
    // opaque background, so a rounded Rectangle inside it sits on a square
    // fill and the corners read as sharp. Every PanelWindow here already
    // does this; the three popups were the ones that never needed it while
    // every corner was square anyway.
    color: "transparent"

    property var player: null
    // Buraya kendi SVG dosya yollarını yaz (örn. "/home/kullanici/.config/quickshell/icons/play.svg")
    property string playIconPath: "file://" + Quickshell.env("HOME") + "/.config/quickshell/play.svg"
    property string pauseIconPath: "file://" + Quickshell.env("HOME") + "/.config/quickshell/pause.svg"

    function formatTime(sec) {
        if (!sec || sec < 0 || isNaN(sec))
            return "0:00";

        let m = Math.floor(sec / 60);
        let s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    grabFocus: true
    implicitWidth: 380
    implicitHeight: 124

    // Popup açıkken ve parça çalarken slider'ı akıcı şekilde ilerlet
    Timer {
        interval: 500
        repeat: true
        running: root.visible && root.player !== null && root.player.playbackState === MprisPlaybackState.Playing
        onTriggered: {
            if (root.player) {
                root.player.positionChanged();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel

        // Aero sheen. Inert on the standard themes — Theme.gloss is 0 — and
        // declared first so it sits under the content rather than over it.
        GlossOverlay {
            anchors.fill: parent
            radius: parent.radius
            midline: 0.3
        }
        color: Theme.panelColor
        border.color: Theme.surface0
        border.width: Theme.borderWidth

        Item {
            anchors.fill: parent
            anchors.margins: 14

            // ---------------- Üst satır: kapak + başlık/sanatçı + kontroller ----------------
            Item {
                id: mainRow

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 52

                // Kapak resmi
                Rectangle {
                    id: cover

                    width: 52
                    height: 52
                    radius: Theme.radius
                    color: Theme.surface0
                    clip: true
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: source != ""
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !(root.player && root.player.trackArtUrl)
                        text: "󰝚"
                        font.family: Theme.fontMono
                        font.weight: Theme.fontWeight
                        color: Theme.overlay0
                        font.pixelSize: 22
                    }

                }

                // Kontroller (geri / duraklat-başlat / ileri) — ismin sağında, en sağa yaslı
                Row {
                    id: controls

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 28
                        height: 28
                        radius: Theme.radius
                        color: "transparent"

                        ButtonSurface {
                            anchors.fill: parent
                            radius: parent.radius
                            hovered: prevArea.containsMouse
                            restingColor: Theme.surface0
                            accentColor: Theme.blue
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            font.family: Theme.fontMono
                            font.pixelSize: 15
                            // Nerd Font glyph rather than an SVG: the icons were
                            // images with a baked-in colour, and recolouring them
                            // would need Qt5Compat.GraphicalEffects, which makes
                            // the whole component fail to register (gotcha #3).
                            // A glyph is just text, so it follows the theme.
                            color: prevArea.containsMouse ? Theme.textOn(Theme.blue) : Theme.text
                        }

                        MouseArea {
                            id: prevArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canGoPrevious) {
                                    root.player.previous();
                                }
                            }
                        }

                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: Theme.radius
                        color: "transparent"

                        ButtonSurface {
                            anchors.fill: parent
                            radius: parent.radius
                            hovered: playArea.containsMouse
                            restingColor: Theme.surface0
                            accentColor: Theme.blue
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
                            font.family: Theme.fontMono
                            font.pixelSize: 17
                            // Nerd Font glyph rather than an SVG: the icons were
                            // images with a baked-in colour, and recolouring them
                            // would need Qt5Compat.GraphicalEffects, which makes
                            // the whole component fail to register (gotcha #3).
                            // A glyph is just text, so it follows the theme.
                            color: playArea.containsMouse ? Theme.textOn(Theme.blue) : Theme.text
                        }

                        MouseArea {
                            id: playArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canTogglePlaying) {
                                    root.player.togglePlaying();
                                }
                            }
                        }

                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: Theme.radius
                        color: "transparent"

                        ButtonSurface {
                            anchors.fill: parent
                            radius: parent.radius
                            hovered: nextArea.containsMouse
                            restingColor: Theme.surface0
                            accentColor: Theme.blue
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            font.family: Theme.fontMono
                            font.pixelSize: 15
                            // Nerd Font glyph rather than an SVG: the icons were
                            // images with a baked-in colour, and recolouring them
                            // would need Qt5Compat.GraphicalEffects, which makes
                            // the whole component fail to register (gotcha #3).
                            // A glyph is just text, so it follows the theme.
                            color: nextArea.containsMouse ? Theme.textOn(Theme.blue) : Theme.text
                        }

                        MouseArea {
                            id: nextArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canGoNext) {
                                    root.player.next();
                                }
                            }
                        }

                    }

                }

                // Başlık / sanatçı — kapak ile kontroller arasında kalan alanı doldurur
                Column {
                    anchors.left: cover.right
                    anchors.leftMargin: 10
                    anchors.right: controls.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackTitle || "Unknown Track") : "Nothing playing"
                        color: Theme.text
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canTogglePlaying) {
                                    root.player.togglePlaying();
                                }
                            }
                        }

                    }

                    Text {
                        width: parent.width
                        text: root.player ? (root.player.trackArtist || "") : ""
                        color: Theme.subtext0
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                }

            }

            // ---------------- İlerleme çubuğu ----------------
            //
            // Eskiden METİN olarak çiziliyordu: "█" ve "░" gliflerini tek
            // renkte basıp dolu/boş ayrımını glif farkına bırakıyordu. Koyu
            // temada işe yarıyordu; açık palette iki glif de koyu çıkınca
            // çubuk tek düz şeride dönüştü. Artık iki dikdörtgen — renk
            // farkı temadan geliyor, glif şansına değil.
            Item {
                id: sliderArea

                readonly property real ratio: (root.player && root.player.length > 0)
                    ? Math.min(1, Math.max(0, root.player.position / root.player.length))
                    : 0

                anchors.top: mainRow.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: 16

                Rectangle {
                    id: track

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: Theme.radiusUpTo(6)
                    color: Theme.surface1

                    Rectangle {
                        width: track.width * sliderArea.ratio
                        height: parent.height
                        radius: parent.radius
                        color: Theme.mauve
                    }
                }

                MouseArea {
                    function seekTo(mouseX) {
                        // The track spans the row, so the mouse position maps
                        // straight onto it — no centring offset to undo.
                        let ratio = Math.max(0, Math.min(1, mouseX / track.width));
                        root.player.position = ratio * root.player.length;
                    }

                    anchors.fill: parent
                    enabled: root.player !== null && root.player.canSeek
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => {
                        return seekTo(mouse.x);
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            seekTo(mouse.x);

                    }
                }

            }

            // ---------------- Süre etiketleri (geçen / kalan) ----------------
            Item {
                anchors.top: sliderArea.bottom
                anchors.topMargin: 2
                anchors.left: parent.left
                anchors.right: parent.right
                height: 14

                Text {
                    anchors.left: parent.left
                    text: root.player ? root.formatTime(root.player.position) : "0:00"
                    color: Theme.subtext0
                    font.pixelSize: 11
                }

                Text {
                    anchors.right: parent.right
                    text: root.player ? "-" + root.formatTime(Math.max(0, root.player.length - root.player.position)) : "0:00"
                    color: Theme.subtext0
                    font.pixelSize: 11
                }

            }

        }

    }

}
