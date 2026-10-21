# Sprig — native macOS

SwiftUI and AppKit implementation of **Sprig Concept 1**, targeting macOS 26 and later. The app uses Apple's Liquid Glass APIs for the floating navigation, board controls, menu buttons and formatting toolbar.

Open [Sprig.xcodeproj](Sprig.xcodeproj) in Xcode, select the **Sprig** scheme and run. This is a local application build; no App Store account is required to build it.

From the parent `sprig/` directory:

```sh
npm run native:build
npm run native:test
npm run native:package
```

The package command creates the native app at `~/.codex/artifacts/sprig-native-0.3.12-arm64/Sprig.app`, and a ZIP plus SHA-256 checksum in `releases/Sprig-native-arm64/` on Apple Silicon. The loose app is kept outside this File Provider-managed Documents folder so the provider cannot inject Finder metadata into its signed resource bundles. Set `SPRIG_ARCH=x86_64` when building for Intel; only the Apple Silicon build has been verified here. The output is ad-hoc signed for local testing. It is not Developer ID signed or notarised and is distributed through GitHub Releases.

## Design preservation

- Original Figma-exported SVG icons, kept at their designed dimensions.
- Bundled Inter fonts for the interface and live editing; monospaced text for code and optional full source.
- Named asset-catalog colours with the exact Figma colour values, including all five sticky-note colours.
- Reference layout: 1470 × 830. The navigation remains 400 × 60, board notes 256 × 256, Home notes 196 × 196, and editor 520 × 520.
- Native `.glassEffect` and `GlassEffectContainer` materials. macOS renders the refraction and reflections and honours Reduce Transparency; those optical effects vary with system settings and content behind them.
- Home, board, colour stacks and floating editor follow the original composition. Library, Search and creation forms extend that visual language.
- The Figma document has not been changed.

## Implementation

The window, controls, note cards, folders and board interactions are SwiftUI/AppKit. The Markdown editor is a local CodeMirror document inside WebKit, with undo history, selection, typing, clipboard handling and live decorations. Headings/emphasis are styled as you type; Markdown markers appear around the active source. Inactive tables, code, maths and recall sections render in place and can be reopened for editing. Checkboxes update their Markdown source. The optional full-source switch uses the same editable document and history. Bundled React Markdown/GFM/KaTeX render complex blocks. Everything runs from bundled files, with no Electron or Node runtime in the app.

The native model supports folders, boards, note creation, dragging, pan, zoom, fit, connections, duplicate, undo/redo, recoverable trash, search, pinning and Markdown/JSON export. Scroll the canvas to pan; pinch or hold Command/Control while scrolling to zoom around the pointer. Right-click a connection to remove it, or use a note’s contextual menu to remove its connections. Fit centres all notes, including notes dragged beyond the original canvas.

Single-click a board note to select it; double-click it or choose Edit to type. In Connect mode, click any part of two notes; slack ropes attach at facing side midpoints, swing with dragging and settle under gravity. Resizing notes, moving existing boards between folders, cloud sync and automatic updates remain future work.

## Data

The native workspace is atomically saved off the UI thread, with pending edits flushed before quitting. Sprig detects external file changes and asks you to export your current work instead of overwriting the newer file. The workspace is saved to:

`~/Library/Application Support/Tandemry/Sprig/workspace.json`

This is separate from the Electron profile and browser local storage. Export a JSON backup from the old app, then choose **Import Sprig backup** in the native app. Import validates the data and adds copies with new identifiers without replacing existing notes. The JSON schema stays compatible with the prototype.

Unreadable workspace files are preserved. If loading fails, the app shows a recovery banner and does not overwrite the original file. Export recovery data and a backup before resolving the underlying file. Session undo history is not persisted.

## Verification

40 Swift tests cover compatibility, hierarchy, connections, safe saves, camera maths, formatting and app state, including delayed edits after switching notes. Seven renderer/editor scenarios passed in both Chromium and WebKit (14 browser test executions). See [the 0.3.0 QA report](QA-0.3.0.md) for the verified fixes and native checks.
```sh
npm run native:test
npx playwright test tests/e2e/native-live-editor.spec.ts tests/e2e/native-preview.spec.ts
npx playwright test tests/e2e/native-live-editor.spec.ts tests/e2e/native-preview.spec.ts --browser=webkit
```

