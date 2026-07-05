---
name: wow-addon-dev
description: This skill should be used when the user wants to "create a WoW addon", "write a World of Warcraft addon", "edit my .toc file", "fix a Lua error in WoW", "debug an addon", "install a WoW addon", "update Interface version", "package an addon", "publish to CurseForge", asks about WoW addon API, taint, secret values, private auras, SavedVariables, Ace3, AceDB, BugSack, encounter detection, slash commands, secure templates, or troubleshoots a specific named addon (ElvUI, WeakAuras, Plater, DBM, BigWigs, Details!, RaiderIO, Auctionator, Bagnon, etc.), or mentions "my addon", an "AddOns folder" issue, addons "disappearing" or "not showing up", an "out of date" warning, or anything related to World of Warcraft addon development and management. Covers retail (Midnight 12.0+), Classic, and addon distribution.
---

# World of Warcraft Addon Development & Management

This skill makes the agent proficient at the full lifecycle of WoW addons: writing them, debugging them, installing them, packaging them, and managing the AddOns folder. Tuned for retail Midnight (Interface 12.0.x) with explicit handling for the breaking changes that arrived with that patch (CLEU removal, Secret Values, private auras), plus Classic variants and multi-version TOCs.

## When this skill applies

Use whenever the user mentions WoW, World of Warcraft, an addon, an `.toc` file, a `.lua` file inside `Interface\AddOns`, BugSack/BugGrabber Lua errors, ElvUI/WeakAuras/DBM/Plater behavior questions, encounter scripting, a `_retail_` or `_classic_` install, `SavedVariables`, slash command registration, taint, or anything that smells like the WoW UI.

## Typical WoW environment

Default install paths (verify with the user — Battle.net lets the install root be customized):

