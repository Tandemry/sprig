# Sprig 0.3.0 — live editor and Connect corrections

21 October 2026. Apple Silicon/macOS 27.0.1. Local build only; no GitHub release was published.

## Editor

The previous editor used separate native source and read-only preview surfaces. Existing notes opened into preview, so clicking the body could not type; the embedded surface also looked like a separate box. Live editing had not been implemented in that version.

The note body now has one editable Markdown document using CodeMirror inside transparent local WebKit. Both empty and existing notes open in live mode. Headings, bold, italics, strikethrough, quotes, links and code receive live styling; Markdown markers appear at the active source. Inactive tables, code blocks, images, inline/display maths and recall sections render in place. Clicking complex blocks opens their source; task checkboxes update Markdown. The optional full-source control preserves the same selection and undo history. Toolbar commands return focus to the document.

This is an Obsidian-style editing approach, not parity with all Obsidian features or plugins.

## Connect

Nested title buttons and card tap gestures previously treated title/body clicks differently. The entire card now shares one selection/connection action. In Select mode, click to select; double-click or Edit opens editing. In Connect mode, click two distinct cards to connect them without opening the editor. Endpoints meet card edges; overlapping cards receive an outside curve. Confirmation appears after creation; repeated connections are not duplicated. Undo/Redo handles connections. Confirmation no longer overlaps the Connect instructions.

## Other corrections

- Routed native Undo/Redo to the live editor when its body has focus.
- Fixed CodeMirror’s default scroller font overriding the interface font. Full source and code remain monospaced.
- Board previews recognise heading prefixes instead of displaying literal hashes.
- Bound edits to their original note identifier: delayed editor messages cannot overwrite the next opened note. Added a regression test.
- The quit path requests the latest live source before flushing the workspace.
- Disposed editors cannot regain active command routing through delayed load callbacks.
- Kept the full-height canvas fix, existing workspace schema, Figma assets/colours and native Liquid Glass controls.

## Verification

- **31 Swift tests passed**, including live-mode, Connect, endpoint and delayed-edit regressions.
- **Seven browser scenarios passed in both Chromium and WebKit (14 executions)**: blank typing/live styling; toolbar/source/undo/redo; tables/tasks/maths; Unicode and script safety; display maths/recall/code; interface font and source editing; offline preview.
- Native checks used a separate QA bundle identifier and disposable demo workspace. Verified new-note typing, live headings/bold/italic, toolbar formatting, native Undo, source mode, whole-card selection, two note-body clicks creating a visible connection, connections between overlapping duplicate cards, and confirmation. Verified the final typed line and existing Markdown after quitting with the editor active and reopening the note; both QA connections also survived. Verified the corrected live font and heading rendering in the native app.
- Debug and Release builds succeeded. The 0.3.0 ZIP checksum passed; its extracted app passed strict signature verification.
- The production workspace checksum was unchanged after testing; study notes were not used for editing tests. Previous app builds were retained.

## Limits

These checks do not establish that every possible bug is eliminated. Physical trackpad edge cases, very large notes, every assistive input method and all combinations of Markdown nesting have not been exhaustively tested. Full-source mode remains available for complex edits. Note resizing, moving boards between folders, sync and automatic updates remain future work.

The app is ad-hoc signed locally, not Developer ID signed or notarised.