The `--build-system native` test flag avoids the installed Swift build engine attempting to sign intermediate resource bundles inside a File Provider-managed Documents directory. Xcode builds place derived output in the system temporary directory and do not need that workaround. The local iOS simulator installation reports a version mismatch, but this macOS target builds successfully without using it.

## Motion

Spring transitions cover navigation selection, page changes, editor opening/closing, note insertion/removal, selection tools, view modes, zoom/Fit, hover and button presses. Direct dragging and panning follow the pointer. Live/full-source mode changes preserve the same editor, selection and undo stack. System Reduce Motion disables movement and scale effects; it does not require a Sprig preference.

## 0.2.2 canvas correction

The board now covers the whole window beneath the floating controls. Previously its top 213 points were outside a clipped canvas, and note creation/dragging clamped coordinates to zero. Both restrictions have been removed. Existing saved positions retain their original appearance; negative world coordinates are supported. Zoom, Fit and note creation use the same canvas origin. Native UI checks confirmed dragging a note above the former boundary, dragging it again from that area, opening it, and saving the new position. Three additional tests cover upper-workspace coordinates, anchored zoom/Fit and saving/reopening an upper note. All 28 native tests passed.

## 0.3.1 interaction and rope update

The entire top navigation label has an explicit rectangular hit area. The editor status row has been removed; optional full source now lives in the note’s actions menu. Connections use a pinned particle rope with gravity, slack and damped inertia. Endpoints follow temporary drag positions before model persistence and sit behind the centre of each card. Idle ropes stop updating; Reduce Motion uses a static settled rope. See [0.3.1 QA](QA-0.3.1.md).

## 0.3.2 rope controls

In Connect mode, click the visible rope to select it. A Liquid Glass toolbar offers six rope colours, Rigidify/Loosen and Delete. Style changes and deletion animate and support Undo/Redo. Colour and rigidity are saved/exported/imported; older connections default to sage and slack. Attachments use fixed side midpoints and outward tangents so sag does not move the apparent exit down the card. See [0.3.2 QA](QA-0.3.2.md).

## 0.3.3 curve refinement

Removed the rigid 24-point attachment leads. Physics now pins the free rope directly at each side midpoint, and one interpolating curve follows it from end to end. Nearby particles stay on the outward side of the attachment without a fixed neck length. This removes the straight-then-sagging appearance. All 38 native tests pass, including a regression that the first free particle bends immediately while the anchor stays fixed. Native visual checks confirmed the curve and rope selection; user notes were unchanged.

## 0.3.4 rope tightness

The rope toolbar includes `< Tighten >`. Hold `>` to increase tightness and `<` to add slack. Native repeating buttons stop on release or at the limit. The rope simulation responds continuously; the value is saved/exported/imported per connection, with 50% preserving previous behaviour. A held adjustment groups into one Undo step. Tightness controls are disabled for rigid lines; choose Loosen first. Forty native tests pass. In native QA, holding right increased 50% to 88%, holding left decreased it to 60%, and Undo restored 88%. Saved tightness was verified after quitting. User study notes were unchanged.

## 0.3.5 selection halo

Selected notes now have an opaque backing beneath the outside selection halo. Ropes can no longer show through its gap or translucent border. Verified visually in the native app with a connected selected note. Debug/Release builds succeeded; model tests were not rerun for this appearance-only change. User study notes were unchanged.

## 0.3.6 official app icon

The Xcode target compiles `AppIcon.icon`, copied unchanged from the original `SprigIcon1.icon` Icon Composer document supplied alongside the PNG exports. The layered sprout, gradient, glass material, translucency and shadows are retained. macOS chooses the default, dark, clear and tinted light/dark presentations through its native icon appearance system. Both build configurations use AppIcon; Xcode generates the compiled icon stacks, icon sizes and fallback `AppIcon.icns`. No runtime Dock-icon override is used.