**Windows** (most common):
- WoW root: `C:\Program Files (x86)\World of Warcraft\`
- Editions: `_retail_\`, `_classic_\`, `_classic_era_\`, `_anniversary_\`
- Retail AddOns: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\`
- Per-account SavedVariables: `<root>\_retail_\WTF\Account\<ACCOUNT>\SavedVariables\`
- Per-character SavedVariables: `<root>\_retail_\WTF\Account\<ACCOUNT>\<Realm>\<Character>\SavedVariables\`

**macOS**:
- WoW root: `/Applications/World of Warcraft/`
- Same `_retail_/Interface/AddOns/` and `_retail_/WTF/Account/...` substructure

The PowerShell scripts in `scripts/` accept a `-WowPath` parameter to override the default. On macOS/Linux the same logic ports cleanly to bash; the user can also just point the agent at the right path manually.

If the user has BugSack and BugGrabber installed (very common — they're shipped with most popular addon-manager defaults), `!BugGrabber.lua` in their per-account SavedVariables holds captured Lua errors. `scripts/read-bugsack.ps1` parses that file. Other useful platforms to know: DBM and BigWigs (boss mods), Details! and Skada (damage meters), WeakAuras (custom UI/triggers), Plater (nameplates), ElvUI (full UI replacement), RaiderIO (M+ scoring).

## Workflow router

When the user's request matches a category below, jump straight to the matching reference, then act:

| The user wants to... | Read this reference first |
|---|---|
| Create a brand-new addon from scratch | `references/toc-format.md` + pick a template from `examples/` |
| Fix a TOC error / "out of date" / multi-version support | `references/toc-format.md` |
| Hook game events (encounter, combat, aura, login, zone) | `references/api-events-frames.md` |
| Migrate an addon from pre-Midnight to 12.0+ | `references/midnight-12.md` |
| Diagnose a Lua error from BugSack / a taint complaint | `references/debugging-and-taint.md` |
| Persist settings / debug `MyAddonDB` not loading | `references/savedvariables-and-load-order.md` |
| Use Ace3, AceDB, AceConfig, LibStub | `references/ace3-and-libraries.md` |
| Build UI frames / handle combat lockdown | `references/ui-and-secure-templates.md` |
| Build addon-to-addon comms | `references/api-events-frames.md` (addon message section) |
| Add a slash command / options panel | `references/slash-commands.md` |
| Localize an addon (frFR/deDE/etc., spell-name issues) | `references/localization.md` |
| Publish to CurseForge / WoWInterface / Wago / build a release zip | `references/distribution-and-packaging.md` |
| Avoid the gotchas the CrownCosmosCallout build hit | `references/lessons-from-ccc.md` |

## Core principles to apply

These are the non-obvious lessons baked into this skill — apply them by default unless the task is unambiguously simple.

### 1. Match the addon's Interface version to the user's actual client

Before editing any `.toc`, verify the running interface number. The patch field bumps with every minor patch; an out-of-date addon shows the yellow warning unless "Load out of date AddOns" is checked. Run `scripts/get-interface-version.ps1`, or read `WoW.exe`'s build, or just `select(4, GetBuildInfo())` in-game. For multi-edition addons, use comma-delimited Interface numbers or per-edition TOC files (`MyAddon_Mainline.toc`, `MyAddon_Vanilla.toc`).

### 2. Never read fields off potentially-secret values without a check

Patch 12.0 introduced Secret Values for sensitive combat data. Reading `aura.spellId` on a private aura, comparing `UnitLevel(unit)` directly, or doing arithmetic on `health` from a tainted code path will throw `"attempt to compare/index ... (a secret <type> value tainted by <addon>)"` and *permanently* attribute taint to the addon for the session. The fix:
- For aura presence: `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` — truthy-check only, do NOT read fields off the result.
- For unit numbers in conditionals: `tonumber(UnitLevel(unit))` and `tonumber(UnitReaction("player", unit))` to scrub potential secrets.
- For value-level introspection: bare globals `issecretvalue(x)`, `canaccessvalue(x)`, `scrubsecretvalues(x)`. The separate `C_Secrets.*` namespace exposes per-category visibility checks (auras, cooldowns, etc.). Verify exact names with `/dump _G.<name>` before relying on any specific function — the secrets API is still settling.

CLEU (`COMBAT_LOG_EVENT_UNFILTERED`) does not fire for addon code in 12.0. For damage/healing meters, threat tracking, or unit-targeted aura tracking, use the per-use-case replacements documented in `references/midnight-12.md`. Old addons that registered for CLEU silently stop working.

### 3. Wire `SetScript("OnEvent", ...)` BEFORE any `RegisterEvent`

Some load-time event protections kick in if a frame has registrations with no handler. Pattern:
```lua
local f = CreateFrame("Frame")
local function OnEvent(self, event, ...) ... end
f:SetScript("OnEvent", OnEvent)   -- handler first
f:RegisterEvent("PLAYER_LOGIN")    -- then registrations
```
For taint-sensitive registrations (anything that might run during load), defer with `C_Timer.After(0, function() f:RegisterEvent(...) end)` to push registration to the next frame tick.

### 4. SavedVariables init pattern

`SavedVariables` and `SavedVariablesPerCharacter` from the TOC are only populated when the file referencing them runs AFTER `ADDON_LOADED` (or after the SVs load, which by default is after the last file in TOC). The init pattern:
```lua
MyAddonDB = MyAddonDB or {}
local function db()
    local d = MyAddonDB
    d.foo = d.foo or "default"
    d.list = d.list or {}
    return d
