# Patch 12.0 (Midnight) Migration Guide

Patch 12.0 was the largest addon-impact patch since the Burning Crusade UI rewrite. ~138 global APIs removed, ~153 CVars removed, the entire combat-log path rewritten, and a "Secret Values" mechanism that breaks any addon assuming it can read combat-relevant numbers off Blizzard objects.

## What broke and why

Blizzard introduced **Secret Values** — opaque wrappers around sensitive combat data — to prevent addons from leaking gameplay-impacting information through the UI layer (target health, raid debuff timers on enemies, hidden ability cooldowns, etc.). The wrapper is at the type-system level: any arithmetic, comparison, or string conversion of a secret value throws a Lua error and *taints the addon for the rest of the session*.

Addons that worked for years now fail with messages like:

```
attempt to compare local 'spellId' (a secret number value tainted by 'MyAddon')
```

Once tainted, the offending addon is silently downgraded — Blizzard hooks may refuse to call it, certain events may stop firing for it. The taint is one-way and persists until `/reload`.

## The Secret Values API surface

These functions exist (per Patch 12.0 API documentation) for safely interacting with potentially-secret values. **Verify exact names and signatures with `/dump _G.<name>` in-game before relying on any of them** — the API surface around secrets evolved through 12.0 PTR cycles and minor patch revisions.

Bare globals for value-level introspection:

```lua
issecretvalue(value)        -- true if this specific value is a secret
canaccessvalue(value)       -- true if it can be read/compared without tainting
hasanysecretvalues(table)   -- recursive check on a table
scrubsecretvalues(value)    -- returns nil if secret, original value otherwise
```

The `C_Secrets` namespace exposes per-category visibility checks (e.g. `C_Secrets.IsAuraVisible`, `C_Secrets.IsCooldownVisible`). Names and signatures vary by patch — confirm before use.

Frames expose introspection methods (`HasSecretValues`, `HasSecretAspect`, `IsPreventingSecretValues`) that report whether a given frame's data has been touched by secret values. Again, verify exact methods on your frame instances with `/dump frame:HasSecretValues` before depending on them.

## Defensive read pattern

Wrap every read of a possibly-secret field:

```lua
-- BEFORE (taints on private aura)
local _, _, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HARMFUL")
if spellId == 12345 then ... end

-- AFTER (safe — no field access)
if C_UnitAuras.GetPlayerAuraBySpellID(12345) then ... end
```

For unit numerics that COULD be secret (level, reaction on enemies):
```lua
-- BEFORE (taints on enemy units that have hidden level)
if UnitLevel(unit) >= 60 then ... end

-- AFTER (scrubs to nil if secret, then nil-check)
local lvl = tonumber(UnitLevel(unit))
if lvl and lvl >= 60 then ... end
```

The `tonumber()` wrap is the canonical "scrub" — secret numbers fail `tonumber` and return nil, leaving the comparison falsy without throwing.

## CLEU is gone for addons

`COMBAT_LOG_EVENT_UNFILTERED` does not fire for addon code in 12.0. `CombatLogGetCurrentEventInfo()` is unavailable to tainted (addon) code. Addons that registered for CLEU silently stop receiving events — no error, just nothing.

### Replacements by use case

| What CLEU was used for | What to use in 12.0+ |
|---|---|
| Damage / healing meter | The built-in damage meter namespace (likely named `C_DamageMeter` — verify in-game with `/dump _G.C_DamageMeter`). No general per-event replacement; addons read aggregate session data. |
| Combat text on screen | Investigate `C_CombatText` (verify availability and surface area). |
| Loss-of-control on the player | `C_LossOfControl` (existed pre-12.0; covers player-only LoC events; not a general raid-wide LoC replacement). |
| Threat / aggro | `UnitThreatSituation`, `UnitDetailedThreatSituation`, `THREAT_LIST_UPDATE` |
| Aura applied/removed on a unit | `UNIT_AURA` (with `RegisterUnitEvent`) + `C_UnitAuras` queries |
| Spell cast detection | `UNIT_SPELLCAST_SUCCEEDED`, `UNIT_SPELLCAST_START` |
| Boss-fight timing | `ENCOUNTER_START`/`ENCOUNTER_END` + boss-emote events |

For raid-wide loss-of-control tracking, debuff aggregation across multiple units, or generic "log every combat event" use cases, there is no clean replacement — these features are gone for addons by design. Boss mods reconstruct what they need from `UNIT_AURA`, boss-emote events, and per-encounter `ENCOUNTER_TIMELINE_*` data.

### Boss mods

Pure CLEU-driven boss mods don't work. DBM and BigWigs both shipped 12.0-compatible versions that use:
- `ENCOUNTER_TIMELINE_*` events for upcoming-mechanic announcements (server-pushed timeline)
- `CHAT_MSG_RAID_BOSS_EMOTE` and `CHAT_MSG_MONSTER_YELL` for transition triggers
- `UNIT_SPELLCAST_SUCCEEDED` filtered to boss casters
- Boss aura events via `UNIT_AURA` on boss unit IDs

Replicating CLEU functionality via these is feasible but requires per-encounter scripting; there's no general-purpose replacement.

## Removed and renamed APIs

The full list is at the [Patch 12.0.0/API changes wiki page](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes). Most-impactful removals:

### Combat / spell