Release verification confirmed the bundle icon keys, compiled Aqua/Dark Aqua/tintable icon stacks and glass lighting metadata, the fallback icon, and the extracted ZIP's ad-hoc signature. This icon-only update does not touch workspace data.

## 0.3.7 navigation and board menus

Navigation icon fill now follows each button's selected state, using the original Figma paths for both outline and filled variants. The board title is a dropdown containing rename, pin, export and switch-board actions, replacing the separate circular ellipsis. Rename and creation sheets use a leading-aligned rounded name field without the grouped Form's rectangular background, consistent typography, a neutral Cancel button and an accented primary action.

Debug and Release builds passed. Native UI checks covered all four navigation states, the title dropdown, rename typing and Return to save, reopening the app with the saved title, blank-name validation, Escape cancellation, and the shared new-board sheet. Checks used a separate temporary workspace. The packaged ZIP was extracted and its ad-hoc signature verified.

## 0.3.8 inline board rename

Double-click the board title or choose Rename board from its adjacent configuration dropdown to edit the title in place. A Liquid Glass surface surrounds the title field and checkmark/cancel controls; Return saves and Escape cancels. The existing name is selected automatically, blank names cannot be saved, and leaving the board discards an uncommitted draft. Renaming uses the existing workspace history and save path. It no longer opens the rename sheet.

Release build passed. Native UI checks in a separate temporary workspace verified both entry points, immediate typing, Return and checkmark saves, blank-name validation, Escape cancellation, and the resulting saved workspace file. The packaged ZIP's extracted ad-hoc signature and checksum were verified.

## 0.3.9 pile dragging

Pile creation now uses an in-board gesture. Only the top sheet moves with the pointer; the two backing sheets remain stationary, with no whole-stack system drag snapshot. Releasing within the source pile returns the sheet without creating a note or a history entry. Successful board drops use the current camera to position one new note. Click and accessibility activation retain their existing create-and-edit behavior. The returning sheet uses a spring, with Reduce Motion respected.

Release build passed. Native checks in an isolated workspace confirmed source-pile releases in butter and rose left the note count unchanged, a board drop created exactly one butter note at the expected coordinates, and clicking sage created exactly one further note. Saved data contained exactly those two additions. The extracted package signature and ZIP checksum were verified.

## 0.3.10 heading alignment

Inactive ATX headings hide the separator whitespace along with the Markdown hashes, aligning the visible heading with body text. Active headings still expose their original editable Markdown. The document itself is never rewritten.

A regression test reproduced a five-pixel offset before the fix and now checks all six heading levels against the body's visible text position while asserting unchanged source. All seven live-editor tests passed in WebKit and Chromium (14 executions). Release build, packaged renderer contents, extracted ZIP signature and checksum were verified.

## 0.3.11 live-editor formatting and alignment

Formatting shortcuts now take precedence over CodeMirror's syntax-selection shortcut, preventing Command-I from selecting a parent line. Active bold spans retain their styling during a trailing space before closing markers, without interpreting code or spanning intervening plain text. Block quotes use a left bar, hide their source markers in live mode, and exit to a normal paragraph when Return is pressed on an empty quote line. Full source mode retains the original syntax. The editor's content and line left padding are zero, aligning normal text with the native note title.

All 11 live-editor scenarios passed in both WebKit and Chromium (22 executions), including the previous heading alignment check and new shortcut, spacing, quoting and padding regressions. Release build passed; packaged renderer bytes match the tested bundle. Extracted ZIP signature and checksum were verified. No real workspace data was edited.

## 0.3.12 title-to-body handoff

Return in the note title now focuses the start of the body editor with a collapsed caret. The existing command bridge queues the action if WebKit is still loading. It does not alter or select the body text.

The WebKit regression test verified first-line focus without changing existing content. Native UI verification in a separate workspace confirmed typing a title, pressing Return, and immediately typing populated the body while preserving the title; both were verified in the saved file. Release build and extracted package signature/checksum passed.
