# Sprig 0.3.2 — side attachments and rope controls

21 October 2026. Native macOS / Apple Silicon.

## Changes

- Rope anchors use the midpoint of the facing horizontal or vertical side. Outward lead controls fix the tangent at the edge, keeping the apparent attachment at the midpoint while gravity acts on the free rope.
- In Connect mode, clicking the visible rope selects it independently of note selection. The hit region follows the curve with a 20-point stroke, rather than its bounding box.
- Selected ropes display an animated Liquid Glass toolbar: palette icon with six colour swatches, Rigidify/Loosen with line/curve icon, and Delete with trash icon. Selection increases the rope emphasis.
- Rigidify interpolates the curve into a straight line. Loosen returns to the hanging simulation. Colour, selection, toolbar appearance and deletion animate; system Reduce Motion remains respected.
- Colour and rigidity persist in connection records and survive backup export/import. Old connection records without these fields load as sage/slack. Undo/Redo retains styles; deletion clears the selected rope. Changing boards or selecting a note clears rope selection.

## Verification

37 native tests passed, including side midpoints and lead directions, legacy decoding, style round-trip/import, selection, save/reopen, style-preserving deletion Undo and board switching. Existing editing, camera, persistence and rope simulation tests also passed.

Native UI checks used a separate QA bundle identifier and a disposable two-note workspace. Verified selecting the actual curved rope, toolbar appearance, blue colour change, Rigidify producing a straight line, Delete removing the rope and toolbar, and Undo restoring it. The saved workspace retained blue/rigid style after quitting; reopening displayed the saved blue straight connection, and Loosen restored the smooth hanging rope.

Debug and Release builds succeeded. The extracted 0.3.2 app passed strict signature verification; its ZIP checksum passed. User study notes were not modified. Prior releases remain intact. The web editor is unchanged, so its previously passing browser scenarios were not rerun.

The rope remains a visual simulation and does not pull connected notes or enforce a fixed distance. It may pass behind other notes. This is a local ad-hoc-signed build; no notarisation or GitHub publication was performed.
