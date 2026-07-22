# DailyBrief Product Expectations

DailyBrief is a lightweight personal productivity utility for macOS. Its job is to make daily reflection and work recall effortless without becoming a general-purpose notes app.

## Product Vision

DailyBrief helps users capture small daily details in real time so they can recall them later for standups, performance reviews, and personal reflection.

The app is intentionally narrow. It is organized around three daily categories:

- **Standup Updates**: work progress, next steps, and blockers.
- **Achievements**: wins, completed tasks, breakthroughs, and professional growth moments.
- **Gratitude**: positive moments and things the user is thankful for.

## Core UX Principles

- **Zero footprint**: DailyBrief must live in the macOS menu bar and stay out of the Dock.
- **Fast capture**: opening the panel should focus the Standup field so the user can type immediately.
- **No save friction**: there are no Save buttons. Edits autosave as the user types.
- **Local and private**: entries are stored locally. The app does not use cloud APIs or external servers.
- **Date-first recall**: all entries are keyed by day, and switching dates should immediately load that day.
- **Compact and calm**: the UI should feel native, minimal, and polished in a menu bar popover.

## Primary User Flow

1. User clicks the menu bar icon or presses `Cmd+Ctrl+D`.
2. DailyBrief opens a compact popover.
3. The Standup Updates field is focused automatically.
4. User types in any of the three sections.
5. Changes autosave in the background.
6. User clicks outside the popover and it closes.
7. User can later navigate dates to recall past entries.

## Interface Expectations

The menu bar panel is ordered from top to bottom:

1. **Date header**
   - Previous-day button.
   - Centered selected date label.
   - Next-day button.
   - Clicking the date opens the calendar popover.

2. **Calendar popover**
   - Month navigation.
   - Today shortcut.
   - Per-day activity dots:
     - Blue: Standup Updates
     - Green: Achievements
     - Red: Gratitude
   - Multiple dots can appear for the same date.
   - Dots should render as a simple centered group with even spacing.

3. **Entry sections**
   - Standup Updates placeholder: `What did you work on today?`
   - Achievements placeholder: `What did you accomplish or smash today?`
   - Gratitude placeholder: `What made you smile or feel thankful for today?`
   - `Tab` moves to the next editor.
   - `Shift+Tab` moves to the previous editor.
   - Scrollbars should only be visible while actively scrolling.

4. **Settings footer**
   - Storage folder selection.
   - Reset to default storage folder.
   - Launch at login toggle.
   - Quit action.

## Date Behavior

- Previous and next buttons move exactly one calendar day.
- The calendar date picker can jump to any visible date.
- Today button selects the current local calendar day.
- Switching dates saves the current date before loading the next one.
- Empty days show empty fields with placeholders.

## Storage Expectations

- Default storage is under Application Support.
- Users can choose another folder, including a synced folder such as Google Drive.
- Entries are stored as local JSON files using this layout:

```text
entries/YYYY-MM-DD.json
```

- Choosing a new empty storage folder should preserve existing entries by copying them into the new location.
- The app should not introduce a remote sync service. Syncing, if any, is owned by the folder provider selected by the user.

## Launch Behavior

- DailyBrief should register itself for launch at login by default on first app launch.
- If the user turns launch-at-login off, the app should not keep re-enabling it.

## Non-Goals

- No accounts or sign-in.
- No external backend.
- No collaborative features.
- No generic notebook organization.
- No rich text editing requirement.
- No Dock-window-first experience.

## Release Expectations

- Public releases should include a downloadable DMG.
- README should link to the latest DMG.
- Current public builds are unsigned, so the README should warn that macOS may ask for confirmation on first open.
