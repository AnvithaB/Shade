# Shade

A small macOS menu-bar utility that puts a translucent tint over your screens. Built for personal use when bright text in dark-mode apps felt too bright.

Shade tints the entire screen, including images and video. It does not selectively recolor text or change the display’s hardware brightness.

## What it does

- Turn the tint on or off from the menu bar.
- Choose a tint color and adjust opacity (0–65%).
- Create a click-through overlay for each connected display.
- Remember your color, opacity, and on/off setting between launches.
- Request support across Spaces and full-screen apps; behavior can vary.

No accounts, network requests, or screen recording. No Screen Recording or Accessibility permission is requested.

## Build and use

Requires macOS 13 or later and Xcode or Apple’s Command Line Tools. The build targets the architecture of the Mac running it. Python 3 is only needed if the script detects an older toolchain’s duplicate module-map issue.

1. Download or clone this repository.
2. In Terminal, open its folder and run:

   ```sh
   ./Build.command
   ```

3. Open the generated **Shade.app**. The first launch applies a teal tint at 18% opacity.
4. Use the moon-in-a-circle menu-bar icon to toggle the tint, adjust intensity, choose a color, or quit.

You can move the built app to Applications. To keep it in the Dock, drag Shade.app there; opening it again brings up its menu. Shade itself has no main window or automatic Dock icon.

To start at login, add Shade.app in **System Settings → General → Login Items** (the wording varies by macOS version). This is a manual setup step, not an in-app feature.

The build is signed locally, not notarized. This repository contains source, not a signed installer or a ready-made download for other Macs.

## Known limitations

- **App Store confirmations can lose their Install/purchase button while Shade is on.** Changing the tint color did not help in testing. Turn the tint off manually for the confirmation, then turn it back on. Shade does not automatically pause for the App Store.
- Secure system screens and some full-screen content may appear above the overlay.
- The menu-bar icon can be difficult to find in a crowded menu bar. A Dock shortcut provides another way to open its menu.
- Multi-display reconnection and Spaces/full-screen behavior have not been comprehensively tested.

This is a small personal utility with limited testing. See [TESTING.md](TESTING.md) for what has actually been checked.

## Development

The implementation is in `Sources/Shade/Shade.swift`. Quit Shade before rebuilding. `Package.swift` can also be opened in Xcode; `Build.command` creates the standalone app bundle.

Run the settings checks after building:

```sh
./Shade.app/Contents/MacOS/Shade --check-settings
```

A separate `--self-test` briefly creates overlay windows and checks their properties. Run it from a normal Mac terminal; it cannot initialize AppKit in some restricted environments. These checks do not replace testing the app on your displays.
