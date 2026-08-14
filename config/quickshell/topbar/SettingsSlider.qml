import QtQuick

// One slider row, bound to a numeric key in settings.json.
//
// **Drag shows, release applies.** Every write costs a `hyprctl reload` (the
// value lives in animations.lua / decorations.lua, which only run then), so
// pushing on every pixel of a drag would reload the compositor dozens of times
// for one gesture. The fill follows the handle immediately through
// root.store.preview(); commit() is what the release handler calls.
//
// A row whose toggle is off is dimmed and inert rather than hidden: the value
// is still what it will be when the toggle comes back on, and a row that
// disappears makes the list jump.
Rectangle {
    id: root

    property string label: ""
    property string settingKey: ""

    /// Where the value lives. Anything exposing `ranges`, `number(key)`,
    /// `preview(key, v)` and `commit(key, v)` works — the compositor settings
    /// and the bar's own settings are two different files with the same shape.
    property var store: SettingsService
    /// Rendered on the right. Bound against `value`, so callers format their
    /// own units without this file knowing about them.
    property var display: ""

    readonly property var range: root.store.ranges[root.settingKey]
    readonly property real value: dragging ? dragValue : root.store.number(root.settingKey)

    // Keyboard navigation: the window walks its rows by these.
    readonly property bool selectable: true
    readonly property string kind: "slider"
    property int rowIndex: -1

    property bool selected: false

    property bool dragging: false
    property real dragValue: 0

    height: 46
    radius: Theme.radius
    color: root.selected ? Theme.selected : "transparent"
    opacity: root.enabled ? 1 : 0.4

    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    /// Keyboard nudge, one step per press. Writes straight through — a key
    /// press is a discrete act, so there is no drag to coalesce.
    function nudge(direction) {
        if (!root.range || !root.enabled)
            return
        const next = Math.max(root.range.min,
            Math.min(root.range.max, root.value + direction * root.range.step))
        root.store.commit(root.settingKey, next)
    }

    Text {
        id: name

        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 6
        text: root.label
        color: Theme.text
        font.pixelSize: 13
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: name.verticalCenter
        text: root.display
        color: root.dragging ? Theme.mauve : Theme.overlay0
        font.family: Theme.fontMono
        font.pixelSize: 11
    }

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        height: 6
        radius: Theme.radiusUpTo(6)
        color: Theme.surface1

        readonly property real fraction: {
            if (!root.range)
                return 0
            const span = root.range.max - root.range.min
            if (span <= 0)
                return 0
            return Math.max(0, Math.min(1, (root.value - root.range.min) / span))
        }

        Rectangle {
            width: track.width * track.fraction
            height: parent.height
            radius: parent.radius
            color: Theme.mauve
        }

        Rectangle {
            id: handle

            width: 14
            height: 14
            radius: Theme.radiusUpTo(14)
            anchors.verticalCenter: parent.verticalCenter
            // Inset by half the handle so it never hangs off either end.
            x: (track.width - width) * track.fraction
            color: Theme.mauve
            border.color: Theme.textOn(Theme.mauve)
            border.width: root.dragging ? 2 : 0
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function valueAt(mouseX) {
            const span = root.range.max - root.range.min
            const local = Math.max(0, Math.min(1, (mouseX - track.x) / track.width))
            const raw = root.range.min + local * span
            // Snapped to the step so the number under the handle is a value
            // someone would type, not 0.9137254901960784.
            const steps = Math.round((raw - root.range.min) / root.range.step)
            return root.range.min + steps * root.range.step
        }

        onPressed: mouse => {
            if (!root.range)
                return
            root.dragValue = area.valueAt(mouse.x)
            root.dragging = true
            root.store.preview(root.settingKey, root.dragValue)
        }

        onPositionChanged: mouse => {
            if (!root.dragging)
                return
            root.dragValue = area.valueAt(mouse.x)
            root.store.preview(root.settingKey, root.dragValue)
        }

        onReleased: {
            if (!root.dragging)
                return
            root.dragging = false
            root.store.commit(root.settingKey, root.dragValue)
        }
    }
}
