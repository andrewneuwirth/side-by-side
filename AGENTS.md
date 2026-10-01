# AGENTS.md — Side by Side

## Purpose
Tiny macOS app that places two photos side by side (same height, no cropping) and saves one PNG.
Option+M global hotkey toggles the window; it registers itself as a login item.

## Stack
Single-file SwiftUI/AppKit app (`main.swift`), compiled directly with `swiftc` (no Xcode project, no SwiftPM).
macOS 14+, Xcode command line tools.

## Commands
- Build: `./build.sh` → `Side by Side.app` next to the script; then `open "Side by Side.app"`.
- No tests.

## Outputs
`Side by Side.app` in the repo root (gitignored via `*.app`). `build.sh` deletes and recreates it each run,
generates `AppIcon.icns` from `icon.svg` (qlmanage/sips/iconutil), and ad-hoc signs it.

## Paths that must not move
- `main.swift` and `icon.svg`: `build.sh` reads both from its own directory.
- The built app's location: it registers itself with `SMAppService.mainApp` as a login item, so moving or
  renaming the installed `.app` affects the login item.

## Docs
Docs go in `docs/`, never the repo root (only README.md and AGENTS.md at the root).
