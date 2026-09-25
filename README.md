# Side by Side

A tiny macOS app that puts two photos next to each other and saves them as one image.

![icon](icon.svg)

- Drag a photo onto each box, or click a box to choose a file
- **Swap** flips left and right
- **Download** (⌘S) saves a single PNG — both photos scaled to the same height, nothing cropped
- **Option + M** shows/hides the window from anywhere; closing the window keeps it running in the background
- Adds itself as a login item so the hotkey is always available (remove in System Settings → General → Login Items)

## Build

Requires macOS 14+ and the Xcode command line tools.

```sh
./build.sh
open "Side by Side.app"
```

Everything lives in `main.swift`; `build.sh` compiles it with `swiftc`, generates the app icon from `icon.svg`, and ad-hoc signs the bundle.
