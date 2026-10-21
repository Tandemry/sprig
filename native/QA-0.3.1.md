# Sprig 0.3.1

21 October 2026. Native macOS Apple Silicon build.

- Made the complete 94 × 48 navigation label rectangular and clickable, including blank space, text and icon. Verified actual coordinate clicks on the blank corner of Boards and the Library label.
- Removed the Markdown / Live editing / Saved locally editor row. Optional full-source editing remains in the note actions menu. Verified the removed row and retained menu in the native app.
- Replaced edge-to-edge straight connections with slack particle ropes pinned beneath the centre of each note. Gravity, adaptive slack, constrained segment lengths and damped inertia produce hanging curves that swing after movement. Curves and hit regions follow the same simulated points. Notes draw above the rope, hiding its ends.
- Added transient drag coordinates so ropes follow their endpoints during a drag. These values do not change saved note content or timestamps. They clear on drag completion/cancellation and board navigation.
- Rope updates stop after settling or four seconds; idle boards do not redraw continuously. Reduce Motion uses an immediately settled static curve.

## Verification

34 native tests passed. Rope coverage checks centre anchors, pinned ends, gravitational sag, movement/inertia, damping, finite positions under rapid movement and coincident endpoints. Existing note/editing/data tests also pass.

Debug and Release builds succeeded. Native UI checks used a disposable demo workspace and separate QA bundle identifier. Verified full-area navigation clicks, editor row removal, source menu availability, a hanging rope behind cards, and a connected note drag followed by rope settling. Also checked the app-only Reduce Motion override displays an immediately settled rope.

Production notes were not modified. Prior versions remain available. This is a local ad-hoc-signed build, not a notarised or published GitHub release. The existing seven editor/browser scenarios were not rerun because this update changes no web editor or renderer code; their 0.3.0 results remain documented separately.

The rope is a visual simulation: it does not pull other notes around, collide with cards, or constrain how far apart notes can be dragged. Slack adapts as notes separate.
