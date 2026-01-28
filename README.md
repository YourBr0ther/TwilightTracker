# Twilight Tracker

A lightweight World of Warcraft addon for tracking the **Midnight prepatch Twilight Ascension** rare spawn rotation in Twilight Highlands.

Tracks all 18 rotating rares + Voice of the Eclipse for the **Two Minutes to Midnight** achievement.

## Features

- **Live rotation timer** - Knows exactly which rare is active and when the next one spawns based on the fixed EST schedule. No sync needed.
- **"Go To" indicator** - Highlights the next unkilled rare in the rotation with coordinates and time until it spawns.
- **Kill tracking** - Automatically detects kills via boss kill events, targeting, mouseover, and loot pickup. Persists across sessions.
- **Manual kill marking** - Use `/tt kill #` to manually mark any rare as killed if auto-detection misses it.
- **Progress bar** - Visual tracker showing how many of the 19 rares you've defeated.
- **Coordinates** - Every rare's location displayed in the tracker and in tooltips.
- **Waypoint support** - Click any row to set a waypoint. Works with TomTom (arrow) or WoW's built-in map pin + supertrack arrow.
- **Collapsible UI** - Minimize to just the header, or expand to see the full checklist. Draggable and position is saved.
- **Minimalist design** - Clean neutral dark theme, small footprint on screen.

## Rare Rotation

The 18 rares cycle every 3 hours on a fixed 10-minute rotation across 6 locations in Twilight Highlands:

| # | Rare | Location |
|---|------|----------|
| 1 | Redeye the Skullchewer | 65.2, 52.2 |
| 2 | T'aavihan the Unbound | 57.6, 75.6 |
| 3 | Ray of Putrescence | 71.2, 29.9 |
| 4 | Ix the Bloodfallen | 46.7, 25.2 |
| 5 | Commander Ix'vaarha | 45.2, 48.8 |
| 6 | Sharfadi, Bulwark of the Night | 41.8, 16.5 |
| 7 | Ez'Haadosh the Liminality | 65.2, 52.2 |
| 8 | Berg the Spellfist | 57.6, 75.6 |
| 9 | Corla, Herald of Twilight | 71.2, 29.9 |
| 10 | Void Zealot Devinda | 46.7, 25.2 |
| 11 | Asira Dawnslayer | 45.2, 49.2 |
| 12 | Archbishop Benedictus | 41.8, 16.5 |
| 13 | Nedrand the Eyegorger | 65.2, 52.2 |
| 14 | Executioner Lynthelma | 57.6, 75.6 |
| 15 | Gustavan, Herald of the End | 71.2, 29.9 |
| 16 | Voidclaw Hexathor | 46.7, 25.2 |
| 17 | Mirrorvise | 45.2, 49.2 |
| 18 | Saligrum the Observer | 41.8, 16.5 |

**Voice of the Eclipse** spawns hourly at one of 4 locations:
- Ruins of Drakgor (40.1, 14.2)
- Verrall Delta (67.0, 53.2)
- Thunderstrike Mountain (69.1, 29.5)
- Verrall River (47.2, 45.6)

## Slash Commands

| Command | Description |
|---------|-------------|
| `/tt` | Toggle the tracker window |
| `/tt show` | Show the tracker |
| `/tt hide` | Hide the tracker |
| `/tt wp` | Set a waypoint to the next unkilled rare |
| `/tt kill #` | Manually mark rare # (1-18) as killed |
| `/tt kill eclipse` | Manually mark Voice of the Eclipse as killed |
| `/tt status` | Print progress and missing rares to chat |
| `/tt reset` | Clear all kill data |
| `/tt help` | Show available commands |

## Installation

1. Download the latest release or clone this repo
2. Copy the `TwilightTracker` folder to your AddOns directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/TwilightTracker/
   ```
3. Restart WoW or `/reload`

The folder should contain:
- `TwilightTracker.toc`
- `TwilightTracker.xml`
- `TwilightTracker.lua`

## WoW 12.0.0 Compatibility

Built for the Midnight prepatch (Interface 120000). Uses XML-based event registration to comply with the new addon security restrictions in 12.0.0 where `Frame:RegisterEvent()` is protected from Lua code. No Blizzard UI templates are used to avoid taint issues.

## Optional Dependencies

- **TomTom** - If installed, clicking a rare row sets a TomTom arrow waypoint. Without TomTom, the addon uses WoW's built-in map pin and supertrack arrow.
