# Verification

The initial standalone app built on an Apple silicon Mac with Swift 6.0.3, targeting macOS 13 or newer. Its Info.plist and local code signature validated.

The executable’s `--check-settings` checks passed: settings encode/decode round-trip, malformed data rejection, finite/range validation, and initial defaults.

The app was launched through Finder and its process confirmed in Activity Monitor. Underlying apps remained usable during the session. The app has been used locally, but this is not a compatibility test across Macs or macOS versions.

## Limits of verification

Automated UI tooling could not inspect the menu-bar interface end-to-end. Color-picker and slider interaction, relaunch persistence, display reconnection, and Spaces/full-screen behavior still need systematic manual checks.

The `--self-test` includes display/window assertions, but could not run from the restricted shell: macOS stopped during NSApplication initialization before the tests. Normal Finder launch did work. Passing settings checks does not prove display behavior.

## Known App Store issue

An App Store installation confirmation had no install control while Shade was enabled. An experimental overlay cutout did not restore the control. That experiment and an automatic-pause workaround are not included. Use the manual tint toggle when needed.

## Manual checklist

- Toggle tint, change intensity and color, and quit.
- Reopen and check saved preferences.
- Confirm typing, clicking, and scrolling reach underlying apps.
- Switch Spaces and enter/leave full screen.
- Connect/disconnect another display and wake from sleep.
- Check App Store confirmation controls with tint on and off.
