# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open in Xcode:
```bash
open Sajda.xcodeproj
```

Select the **Sajda** scheme and press ⌘R to run.

Build a release DMG:
```bash
./scripts/make-dmg.sh
```

Output lands at `dist/Sajda.dmg`. The script uses `CODE_SIGN_IDENTITY="-"` (ad-hoc signing) so no Apple Developer account is required.

## Architecture

Sajda is a macOS 14+ menu bar app with a companion WidgetKit extension. There are two targets and one shared module:

**Sajda (main app)**
- `SajdaApp.swift` — `@main` entry point. Hosts a `MenuBarExtra` with `.window` style so the popover is a floating panel. Creates the single `PrayerTimesViewModel` and passes it into `ContentView`. Calls `LaunchAtLogin.enableOnFirstLaunchIfNeeded()` on first launch.
- `ContentView.swift` — SwiftUI view + `PrayerTimesViewModel`. The view model handles CoreLocation (with an 8-second timeout), reverse geocoding via `CLGeocoder`, and falls back to `ipwho.is` for an IP-based approximate location when GPS is unavailable. Prayer data is fetched from the Aladhan API. A `Timer` fires every 30 s to keep `now` current; the UI uses `TimelineView(.periodic(from:by:15))` for the countdown ring.
- `LaunchAtLogin.swift` — thin wrapper around `SMAppService.mainApp` (ServiceManagement framework). Registers the app as a Login Item; `enableOnFirstLaunchIfNeeded()` auto-enables it on first launch via a `UserDefaults` flag (`sajda.didOfferLaunchAtLogin`).

**SajdaWidget**
- `SajdaWidget.swift` — WidgetKit extension. `SajdaTimelineProvider` fetches a fresh schedule and schedules the next refresh at the following prayer time (+60 s). Three widget sizes: small (next prayer only), medium (next prayer + 4-row list), large (next prayer + full list).

**Shared**
- `PrayerTimes.swift` — all data types and networking, compiled into both targets:
  - `PrayerSchedule` / `PrayerTime` / `PrayerName` — core value types
  - `PrayerTimesService` — fetches from `https://api.aladhan.com/v1/timings` (method 2 = ISNA). Default location is London (51.5074, −0.1278).
  - `PrayerSchedule.sample` — static fixture used for widget previews and Xcode Previews
  - Private Decodable structs mirror the Aladhan API response shape
- `GlassPanel.swift` — `TransparentMenuBarWindow` NSViewRepresentable that gives the popover window a transparent background so the card's dark fill shows cleanly

## Key Constraints

- **No persistence layer** — schedule is fetched fresh each launch and discarded; the widget refreshes itself via WidgetKit timelines.
- **Shared target** — `PrayerTimes.swift` and `GlassPanel.swift` have membership in both the app and widget targets. Adding new shared types goes there.
- **Location fallback chain**: CoreLocation GPS → `ipwho.is` IP geolocation → hard-coded London default (widget only).
- **Calculation method is hardcoded** to `method=2` (ISNA) in the Aladhan query.