end
```
Don't store frame references, function references, or userdata in saved tables — only plain Lua values (string/number/bool/table). Strings are copied; tables holding only those primitives serialize cleanly.

### 5. Combat lockdown is real

Protected frames (anything inheriting `SecureActionButtonTemplate`, `SecureGroupHeaderTemplate`, etc.) cannot have their attributes, parents, or anchors changed in combat. Check `InCombatLockdown()` first, and queue the change for `PLAYER_REGEN_ENABLED` if locked. Frames you `CreateFrame` yourself with no secure template are unprotected and can be moved/shown/hidden in combat freely.

### 6. Restart > /reload after TOC changes

`/reload` reloads Lua files but *not* the TOC parser's view of the addon. After editing a `.toc` (Interface number, dependencies, file list) the user must fully exit and relaunch WoW. State this explicitly when handing off — it's a routine source of "but it still doesn't work" frustration.

### 7. AddOn message protocol limits

`C_ChatInfo.SendAddonMessage(prefix, text, channel)` has hard limits: prefix ≤ 16 chars, message ≤ 255 chars, 10-message burst with 1/sec refill per prefix. Both sender and receiver must `C_ChatInfo.RegisterAddonMessagePrefix(prefix)` to see traffic. Channel must be one of `RAID`, `PARTY`, `INSTANCE_CHAT`, `GUILD`, `OFFICER`, `WHISPER` (with target name for whisper). Versioning the payload (e.g. `v2:fielda|fieldb`) lets you ship protocol upgrades without breaking peers on the old version.

### 8. Taint avoidance checklist when modifying Blizzard frames

If the addon touches raid frames, action bars, or anything in `Blizzard_*`:
- Only call protected functions out of combat.
- Don't call `securecall(...)` defensively unless taint analysis shows a real leak.
- Hooks should be `hooksecurefunc` (post-hook only, can't change return values, doesn't transfer taint backwards).
- Test with `/console taintLog 1`, reload, repro, then read `WoW\Logs\taint.log` for `blocked` lines.

## Tools to use

### Scripts

These live in `scripts/` and are the deterministic actions the skill performs repeatedly:

- `scripts/list-installed-addons.ps1` — Lists every addon folder in `_retail_\Interface\AddOns` with its TOC `Title`, `Version`, `Interface`, and `Author`. Use to answer "what addons do I have / which are out of date / what version of X is installed".
- `scripts/get-interface-version.ps1` — Returns the current retail/classic interface numbers from the user's installed `Wow.exe` builds. Use to set `## Interface:` correctly.
- `scripts/validate-toc.ps1 <path-to-.toc>` — Validates: file/folder name match, required directives present, Interface number format, no orphan files referenced. Run after every TOC edit.
- `scripts/install-addon.ps1 <source-folder> [-Edition retail|classic]` — Copies an addon folder into the right `Interface\AddOns\` location. Use for local addon installs from a cloned repo or downloaded zip extraction.
- `scripts/read-bugsack.ps1 [-Account NAME]` — Parses `WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua` and prints the most recent Lua errors with full stacks. The fastest path to "what error is the user actually seeing".
- `scripts/package-addon.ps1 <addon-folder> [-Output zip]` — Builds a clean release zip with the standard `AddonName/AddonName.toc` structure. Strips `.git`, dotfiles, `.bak`. Use before manual upload to CurseForge/WoWInterface.
- `scripts/set-interface-version.ps1 <addon-folder> <new-interface>` — Bumps `## Interface:` across every `.toc` in an addon (handles `_Mainline.toc`, `_Vanilla.toc` variants).

### Examples

Working starter templates in `examples/` — copy and adapt rather than write from scratch:

