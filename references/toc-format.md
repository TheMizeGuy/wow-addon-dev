# TOC Format Reference

The `.toc` file is the manifest. WoW reads it to decide whether to load the addon, what to call it, what files to load, and what saved variables to track.

## Hard rules

- **Folder name and TOC filename must match.** `MyAddon\MyAddon.toc` — if the folder is `MyAddon` then the file must be `MyAddon.toc` (or one of the per-edition variants below). Mismatch = addon doesn't show up.
- **Lines starting with `## ` are directives.** Everything else not blank or a comment is treated as a path to a file (relative to the addon folder) to load in order.
- **Comments use `# `** (single hash). Blank lines are ignored.
- **Only the first 1024 characters of each line are processed.** Long file paths get truncated.
- **File paths use backslashes** (`subfolder\file.lua`) for Windows compatibility, though forward slashes work on macOS.

## Required directives

```
## Interface: 120005
## Title: My Addon
```

`Interface` controls compatibility — too low and the addon shows "Out of Date" in the AddOns list and won't load unless the player checks "Load out of date AddOns". `Title` is what shows in the list.

## Current Interface numbers (April 2026)

| Edition | Number | Notes |
|---|---|---|
| Mainline (retail Midnight) | `120005` | 12.0.5; bumps with every minor patch |
| Mists Classic | `50503` | |
| Wrath / Titan Reforged | `38001` | |
| TBC Classic | `20505` | |
| Vanilla / Classic Era | `11508` | |

To get the live number from in-game: `/dump select(4, GetBuildInfo())` — the 4th return is the interface number.

To support multiple editions in one TOC, comma-delimit:
```
## Interface: 120005, 50503, 11508
```
WoW picks whichever number matches the running client.

## Standard metadata directives

```
## Interface: 120005
## Title: My Addon
## Notes: Brief description that shows on hover in the AddOns list.
## Author: YourName
## Version: 1.2.3
## IconTexture: Interface\Icons\INV_Misc_QuestionMark
## IconAtlas: TaskPOI-Icon
## Category: Combat
## Group: MyAddonSuite
```

`Notes` supports color codes: `## Notes: Important |cFFFF0000warning|r text.`

`Category` (added 11.1) helps users filter. Standard values: `Achievements`, `Action Bars`, `Auction & Economy`, `Audio`, `Bags & Inventory`, `Buffs & Debuffs`, `Chat & Communication`, `Class`, `Combat`, `Companions`, `Development Tools`, `Guild`, `Healing`, `Map & Minimap`, `Mission`, `Plugins`, `Professions`, `PvP`, `Quests & Leveling`, `Raid Frames`, `Roleplay`, `Tanking`, `Tooltip`, `Transmogrification`, `UI Replacement`, `Unit Frames`, `Utility`, `Other`.

`Group` (added 11.1) groups related addons under a parent in the AddOns list.

## Localization variants

Append a locale code to localize any string directive:

```
## Title: My Addon
## Title-frFR: Mon Module
## Title-deDE: Mein Addon
## Notes: Default English notes.
## Notes-frFR: Notes en français.
```

Locales: `enUS`, `enGB`, `frFR`, `deDE`, `esES`, `esMX`, `ruRU`, `koKR`, `zhCN`, `zhTW`, `ptBR`, `itIT`.

## Saved variables

```
## SavedVariables: MyAddonDB, MyAddonOptions
## SavedVariablesPerCharacter: MyAddonCharDB
## LoadSavedVariablesFirst: 1
```

- `SavedVariables` — written to `WTF\Account\<ACCOUNT>\SavedVariables\<AddonName>.lua`. Shared across all characters.
- `SavedVariablesPerCharacter` — written to `WTF\Account\<ACCOUNT>\<Realm>\<Character>\SavedVariables\<AddonName>.lua`. Per character.
- `LoadSavedVariablesFirst: 1` — load the SVs *before* the Lua files, instead of after the last file. Only useful if you need the table populated when the file's chunk runs (rare).

Comma-separated variables go into the same TOC line. Always declare every saved global your addon writes to — undeclared globals don't persist.

## Dependencies

```
## Dependencies: Ace3, LibStub
## OptionalDeps: Masque, LibSharedMedia-3.0
## LoadWith: Blizzard_AchievementUI
## LoadManagers: AddonLoader
```