| Removed | Replacement |
|---|---|
| `COMBAT_LOG_EVENT_UNFILTERED` | (no general replacement; see CLEU section above) |
| `CombatLogGetCurrentEventInfo` | (no replacement for addons) |
| `GetSpellInfo(id)` | `C_Spell.GetSpellInfo(id)` returns table |
| `GetSpellCooldown(id)` | `C_Spell.GetSpellCooldown(id)` returns DurationObject |
| `GetSpellTexture(id)` | `C_Spell.GetSpellTexture(id)` |
| `GetSpellLink(id)` | `C_Spell.GetSpellLink(id)` |
| `IsUsableSpell(id)` | `C_Spell.IsSpellUsable(id)` |

### Action bars

| Removed | Replacement |
|---|---|
| `GetActionInfo(slot)` | `C_ActionBar.GetActionInfo(slot)` |
| `GetActionTexture(slot)` | `C_ActionBar.GetActionTexture(slot)` |
| `IsCurrentAction(slot)` | `C_ActionBar.IsActionCurrent(slot)` |

### Addon management

| Removed | Replacement |
|---|---|
| `LoadAddOn(name)` | `C_AddOns.LoadAddOn(name)` |
| `IsAddOnLoaded(name)` | `C_AddOns.IsAddOnLoaded(name)` |
| `GetAddOnInfo(idx)` | `C_AddOns.GetAddOnInfo(idx)` |
| `GetNumAddOns()` | `C_AddOns.GetNumAddOns()` |
| `GetAddOnDependencies(idx)` | `C_AddOns.GetAddOnDependencies(idx)` |
| `GetAddOnEnableState(char, idx)` | `C_AddOns.GetAddOnEnableState(char, idx)` |

(Note: most `C_AddOns` namespace functions actually appeared in 10.2; 12.0 fully removed the deprecated aliases.)

### UI

| Removed | Replacement |
|---|---|
| `InterfaceOptions_AddCategory(panel)` | `Settings.RegisterCanvasLayoutCategory(frame, name)` + `Settings.RegisterAddOnCategory(category)` |
| `InterfaceOptionsFrame_OpenToCategory(panel)` | `Settings.OpenToCategory(categoryID)` |
| `GameTooltip:SetSpell(...)` legacy variants | `GameTooltip:SetSpellByID(spellID)` |

### New 12.0 APIs to know about

These are the families of new APIs Patch 12.0 introduced. **Spelling and signatures change between PTR builds and live patches** — verify each with `/dump _G.<name>` or against the [current API changes wiki page](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes) before depending on it:

- **Heal-prediction calculator object**: a sandboxed object that replaces ad-hoc `UnitGetIncomingHeals` math while respecting secret-value protections. Constructed via a `Create...` global; method names typically include `:Calculate(now)`.
- **`C_CurveUtil` namespace**: sandboxed curve evaluation for stat scaling and color interpolation. Direct math on potentially-secret health/scaling values would taint; the `Curve` and `ColorCurve` objects let Blizzard do the math safely.
- **`C_ColorUtil` namespace**: HSL/HSV/RGB conversions that don't require addons to do their own arithmetic on potentially-secret color values.
- **`DurationObject`**: a new type returned by cooldown queries instead of raw `(start, duration)` tuples. Has methods like `:GetTimeRemaining()` and `:IsExpired()`. Replaces the old multi-return pattern from `GetSpellCooldown`.

The general pattern: when 12.0 wants to give an addon access to a derived value that could leak secret data, it returns an opaque object with safe accessor methods instead of the raw numbers.

## Spell whitelisting

12.0 also added per-spell addon-API restrictions: certain spells (mostly hidden gameplay mechanics) are now flagged "secret" individually. Even if you have the spellID, queries about that spell return secret values.

Blizzard publishes a partial whitelist of player-buff spells that remain fully addon-readable. Anything not on the whitelist may degrade to secret. Practical rule: assume any aura applied by a boss, dungeon mechanic, or PvP scenario could be private; design for graceful degradation.

## Migration checklist

When updating a pre-12.0 addon:

1. **Bump `## Interface:` to `120005`** (or current; check `select(4, GetBuildInfo())` in-game).
2. **Grep for `COMBAT_LOG_EVENT_UNFILTERED`** and replace with use-case-specific alternative or remove the feature.
3. **Grep for `LoadAddOn`, `IsAddOnLoaded`, `GetSpellInfo`, `GetSpellCooldown`** as bare globals — prefix with `C_AddOns.` / `C_Spell.`.
4. **Grep for direct field reads on aura tables** (`.spellId`, `.duration`, `.expirationTime` after `UnitAura`/`UnitDebuff`) — refactor to `GetPlayerAuraBySpellID` truthy-check or scrub-and-nil-check.
5. **Wrap `UnitLevel`, `UnitReaction`, `UnitHealth`** results in `tonumber()` if they feed into comparisons that affect addon behavior.
6. **Replace `InterfaceOptions_AddCategory`** with `Settings.RegisterCanvasLayoutCategory` (keep the old call as a fallback for Classic).
7. **Test with `/console taintLog 1`**, reload, exercise the addon in combat, then `WoW\Logs\taint.log` for `blocked` lines.
8. **Run BugSack** and watch for "secret value" or "ADDON_ACTION_FORBIDDEN" errors during a test pull.

## Detection helpers

Add a build gate to your addon:

```lua
local _, _, _, interfaceNum = GetBuildInfo()
local IS_MIDNIGHT = interfaceNum >= 120000

if IS_MIDNIGHT then
    -- modern path
else
    -- legacy fallback for Classic editions
end
```

This lets a single multi-edition addon ship code that works across retail and Classic without separate TOC files.