- `examples/MinimalAddon/` — Single-file addon, no libs. Frame + event handler + SavedVariables + slash command. The right starting point for ~80% of new addons.
- `examples/MyAce3Addon/` — Ace3 (`AceAddon-3.0`, `AceEvent-3.0`, `AceDB-3.0`) skeleton with profile-aware DB, options panel via `AceConfig-3.0`, slash command. Use when the addon has more than one config knob.
- `examples/EncounterMod/` — Boss-fight handler: `ENCOUNTER_START`/`ENCOUNTER_END` filtering, hard lockout pattern, `C_Timer.After` with generation counter to invalidate stale callbacks across pulls. Distilled from CrownCosmosCallout.
- `examples/options-panel/` — Modern Settings API panel using `Settings.RegisterCanvasLayoutCategory` + `Settings.OpenToCategory`, with the legacy `InterfaceOptions_AddCategory` fallback for Classic.
- `examples/addon-message/` — Versioned addon-message protocol with prefix registration, payload parsing, and a 1-second resolve window for distributed coordination.
- `examples/multi-version-toc/` — Per-edition TOC files (`_Mainline.toc`, `_Vanilla.toc`, `_Cata.toc`) sharing a Lua core, with conditional file loading via `[AllowLoadGameType ...]`.

## Behavior expectations

- **When the user pastes a Lua error**: jump straight to `references/debugging-and-taint.md` and run `scripts/read-bugsack.ps1` if more context is needed. Don't ask them to paste more — read SavedVariables.
- **When asked to "install this addon"**: use `scripts/install-addon.ps1` after confirming the source path. Always install into `_retail_` unless the user mentions Classic, then ask which edition.
- **When asked to "update my addon for the new patch"**: read the addon's TOC, run `scripts/get-interface-version.ps1`, bump `## Interface:` via `scripts/set-interface-version.ps1`, then scan the Lua for any 12.0-removed APIs from `references/midnight-12.md`.
- **When writing new addon code**: default to single-file Lua (no Ace3) unless the addon has multiple configurable behaviors or needs profile management. Ace3 is the right call for medium+ addons; overkill for one-shots.
- **Always tell the user to fully restart WoW** (not `/reload`) after a TOC edit. After a Lua-only edit, `/reload` is fine.
- **Never claim an addon "should work"** without saying what was tested. If you couldn't run it in-game, say so — the user can run a `/<addon> test` style harness (see the test-harness pattern in `references/lessons-from-ccc.md`).

## Verification before claiming done

Do not report an addon change as working without stating which of these actually ran:

1. **After any `.toc` edit** — run `scripts/validate-toc.ps1 <path-to-.toc>`; expect zero findings. Remind the user a full client restart (not `/reload`) is required.
2. **After Lua edits** — syntax-check if a Lua interpreter is available (`luac -p <file>` or `lua -e "assert(loadfile('<file>'))"`); otherwise re-read the diff for unbalanced `end`s and nil-index risks. In-game: enable `/console scriptErrors 1` (or BugSack), exercise the changed code path, then run `scripts/read-bugsack.ps1` and confirm zero new errors.
3. **After packaging** — open the zip and confirm the top-level structure is `AddonName/AddonName.toc`; a nested or renamed folder will not load.
4. **If in-game testing was not possible** — say so explicitly and offer the slash-command test-harness pattern from `references/lessons-from-ccc.md` ("Test harnesses pay for themselves") so the user can verify with one command.

## Quick wins for common asks

- "Why is my addon out of date?" → Bump `## Interface:` to current; show toggle for "Load out of date AddOns" in the AddOns list.
- "BugSack is showing a `nil value` error" → Run `scripts/read-bugsack.ps1`, identify the file:line, walk through the variable's lifetime (registered? saved variables loaded? event order?).
- "How do I see what raid mark I have?" → `GetRaidTargetIndex("player")` → 1-8 or nil. Don't poll; register `RAID_TARGET_UPDATE`.
- "Can my addon click a button for me?" → Only via `SecureActionButtonTemplate` set up out of combat; you cannot synthesize a click on Blizzard's buttons in combat.
- "How do I send a chat message from my addon?" → `SendChatMessage(text, "RAID")` — but fall back to PARTY/SAY when not in a raid (see CrownCosmosCallout's `SafeSend`).
- "How do I save settings per character vs per account?" → `## SavedVariables: MyAddonDB` (account) vs `## SavedVariablesPerCharacter: MyAddonDB` (character). Pick one; mixing requires AceDB.

