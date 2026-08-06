import QtQuick
import Quickshell
import Quickshell.Services.Mpris

PopupWindow {
    id: root

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
        radius: 0
        color: Theme.base
        border.color: Theme.surface0
        border.width: 1

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
                    radius: 0
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
                        radius: 0
                        color: prevArea.containsMouse ? Theme.blue : Theme.text

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/next.svg"
                            rotation: 180
                            fillMode: Image.PreserveAspectFit
                            smooth: true
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
                        radius: 0
                        color: playArea.containsMouse ? Theme.blue : Theme.text

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: root.player && root.player.isPlaying ? root.pauseIconPath : root.playIconPath
                            fillMode: Image.PreserveAspectFit
                            smooth: true
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
                        radius: 0
                        color: nextArea.containsMouse ? Theme.blue : Theme.text

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/next.svg"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
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
            Item {
                id: sliderArea

                property real ratio: (root.player && root.player.length > 0) ? Math.min(1, Math.max(0, root.player.position / root.player.length)) : 0
                property int barLength: 40
                property int filledCount: Math.round(barLength * ratio)
                property int emptyCount: barLength - filledCount
                property string progressBar: "█".repeat(filledCount) + "░".repeat(emptyCount)

                anchors.top: mainRow.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                height: 16

                Text {
                    id: progressText

                    anchors.centerIn: parent
                    text: sliderArea.progressBar
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.weight: Theme.fontWeight
                    font.pixelSize: 10
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    function seekTo(mouseX) {
                        let barWidth = progressText.paintedWidth;
                        let barStart = (parent.width - barWidth) / 2;
                        // Mouse'un gerçek bar üzerindeki konumu
                        let positionInBar = mouseX - barStart;
                        // 0 - 1 arasına sıkıştır
                        let ratio = Math.max(0, Math.min(1, positionInBar / barWidth));
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
