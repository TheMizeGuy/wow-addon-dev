# Localization

WoW addons reach a global audience. Localization lets one addon speak the user's language without code-level branching.

## Two layers: TOC strings vs runtime strings

**TOC strings** (`Title`, `Notes`) localize via `<Directive>-<locale>:` (see `references/toc-format.md` for syntax). Runtime strings — chat output, button labels, tooltip text — need a different mechanism.

## The bare-bones pattern (no library)

Wrap every user-visible string in a lookup function:

```lua
-- Locales\enUS.lua  (loaded for default + English)
local L = {}
L["Hello, %s!"]        = "Hello, %s!"
L["Combat started"]    = "Combat started"
L["Enabled"]           = "Enabled"
L["Threshold"]         = "Threshold"

MyAddonLocale = L

-- Locales\frFR.lua  (loaded only on French clients)
local L = MyAddonLocale  -- start from English defaults
L["Hello, %s!"]        = "Bonjour, %s !"
L["Combat started"]    = "Combat commencé"
L["Enabled"]           = "Activé"
L["Threshold"]         = "Seuil"
```

In TOC, conditional-load each locale:

```
## Interface: 120005

Locales\enUS.lua [AllowLoadTextLocale enUS, enGB]
Locales\frFR.lua [AllowLoadTextLocale frFR]
Locales\deDE.lua [AllowLoadTextLocale deDE]
Core.lua
```

In Core.lua:
```lua
local L = MyAddonLocale or {}
print(L["Combat started"] or "Combat started")
```

The `or "Combat started"` fallback handles the case where the locale file failed to load — the original English string ships as the dictionary key, so it's always available even without a translation.

## With AceLocale-3.0

The Ace3 alternative. Cleaner namespace and missing-key warnings during dev.

```lua
-- Locales\enUS.lua (default — sets up the L table)
local L = LibStub("AceLocale-3.0"):NewLocale("MyAddon", "enUS", true)
if not L then return end

L["Hello, %s!"]    = true   -- 'true' means use the key as the value
L["Enabled"]       = true
L["Threshold"]     = true

-- Locales\frFR.lua
local L = LibStub("AceLocale-3.0"):NewLocale("MyAddon", "frFR")
if not L then return end

L["Hello, %s!"]    = "Bonjour, %s !"
L["Enabled"]       = "Activé"
L["Threshold"]     = "Seuil"

-- Core.lua
local L = LibStub("AceLocale-3.0"):GetLocale("MyAddon")
print(L["Enabled"])
```

The `true` literal means "key is the value." Other locales fill in just the strings they translate; missing keys silently fall back to the default locale.

`NewLocale("MyAddon", "enUS", true)` — the third `true` argument marks this as the default locale.

`AceLocale-3.0` also supports a `silent` mode (`NewLocale("MyAddon", "enUS", true, true)`) to suppress per-key missing warnings — turn off in production, leave on in dev.

## Locale codes

| Code | Language |
|---|---|
| `enUS` | English (US) — default |
| `enGB` | English (UK) — usually shares enUS |
| `frFR` | French |
| `deDE` | German |
| `esES` | Spanish (Spain) |
| `esMX` | Spanish (Latin America) |
| `ruRU` | Russian |
| `koKR` | Korean |
| `zhCN` | Chinese (Simplified, Mainland) |
| `zhTW` | Chinese (Traditional, Taiwan) |
| `ptBR` | Portuguese (Brazil) |
| `itIT` | Italian |

Detect the running locale: `GetLocale()` returns the code (e.g. `"enUS"`).

## Spell and item names — don't hardcode strings

Spell and item names differ by locale. To match a spell across all clients, use the spellID:

```lua
-- WRONG: only works on enUS clients
if spellName == "Frostbolt" then ... end

-- RIGHT: works everywhere
local frostboltSpellID = 116
if spellID == frostboltSpellID then ... end

-- Or, if a name is needed for display, look it up at runtime:
local info = C_Spell.GetSpellInfo(frostboltSpellID)
local localizedName = info and info.name  -- "Frostbolt" / "Frostblitz" / "Éclair de givre"
```

Same principle for items — `itemID` is universal; `GetItemInfo(itemID)` returns the localized name.

## GLOBAL_STRINGS

WoW exposes ~10,000 localized constants as Lua globals (e.g. `READY`, `CANCEL`, `DAMAGE`, `HEALER`, `RAID_DIFFICULTY1` for "Normal"). Use these for any concept Blizzard already translated:

```lua
-- WRONG: one-off translation needed per locale
button:SetText("Cancel")

-- RIGHT: free localization
button:SetText(CANCEL)
```

Browse the constants on the wiki under `Global_strings`. Common ones:
- `OKAY`, `CANCEL`, `YES`, `NO`, `ACCEPT`, `DECLINE`
- `HEALER`, `TANK`, `DAMAGER`
- `LFG_LIST_ITEM_LEVEL_INSTR_SHORT`
- `RAID`, `PARTY`, `GUILD`, `WHISPER`
- `TRACK_QUEST_BUTTON_TEXT`
- `ENABLE`, `DISABLE`

Reusing GLOBAL_STRINGS doesn't add localization burden but does keep the addon visually consistent with Blizzard UI.

## Pluralization

Lua's `string.format` doesn't handle plurals. For "1 mob" vs "2 mobs":

```lua
local function pluralize(n, singular, plural)
    if n == 1 then return ("%d %s"):format(n, singular) end
    return ("%d %s"):format(n, plural)
end

print(pluralize(count, L["mob"], L["mobs"]))
```

For languages with multiple plural forms (Russian, Polish), this gets harder; AceLocale supports per-key form variants but most addons just pick the dominant form per language and accept some awkwardness.

## Number / date formatting

```lua
FormatLargeNumber(1234567)    -- "1,234,567" or "1 234 567" depending on locale
date("%Y-%m-%d")              -- formatted date string; %X / %x are locale-aware
```

WoW's `BreakUpLargeNumbers(value)` returns the locale-correct big-number formatting (commas, dots, spaces).

## Testing localization without changing client language

Force a non-default locale for testing in your dev addon:

```lua
-- temporary; remove before shipping
local L = MyAddonLocale_frFR  -- pretend we're on frFR
```

Or duplicate strings into a debug locale and switch to that. The proper test is in a real localized client, but this catches obvious string-coverage gaps fast.

## What to localize

- **All user-visible chat output** (`print`, `SendChatMessage`, `RaidNotice_AddMessage`).
- **All UI element text** (button labels, slider titles, options panel descriptions).
- **All tooltip text**.
- **Error messages**.

What NOT to localize:
- Slash command names — `/myaddon` should be the same everywhere; users learn the command.
- Debug/diagnostic output — it's for the developer, not the user.
- Internal protocol strings (addon message payloads, SavedVariables keys).
- Color codes, file paths, identifiers.

## Common pitfalls

- **Concatenating localized strings**: `"You have " .. count .. " items"` — word order varies by language. Use format strings: `L["You have %d items"]:format(count)` so the translator can move `%d` around.
- **Hardcoding spell/item names** — covered above; always use IDs.
- **Forgetting fallback for missing translations** — ensure non-translated keys still produce something readable, ideally the original English.
- **Localizing slash command names** — confuses users sharing macros and posting to forums.
- **Not testing** — at minimum, force-load the frFR locale on enUS client and watch for English text leaking through.
