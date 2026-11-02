# Phantom Blade Zero Map Acquisition Guide

[简体中文](README.md) · Version 0.4.2 stable release

A read-only map guide and searchable collection checklist for the PC Steam version of Phantom Blade Zero.

## Features and language

- Hover or click a native map point for the item name, source region chapter and nearby bell. Expand details for available native descriptions.
- Clicking the native map preserves your region and view. Clicking a checklist entry locates its source; locked maps remain closed.
- Cyan source markers persist when clicking empty space and remain stable while zooming.
- Search by name, pinyin, initials or native ID. Filter by category, region and collection status.
- Mod text follows the game's current text language: Chinese uses Simplified Chinese; English and other languages use English. If language detection fails, English is used. After changing the game language, close and reopen the map.
- Item, region, bell and quest names use the game's own localization. The Mod does not invent translations for missing native text.
- Only native game information is used. No community walkthrough data is included. Inventory, quests, achievements and save progress are not modified.

The catalog contains 530 map records across 12 categories; this is not a unique-item count or a claim of complete game coverage. Source region chapter does not mean the earliest obtainable chapter. Nearby bells are selected by straight-line distance, not a verified walkable route.

## Requirements

- PC Steam version. Tested development baseline: Steam Build 26266538.
- [PowerShell 7](https://github.com/PowerShell/PowerShell/releases).
- The game-specific [UE4SS v3.0.1-1188-gf885e8d2 build](https://github.com/KintaroModding/ue4ss/releases/tag/v3.0.1-1188-gf885e8d2). Download `phantombladezero_ue4ss_v3.0.1-1188-gf885e8d2.zip`, not Source code. The loader is not bundled with this Mod.

## Installation

1. Exit the game. In Steam, use **Manage → Browse local files** to find the actual game folder.
2. Install the prerequisite loader by placing its `dwmapi.dll` and `ue4ss` folder inside the game's `platform/steam/`, next to `PBZ.exe`.
3. Extract the entire Mod ZIP, keeping `manifest.json`, `payload`, `tools` and the installer together. Run `INSTALL.cmd`; it locates PowerShell 7 and the Steam installation. Administrator access is requested only when needed to write to the game directory.
4. Launch normally through Steam, enter your save and open the native map. No separate game launcher or pak override is required.

```text
PBZ/
├─ platform/steam/
│  ├─ PBZ.exe                         Original game executable
│  ├─ dwmapi.dll                      UE4SS prerequisite
│  └─ ue4ss/
│     ├─ UE4SS.dll                    UE4SS prerequisite
│     └─ Mods/
│        ├─ mods.txt                  PBZMapGuide enable line merged by installer
│        └─ PBZMapGuide/
│           ├─ Scripts/main.lua       Mod entry
│           ├─ Scripts/lib/           Mod source modules
│           └─ .pbz-map-guide-install.json
└─ ProjectPBZ/Content/Paks/           Original game data; not changed
```

To specify a nonstandard location, run in PowerShell 7:

```powershell
pwsh -NoProfile -File .\install.ps1 -GameRoot 'D:\SteamLibrary\steamapps\common\PBZ' -NoPause
```

This path is an example. Use the actual directory shown by Steam.

## Upgrade, verification and uninstall

Exit the game and run the new package's `INSTALL.cmd` to upgrade. The installer checks ownership and hashes, backs up replaced files and preserves other Mods, user preferences and shared loader files. Unexpected modified files stop replacement rather than being silently overwritten.

Verify with `pwsh -NoProfile -File .\install.ps1 -Action Verify -NoPause`.

Run `UNINSTALL.cmd` to remove hash-matching Mod-owned files and its enable line. Shared UE4SS files, other Mods, preferences and transaction backups are preserved. Modified Mod scripts require review before removal.

## Limitations

- Full quest prerequisites, earliest obtainable chapters, automatic routes and panel dragging are deferred. Unknown conditions remain explicitly unverified. The separate map preview is not included.
- Collection status and location completion are distinct. Absence of a consumed item is not proof that its location is incomplete.
- Controller operation, future game patches and actual UAC elevation have not completed acceptance testing.
- Version 0.4.2 has passed automated tests, installation verification and in-game acceptance.

## License

Mod-owned code is MIT licensed; see [LICENSE](LICENSE). Game and UE4SS rights belong to their respective owners. Pinyin search data derives from [mozillazg/pinyin-data v0.15.0](https://github.com/mozillazg/pinyin-data/tree/v0.15.0), with its original MIT notice retained in `pinyin_map.lua`. No loader DLLs or original game assets are redistributed.
