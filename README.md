# Sprig

Sticky-note study boards by Tandemry, built for macOS with SwiftUI, AppKit and Liquid Glass.

[Download the latest release](https://github.com/Tandemry/sprig/releases/latest)

## Install

Download the macOS ZIP from Releases, extract it, and move Sprig.app to Applications.

- Requires macOS 26 or later and an Apple Silicon Mac.
- The current release is an early development build with an ad-hoc signature. It is not Developer ID signed or notarised; macOS may block downloaded copies.
- Intel builds have not been verified. Automatic updates are not implemented.

## Features

- Nested folders, boards and five sticky-note colours.
- Drag notes from their piles, pan, zoom, fit and switch to a list.
- Live Markdown editing with formatting, tables, tasks, code and maths; optional full-source mode.
- Animated rope connections with colours, rigidity and adjustable tension.
- Inline board renaming, pinned boards, search, undo/redo and recoverable note trash.
- Local saving, Markdown export, and JSON workspace backup/import.
- Official layered Liquid Glass app icon with system appearance support.

## Build

Use Xcode 27 or later and Node.js 22.12 or later. The current release was built with Xcode 27.1 on Apple Silicon.

```sh
npm ci
npm run native:renderer
open native/Sprig.xcodeproj
```

Select the Sprig scheme and run, or build and package from the terminal:

```sh
npm run native:build
npm run native:package
```

The package command writes the app to `~/.codex/artifacts/sprig-native-0.3.12-arm64/Sprig.app` and the ZIP/checksum to `releases/Sprig-native-arm64/`. It uses an ad-hoc signature and does not publish anything automatically.

## Tests

```sh
npm run native:test
npm run native:renderer
npx playwright install chromium webkit
npx playwright test tests/e2e/native-live-editor.spec.ts tests/e2e/native-preview.spec.ts
npx playwright test tests/e2e/native-live-editor.spec.ts tests/e2e/native-preview.spec.ts --browser=webkit
```

The GitHub workflow runs the editor and preview checks in Chromium and WebKit. Native build details and change notes are in [native/README.md](native/README.md).

## Your notes

The native app stores its workspace locally at `~/Library/Application Support/Tandemry/Sprig/workspace.json`. Export backups regularly from Library. JSON import adds copies without replacing existing notes. Cloud sync and collaboration are not implemented.

The repository includes sample Psychology content for the initial board. It does not include a user's saved workspace.

## Source layout

- `native/`: the current macOS app, Xcode project, Swift tests and bundled editor.
- `tests/e2e/native-*.spec.ts`: live editor and Markdown preview checks.
- `src/`, `desktop/`: the earlier web/Electron prototype, retained for reference. It has separate storage and is not the released native app.
- `public/assets/`, `design-reference/`: original Sprig Concept 1 design assets and references.

Third-party notices are included with the bundled editor; font licences are in `native/Sources/SprigApp/Resources/Fonts/`.
