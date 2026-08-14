import QtQuick

// The Aero specular highlight: a bright band across the top of a surface that
// falls off sharply at the midline, the way a curved piece of glass catches a
// light source above it. Draw it over any Rectangle:
//
//     Rectangle {
//         id: panel
//         radius: Theme.radiusPanel
//         GlossOverlay { anchors.fill: parent; radius: panel.radius }
//     }
//
// It is inert on the standard themes — `Theme.gloss` is 0 for anything without
// a `style` block in palettes.json, and `visible` follows it — so this can be
// dropped into shared components without changing how they look today.
//
// DİKKAT: no `Qt5Compat.GraphicalEffects` here, and none anywhere else in this
// config. That import makes the whole component fail to register with no error
// at all (gotcha #3), which is also why the highlight is a plain Gradient
// rather than a real specular shader.
Rectangle {
    id: root

    /// 0 = invisible, 1 = full sheen. Defaults to the active theme's value.
    property real strength: Theme.gloss

    /// Where the highlight dies. Lower = a tighter band at the very top.
    property real midline: 0.5

    /// Also lift the bottom edge slightly, the way glass picks up bounce
    /// light. Off for thin surfaces (a 30px bar) where it just muddies.
    property bool bounce: true

    /// Aero's other half: a tint that climbs from the bottom edge upward.
    /// Win7's glass was never a flat wash — the specular sweep across the top
    /// is only half of it, and without this rising tint a translucent panel
    /// reads as "faded", not as a pane with depth. Follows the theme's own
    /// accent so the glass takes the palette's colour rather than a fixed
    /// blue.
    property color tint: Theme.mauve
    property real tintStrength: Theme.glass ? 0.22 : 0

    color: "transparent"
    visible: root.strength > 0 || root.tintStrength > 0
    // Purely decorative: it must never eat a click meant for the surface.
    enabled: false

    // Two stacked passes, because one Gradient cannot both rise from the
    // bottom and break sharply at the midline. The parent's own gradient (the
    // specular sweep) paints first and this child paints over it — which is
    // harmless here, since the sweep is strongest at the top and already zero
    // by the midline, exactly where the rising tint starts to show.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.tintStrength > 0

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0) }
            GradientStop { position: 0.55; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.35 * root.tintStrength) }
            GradientStop { position: 1.0; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tintStrength) }
        }
    }

    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.62 * root.strength) }
        GradientStop { position: root.midline * 0.82; color: Qt.rgba(1, 1, 1, 0.16 * root.strength) }
        // The hard step at the midline is the point — a smooth fade reads as a
        // washed-out surface, the abrupt one reads as glass.
        GradientStop { position: root.midline; color: Qt.rgba(1, 1, 1, 0.03 * root.strength) }
        GradientStop { position: Math.min(1, root.midline + 0.001); color: Qt.rgba(1, 1, 1, 0) }
        GradientStop { position: 1.0; color: root.bounce ? Qt.rgba(1, 1, 1, 0.10 * root.strength) : Qt.rgba(1, 1, 1, 0) }
    }

    // A one-pixel bright rim along the top edge. Cheap, and it is what makes
    // the corner radius read as a bevel instead of a rounded flat rectangle.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.radius > 0 ? root.radius * 0.5 : 0
        height: 1
        color: Qt.rgba(1, 1, 1, 0.75 * root.strength)
        visible: root.strength > 0
    }
}
