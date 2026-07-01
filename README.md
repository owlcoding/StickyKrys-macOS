# StickyKeys

StickyKeys is a native macOS menu-bar utility for one-shot modifier keys:

- press and release **Right Shift**, then press a key to apply **Shift** once;
- double-tap **Right Shift** quickly to lock **Shift** for following keys, then press
  **Right Shift** once to return to normal;
- press and release **Right Option**, then press a key to apply **Option** once;
- press and release **Right Command**, then press a key to apply **Command** once;
- with **Enable modifiers for mouse click and scrolls** turned on, the pending
  modifier is also applied to clicks, drags, and scroll events without consuming it;
- press **Escape** or press the same non-locking trigger twice to cancel the pending
  modifier.

While a modifier is pending, a non-interactive HUD in the top-right corner shows
`⇧`, `⌥`, or `⌘`. Locked Shift uses the same `⇧` symbol with a green dot next
to it. It disappears when the modifier is used, cancelled, or unlocked.

## Requirements

- macOS 13 or newer
- Xcode 15 or newer (the project is verified with the Xcode version reported by `xcodebuild`)

## Build and run

1. Open `StickyKeys.xcodeproj` in Xcode.
2. Select the `StickyKeys` scheme and the **My Mac** destination.
3. In **Signing & Capabilities**, select your development team if Xcode asks for one.
4. Build and run with **⌘R**. The app appears only in the menu bar.
5. Choose **Permissions…** from the menu and grant both **Accessibility** and **Input Monitoring**. Restart the app if macOS asks you to do so.

For normal use, archive/copy `StickyKeys.app` to `/Applications` before enabling **Launch at Login**. macOS permission records are tied to the signed app identity and location, so rebuilding or moving an unsigned Debug app can require granting permissions again.

## Implementation notes

- A session-level `CGEventTap` consumes trigger events and mutates following key
  events. Mouse actions receive the active modifier flags without consuming pending
  state.
- The app handles keyboard, mouse button, drag, and scroll events. Modifier triggers
  normally arrive as `flagsChanged`.
- Right Shift, Right Option, and Right Command are consumed as one-shot triggers, while their left-side counterparts continue to work as normal modifiers.
- App Sandbox is disabled because a suppressing global event tap is incompatible with the sandboxed app model.
- Preferences are persisted with `UserDefaults`; Launch at Login uses `SMAppService.mainApp`.
