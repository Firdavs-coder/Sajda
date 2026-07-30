![Sajda](banner.png)

# Sajda

A lightweight macOS menu bar app for Islamic prayer times.

Sajda lives in your menu bar and shows the next prayer at a glance. Click it for today’s full schedule, countdown, and location — with optional desktop widgets.

## Features

- **Menu bar countdown** — next prayer name and time, always visible
- **Daily schedule** — Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
- **Location-based times** — uses your location (falls back to London)
- **Hijri & Gregorian dates**
- **Desktop widgets** — small, medium, and large
- **Launch at login** — reappears after reboot

## Requirements

- macOS 14.0 or later
- Xcode 15+ (to build from source)

## Install

### From DMG

1. Open `dist/Sajda.dmg` (or build one with the script below)
2. Drag **Sajda** into **Applications**
3. Open the app — it appears in the menu bar

### Build from source

```bash
open Sajda.xcodeproj
```

Select the **Sajda** scheme and run (⌘R).

### Create a DMG

```bash
./scripts/make-dmg.sh
```

Output: `dist/Sajda.dmg`

## Usage

1. Launch **Sajda** — a prayer label appears in the menu bar
2. Click it for the full day panel and countdown ring
3. Allow **Location** when prompted for local times
4. Add a **Sajda** widget from the macOS widget gallery (optional)

## Privacy

Prayer times are fetched from the [Aladhan API](https://aladhan.com/prayer-times-api). Location is used only to request times for your area; nothing is stored on a Sajda server.

## License

[MIT](LICENSE)
