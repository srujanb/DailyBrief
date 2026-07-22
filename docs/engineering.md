# DailyBrief Engineering Notes

This document is for agents and maintainers working on DailyBrief. It describes the current architecture, important implementation choices, and commands used to build, test, and release the app.

## Tech Stack

- Language: Swift
- UI: SwiftUI
- Native macOS integration: AppKit
- Launch at login: `ServiceManagement` / `SMAppService`
- Global hotkey: Carbon `RegisterEventHotKey`
- Persistence: local JSON files
- Minimum macOS target: macOS 13

## Source Layout

```text
DailyBrief/
  App/
    AppDelegate.swift          # NSStatusItem, NSPopover, app lifecycle
    MenuBarIcon.swift          # Code-drawn template menu bar icon
  HotKeys/
    HotKeyManager.swift        # Cmd+Ctrl+D global shortcut
  Models/
    DailyEntry.swift           # Date-keyed entry model and activity flags
    DateKey.swift              # YYYY-MM-DD date key helpers
  Resources/
    AppIcon.icns               # App bundle icon
  Settings/
    LaunchAtLoginController.swift
  Storage/
    EntryActivityIndex.swift   # Calendar activity-dot data
    EntryStore.swift           # JSON read/write and storage switching
    StorageSettings.swift      # Default/custom storage folder bookmarks
  ViewModels/
    DailyBriefViewModel.swift  # Selected date, autosave, storage switching
  Views/
    ActivityCalendarView.swift
    DateHeaderView.swift
    EntrySectionView.swift
    MenuBarPanelView.swift
    MultilineTextEditor.swift  # AppKit-backed text editor
    SettingsFooterView.swift
```

Supporting files:

```text
DailyBrief.xcodeproj/
DailyBriefTests/
Tools/GenerateAppIcon.swift
docs/
README.md
```

## App Lifecycle

`DailyBriefApp` has no normal app window. It uses `NSApplicationDelegateAdaptor` to hand lifecycle control to `AppDelegate`.

`AppDelegate` is responsible for:

- Setting `.accessory` activation policy.
- Registering launch-at-login defaults.
- Creating the `NSStatusItem`.
- Showing and hiding the transient `NSPopover`.
- Wiring the SwiftUI `MenuBarPanelView`.
- Registering and unregistering the global hotkey.
- Saving immediately on popover close and app termination.

The app also sets `LSUIElement = true` in `Info.plist`, so it stays out of the Dock.

## Menu Bar Icon And App Icon

- Menu bar icon is code-drawn in `MenuBarIcon.sunriseNote()`.
- It is marked as an `NSImage` template so macOS can tint it correctly for the menu bar.
- App icon is stored as `DailyBrief/Resources/AppIcon.icns`.
- `Tools/GenerateAppIcon.swift` generates the app icon PNG iconset from a matching sunrise-note design.

To regenerate the app icon:

```sh
mkdir -p DailyBrief/Resources
swift Tools/GenerateAppIcon.swift DailyBrief/Resources/AppIcon.iconset
iconutil -c icns DailyBrief/Resources/AppIcon.iconset -o DailyBrief/Resources/AppIcon.icns
rm -rf DailyBrief/Resources/AppIcon.iconset
```

`AppIcon.icns` is included in the app target Resources phase, and `Info.plist` sets:

```text
CFBundleIconFile = AppIcon
```

## Data Model

`DailyEntry` stores:

- `dateKey`
- `standup`
- `achievements`
- `gratitude`

`dateKey` is always a local calendar day in `YYYY-MM-DD` format. Use `DateKey.key(for:calendar:)`; do not introduce timestamp-based storage for daily entries.

`EntryActivity` derives whether each section has content. It drives the colored dots in the calendar.

## Persistence

`EntryStore` stores entries as JSON:

```text
<storage-root>/entries/YYYY-MM-DD.json
```

Important behavior:

- Empty entries are removed instead of persisted as blank JSON.
- Writes are atomic.
- Loading a missing day returns a blank `DailyEntry`.
- Switching storage folders can copy existing entries to a new empty destination.

`StorageSettings` controls the active storage root:

- Default is Application Support / DailyBrief.
- Custom folders are stored as security-scoped bookmarks.
- `saveStorageURL` ensures the chosen directory exists before bookmarking it.

## View Model

`DailyBriefViewModel` owns user-facing state:

- `selectedDate`
- `standup`
- `achievements`
- `gratitude`
- `activityByDateKey`
- `storageURL`
- `lastErrorMessage`

Autosave behavior:

- Text edits schedule a short debounce.
- Date switches save immediately before loading the next date.
- Popover close and app termination call `saveImmediately()`.

Keep date switching and calendar selection on the same path through `selectDate(_:)`.

## Text Editing

`MultilineTextEditor` wraps `NSTextView` because SwiftUI `TextEditor` does not provide enough native control for this app.

It is responsible for:

- Multiline plain text editing.
- Native undo.
- Explicit focus through AppKit first responder.
- `Tab` and `Shift+Tab` field navigation.
- Scrollbars that appear only while actively scrolling.

Tab behavior is handled through standard AppKit text command routing:

- `insertTab(_:)`
- `insertBacktab(_:)`
- `textView(_:doCommandBy:)`

Avoid raw keyboard-event hacks unless there is clear evidence that command routing cannot solve a specific problem.

## Calendar Dots

`ActivityCalendarView` renders activity dots from `EntryActivity`.

Keep dot rendering simple:

- Build an array of visible dots.
- Render the visible dots in a centered `HStack`.
- Use one shared size and spacing.
- Do not reserve invisible dot slots.
- Do not use fixed per-color offsets.

## Launch At Login

`LaunchAtLoginController` uses `SMAppService.mainApp`.

Current behavior:

- On first app launch, it attempts to enable launch-at-login by default.
- A UserDefaults flag records that the default has been applied.
- If the user turns launch-at-login off later, the app should not keep re-enabling it.

## Build And Test

Build Debug:

```sh
xcodebuild -project DailyBrief.xcodeproj -scheme DailyBrief -configuration Debug build
```

Run tests:

```sh
xcodebuild test -project DailyBrief.xcodeproj -scheme DailyBrief -configuration Debug -destination 'platform=macOS'
```

Build Release:

```sh
xcodebuild -project DailyBrief.xcodeproj -scheme DailyBrief -configuration Release build
```

## Packaging A DMG

The release DMG is created from the Release app bundle:

```sh
rm -rf .release
mkdir -p .release/staging
cp -R ~/Library/Developer/Xcode/DerivedData/DailyBrief-hbblpkfcusrkvnavozbugyutndmp/Build/Products/Release/DailyBrief.app .release/staging/
ln -s /Applications .release/staging/Applications
hdiutil create -volname DailyBrief -srcfolder .release/staging -ov -format UDZO .release/DailyBrief.dmg
hdiutil verify .release/DailyBrief.dmg
```

`.release/` is gitignored.

## GitHub Release

Current release convention:

- Tag format: `vX.Y.Z`
- DMG asset name: `DailyBrief.dmg`
- README latest-download URL:

```text
https://github.com/srujanb/DailyBrief/releases/latest/download/DailyBrief.dmg
```

Create a release with:

```sh
gh release create vX.Y.Z .release/DailyBrief.dmg \
  --target main \
  --title "DailyBrief X.Y.Z" \
  --notes "<release notes>"
```

## Implementation Guardrails

- Prefer native macOS behavior over custom workarounds.
- Keep the app menu-bar only unless the product direction explicitly changes.
- Do not add cloud/network behavior for entries.
- Keep persistence plain and inspectable.
- Keep UI changes compact and suitable for a menu bar popover.
- Preserve autosave and save-before-date-switch invariants.
- Add focused tests for storage, date behavior, and view model changes.