- `Dependencies` (or `RequiredDeps`) — addons that must load *before* this one. The game refuses to load this addon if any are missing.
- `OptionalDeps` — addons that load before this one *if available*. No error if missing. Use for soft library dependencies.
- `LoadWith` — load this addon when the named addon (typically a `Blizzard_*` LoD addon) loads.
- `LoadManagers` — defer loading to a third-party manager (rare).

## Load behavior

```
## LoadOnDemand: 1
## DefaultState: disabled
## OnlyBetaAndPTR: 1
## SecureRequired: 1
## AllowAddOnTableAccess: 1
```

- `LoadOnDemand: 1` — addon doesn't auto-load; another addon or `/run C_AddOns.LoadAddOn("name")` must load it.
- `DefaultState: disabled` — addon ships disabled by default; user must enable it.
- `OnlyBetaAndPTR: 1` — only loads on PTR/Beta builds.

## Addon compartment (Dragonflight+)

The minimap-button replacement panel:
```
## AddonCompartmentFunc: MyAddon_OnClick
## AddonCompartmentFuncOnEnter: MyAddon_OnEnter
## AddonCompartmentFuncOnLeave: MyAddon_OnLeave
```

Each value is a Lua function name (must be a global) that runs on the corresponding interaction.

## Multi-edition file naming

When an addon needs different code per WoW edition, use per-edition TOC files. The game picks the most-specific one available:

| Suffix | Edition matched |
|---|---|
| `_Standard.toc` | Mainline excluding Plunderstorm |
| `_Mainline.toc` | Mainline including Plunderstorm |
| `_Mists.toc` | Mists Classic |
| `_Cata.toc` | Cataclysm Classic |
| `_Wrath.toc` | Wrath Classic |
| `_TBC.toc` | TBC Classic |
| `_Vanilla.toc` | Vanilla / Classic Era |
| `_Classic.toc` | Any Classic (fallback) |
| `.toc` (no suffix) | Default fallback |

Legacy suffixes `-WOTLKC` and `-BCC` were deprecated in 2026.

## Variable expansion in file paths

Inside the file list section of a TOC, these substitute at parse time:

```
## Interface: 120005
[Family]\Core.lua
[Game]\Tweaks.lua
Localization\[TextLocale].lua
```

- `[Family]` → `Mainline` or `Classic`
- `[Game]` → `Standard` / `Vanilla` / `TBC` / `Wrath` / `Cata` / `Mists`
- `[TextLocale]` → `enUS`, `frFR`, etc. (added 11.2)

## Conditional file loading

Append `[AllowLoadGameType <type>[, <type>...]]` to a file line to skip it on other editions:

```
RetailFeatures.lua [AllowLoadGameType mainline]
ClassicCompat.lua [AllowLoadGameType vanilla, tbc, wrath]
```

Game type tokens: `standard`, `mainline`, `mists`, `cata`, `wrath`, `tbc`, `vanilla`, `plunderstorm`, `wowhack`, `classic` (matches all classic editions).

For locale-conditional files (added 11.2):
```
Localization\enUS.lua [AllowLoadTextLocale enUS]
Localization\frFR.lua [AllowLoadTextLocale frFR]
```

## Embedded libraries

Convention is to put libraries in `Libs\` and reference them via TOC includes:

```
## OptionalDeps: Ace3
embeds.xml
Core.lua
```

`embeds.xml` is an XML file that wraps `<Include file="Libs\LibStub\LibStub.lua"/>` etc. When a third-party addon already provides a newer version of a library via LibStub, the embedded version is silently shadowed — that's the point.

## Real example: a complete TOC

```
## Interface: 120005
## Title: Crown Cosmos Callout
## Notes: On Crown of the Cosmos, announces the demiboss you're running to the first time Silverstrike Arrow goes out - only if you get the arrow.
## Author: YourName
## Version: 1.23
## IconTexture: Interface\Icons\Ability_Hunter_Snipershot
## Category: Combat
## SavedVariablesPerCharacter: CrownCosmosCalloutDB

CrownCosmosCallout.lua
```

## Common mistakes

- **Forgetting blank line between directives and file list.** Not strictly required but conventional and easier to read.
- **Trailing whitespace on `## Interface:` line.** Some addon managers strip it; others fail to parse.
- **Using `MyAddon-Mainline.toc`** (hyphen) instead of `_Mainline.toc` (underscore). Hyphen variant is for retired Classic suffixes only.
- **Listing files in the wrong order.** Files load top-to-bottom. If `Init.lua` defines a function used by `Core.lua`, `Init.lua` must be listed first.
- **Leaving stale entries.** A file in the list that doesn't exist on disk fails the addon to load with a "TOC: file not found" error.
