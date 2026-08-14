import QtQuick

// Bildirimlerdeki ilerleme çubuğu görünümünde değer seçici: segmentlere
// bölünmüş bir bar, seçili segment ayrı renkte. Sürükle, tıkla veya tekerlek.
Item {
    id: root

    property string label: ""
    property int from: 0
    property int to: 23
    property int value: 0

    property color accent: Theme.mauve
    property color activeColor: Theme.yellow

    readonly property int count: root.to - root.from + 1

    implicitHeight: 44

    function setFromX(x) {
        const w = track.width
        if (w <= 0)
            return
        const clamped = Math.max(0, Math.min(0.9999, x / w))
        root.value = root.from + Math.floor(clamped * root.count)
    }

    Text {
        id: labelText

        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        color: Theme.overlay0
        font.pixelSize: 10
        font.bold: true
    }

    Text {
        id: valueText

        anchors.right: parent.right
        anchors.verticalCenter: labelText.verticalCenter
        text: (root.value < 10 ? "0" : "") + root.value
        color: root.activeColor
        font.pixelSize: 13
        font.bold: true
        font.family: Theme.fontMono
        font.weight: Theme.fontWeight
    }

    Item {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: labelText.bottom
        anchors.topMargin: 10
        height: 16

        Row {
            id: segments

            anchors.fill: parent
            spacing: 1

            Repeater {
                model: root.count

                delegate: Item {
                    id: segment

                    required property int index

                    readonly property bool isActive: segment.index === root.value - root.from
                    readonly property bool isFilled: segment.index < root.value - root.from

                    width: (track.width - (root.count - 1) * segments.spacing) / root.count
                    height: track.height

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: segment.isActive ? 16 : 8
                        radius: Theme.radiusUpTo(8)
                        color: {
                            if (segment.isActive)
                                return root.activeColor
                            if (segment.isFilled)
                                return root.accent
                            return Theme.surface0
                        }

                        Behavior on height {
                            NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 90 }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: mouse => root.setFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    root.setFromX(mouse.x)
            }
            onWheel: wheel => {
                const delta = wheel.angleDelta.y > 0 ? 1 : -1
                root.value = Math.max(root.from, Math.min(root.to, root.value + delta))
            }
        }
    }
}
