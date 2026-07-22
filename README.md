# DailyBrief

DailyBrief is a lightweight macOS menu bar app for capturing the small details of your day as they happen.

It is built around three daily prompts:

- **Standup Updates**: what you worked on and what is blocked.
- **Achievements**: wins, completed work, and breakthroughs.
- **Gratitude**: positive moments worth remembering.

The app stays out of the Dock, opens from the menu bar or a global shortcut, autosaves every edit, and keeps data local in a folder you control.

## Features

- Menu bar only app with no Dock icon.
- Compact popover interface that dismisses when you click away.
- Global shortcut: `Cmd+Ctrl+D`.
- Three focused multiline note sections.
- Realtime autosave with no Save button.
- Date navigation with previous and next day buttons.
- Calendar view with per-section activity dots:
  - Blue: Standup Updates
  - Green: Achievements
  - Red: Gratitude
- Today shortcut in the calendar.
- User-selectable storage folder, useful for synced folders like Google Drive.
- Launch at login setting.
- Local JSON storage only. No cloud service or external server.

## Storage

DailyBrief stores one JSON file per day:

```text
entries/YYYY-MM-DD.json
```

By default, entries are stored under the app's Application Support folder. You can choose a different folder from the settings gear in the app, including a synced drive folder.

## Build

Requirements:

- macOS 13 or newer
- Xcode

Build from the command line:

```sh
xcodebuild -project DailyBrief.xcodeproj -scheme DailyBrief -configuration Debug build
```

Run tests:

```sh
xcodebuild test -project DailyBrief.xcodeproj -scheme DailyBrief -configuration Debug -destination 'platform=macOS'
```

## Development

The app is written in Swift and SwiftUI, with AppKit used where macOS menu bar behavior and text editing need native control.

Key areas:

- `DailyBrief/App`: app delegate, menu bar lifecycle, and menu bar icon.
- `DailyBrief/Views`: SwiftUI views and the AppKit-backed multiline editor.
- `DailyBrief/Storage`: local JSON persistence and storage folder settings.
- `DailyBrief/ViewModels`: date selection, autosave, and activity state.
- `DailyBriefTests`: persistence and view model tests.

## Privacy

DailyBrief does not sync data itself and does not send your entries anywhere. If you choose a synced folder, syncing is handled by that folder provider.
