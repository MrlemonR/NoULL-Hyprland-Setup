import QtQuick

// The chip every button in the shell sits on.
//
// Pulled out of SettingsCategory, which is where the look was first arrived at:
// a **resting fill** rather than a transparent rectangle, the theme's radius,
// a sheen that comes up under the cursor, and a bright top rim. The resting
// fill is the part that matters — a button that only appears on hover reads as
// a hit-box, and the moment the surface behind it went to glass there was
// nothing to tell you a button was there at all.
//
// Everything is inert on the standard themes: `Theme.radius` is 0, `Theme.gloss`
// is 0, so this collapses to exactly the flat rectangle these buttons already
// were. Only a theme carrying a `style` block, or Aero Glass, changes anything.
//
//     ButtonSurface {
//         hovered: area.containsMouse
//         active: thisIsTheCurrentTab
//         MouseArea { id: area; anchors.fill: parent; hoverEnabled: true }
//     }
Rectangle {
    id: root

    /// Cursor is over it. The caller owns the MouseArea, because half of these
    /// need its clicks and positions for other things too.
    property bool hovered: false

    /// Selected / current / on. Filled with the accent rather than the surface.
    property bool active: false

    /// Keyboard cursor, where there is one.
    property bool selected: false

    /// Fill when idle. `"transparent"` for buttons that genuinely should
    /// disappear into their surroundings — a bar section, say, where a chip per
    /// widget would turn the bar into a row of boxes.
    property color restingColor: Theme.hover

    /// Fill when active. Text drawn on top should use `Theme.textOn(accent)`.
    property color accentColor: Theme.mauve

    radius: Theme.radius

    color: {
        if (root.active)
            return root.accentColor
        if (root.hovered)
            return Theme.surface0
        if (root.selected)
            return Theme.selected
        return root.restingColor
    }

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    // Under the cursor only. A sheen on every button at rest turns a panel into
    // a wall of glass and stops the highlight meaning anything.
    GlossOverlay {
        anchors.fill: parent
        radius: root.radius
        strength: (root.hovered || root.active || root.selected) ? Theme.gloss : 0
        bounce: false

        Behavior on strength {
            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
        }
    }
}
