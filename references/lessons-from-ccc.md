# Lessons from CrownCosmosCallout (a production addon case study)

Distilled gotchas and patterns from a 1.x production WoW addon — CrownCosmosCallout, an encounter callout for the Crown of the Cosmos boss in The Voidspire (Midnight S1). Each lesson is something hit, debugged, and fixed during real-raid use, not theoretical.

The addon coordinates between multiple raid members running the same addon (so two players targeted by the same mechanic don't pick the same destination), uses private-aura detection (Silverstrike Arrow), and has a built-in test harness. It exercises most of the gnarly parts of modern WoW addon dev in one ~840-line file, which makes it a useful case study even if you're not writing an encounter mod.

## 1. Don't read fields off private aura results

CrownCosmosCallout listens for Alleria's `Silverstrike Arrow` (a Blizzard "private aura" — secret-flagged in 12.0). Naive code:

```lua
-- broken: throws on first cast
for i = 1, 40 do
    local _, _, _, _, _, _, _, _, _, _, spellId = UnitDebuff("player", i)
    if spellId == ARROW_SPELL_ID then
        DoAnnounce()
    end
end
```

Throws `attempt to compare local 'spellId' (a secret number value tainted by 'CrownCosmosCallout')`. Once that happens, the addon is taint-marked for the session and Blizzard hooks may stop calling it.

Working pattern:

```lua
if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
   and C_UnitAuras.GetPlayerAuraBySpellID(ARROW_SPELL_ID) then
    OnArrowDetected()
end
```

`GetPlayerAuraBySpellID` does the spellID match inside Blizzard's own code and returns either the AuraData table or nil. Truthy-check ONLY — never `local x = aura.spellId`.

## 2. Wire OnEvent before RegisterEvent, then defer registrations

CrownCosmosCallout creates its frame and immediately sets the handler:

```lua
local frame = CreateFrame("Frame", "CrownCosmosCalloutEvents")
local function OnEvent(self, event, ...) ... end
frame:SetScript("OnEvent", OnEvent)  -- handler FIRST

-- registrations deferred to next frame tick to sidestep load-time taint
C_Timer.After(0, function()
    for _, ev in ipairs(WANTED_EVENTS) do
        if not frame:IsEventRegistered(ev) then
            frame:RegisterEvent(ev)
        end
    end
end)
```

The `C_Timer.After(0, ...)` defer is the killer detail. Some load-time event protections silently disable a frame whose registrations happen before WoW's full UI init. Pushing to next tick (after all addons have finished their initial Lua execution) avoids the gating.

`UNIT_AURA` registration is special: `frame:RegisterUnitEvent("UNIT_AURA", "player")` is more efficient than `RegisterEvent("UNIT_AURA")` (server filters per-unit instead of dumping every raid member's aura changes). It also seems to be less subject to taint gating than CLEU was — UNIT_AURA still fires after any taint event; CLEU permanently stops.

## 3. Polling as backup for unreliable events

`UNIT_AURA` doesn't always fire when a private aura is applied. Solution: paired with a poll.

```lua
local function PollForArrow()
    if not active or locked or resolveQueued then return end
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
       and C_UnitAuras.GetPlayerAuraBySpellID(ARROW_SPELL_ID) then
        OnArrowDetected("polling")
    end
end
C_Timer.NewTicker(0.2, PollForArrow)
```

The event handler covers the common case (instant detection, low overhead). The 0.2s poll is the safety net. Both gate on `active` (between ENCOUNTER_START and ENCOUNTER_END) so they don't run when irrelevant.

## 4. Generation counters defeat stale C_Timer callbacks

When you queue `C_Timer.After(N, fn)` and then ENCOUNTER_END fires before N seconds elapse, `fn` will still run on the next pull with stale state. The fix:

```lua
local pullGen = 0

local function ResetPull()
    pullGen = pullGen + 1
    -- ... reset other state ...
end

local function OnArrowDetected()
    -- ...
    local gen = pullGen  -- snapshot at queue time
    C_Timer.After(RESOLVE_WAIT, function()
        if pullGen == gen then  -- still my pull?
            DoAnnounce()
        end
        -- else: another pull started; abandon
    end)
end
```

Closures capture `gen` at the time the callback is queued. When the callback finally fires, comparing against the current `pullGen` tells whether intervening `ResetPull()` calls have invalidated this work.

## 5. Snapshot config at broadcast time, not at resolve time

CrownCosmosCallout broadcasts an "intent" message via addon comms, then waits 1s to collect peers' broadcasts before deciding what to announce. Without snapshotting:

```lua
-- broken: user changes /ccc pool between broadcast and resolve, peers see old pool but local code uses new
function ResolveMyPick()
    local pool = db().pool  -- LIVE state; peer thinks I have different pool
    -- ...
end
```

If the user runs `/ccc pool A B` during the 1-second resolve window, peers still hold the OLD pool I broadcast — but my local `db().pool` is now the new value. We desync.

Fix: snapshot at broadcast:

```lua
local myBroadcast = nil

function BroadcastMyIntent()
    local d = db()
    local poolCopy = {}
    for i, v in ipairs(d.pool) do poolCopy[i] = v end
    myBroadcast = { fixed = d.fixed, name = d.fixed or "", pool = poolCopy }
    -- send myBroadcast over addon channel
end

function ResolveMyPick()
    local snap = myBroadcast or { fixed = false, pool = db().pool }
    -- decisions read from snap, not live db
end
```

The general principle: any distributed state that's collected from peers must use the SAME snapshot of local state that peers received. Otherwise late mutations create deterministic disagreements.

## 6. Versioned addon-message protocols enable forward compatibility

CCC went from v1.18 (no `pool` field) to v1.19+ (with `pool`). Old peers send `"P:GUID:r:Vorelus"` (no pool); new send `"P:GUID:r:|Vorelus,Morium"` (pool delimited by `|`).

```lua
local guid, mode, rest = text:match("^P:([^:]+):([fr]):(.*)$")
local name, poolStr = rest:match("^([^|]*)|?(.*)$")  -- optional |pool
local pool
if poolStr ~= "" then
    pool = {}
    for nm in poolStr:gmatch("[^,]+") do pool[#pool+1] = nm end
end
remotePicks[guid] = { fixed = (mode == "f"), name = name, pool = pool }
```

`pool` is `nil` for legacy peers, populated for v1.19+. Resolve logic detects legacy peers and falls back to the older indexed-slot algorithm (which assumed pools matched). New-only deployments use the greedy per-pool algorithm.

When upgrading the protocol:
- Add new fields after old ones (parsing old peers gives `nil` for the new fields).
- Use distinct delimiters for new fields so old parse patterns don't accidentally match.
- Embed a version tag if the change is breaking.
- Keep both code paths until the user base migrates.

## 7. Test harnesses pay for themselves

CCC has `/ccc test`, `/ccc test all`, `/ccc test raid`, `/ccc test live`. Each exercises a different scenario without needing to be in the actual raid:

- `/ccc test` — one-shot announce using local pick logic. Verifies the announce pipeline.
- `/ccc test all` — full battery (fresh pull, wave-2 silent, raid simulation). Takes ~3s.
- `/ccc test raid` — simulates another raider with the addon getting an arrow at the same time. Verifies coordination.
- `/ccc test live` — broadcasts a sync message to all addon users in the actual raid; everyone fires a fake arrow at the same moment. Verifies coordination end-to-end across real machines and real network latency.

Build the test harness as you build the feature. The test code lives in the same file (gated behind a slash-command branch) so it ships with the addon and can be re-run any time. Real callouts go to real raid chat — the test is verifying the entire pipeline including the part that talks to the server.

## 8. Avoid CLEU; use UNIT_AURA on player

CCC's prototype used `COMBAT_LOG_EVENT_UNFILTERED`. After 12.0 it stopped working entirely. The UNIT_AURA-on-player approach has three benefits:
1. CLEU is gone for addons in 12.0+; UNIT_AURA still fires.
2. UNIT_AURA on player only fires for the player's own aura changes — much less noise than CLEU.
3. UNIT_AURA isn't subject to the same per-session gating as CLEU was after `ADDON_ACTION_FORBIDDEN` events.

Whenever the data you need is "did an aura get applied to me / a specific unit", `UNIT_AURA` + `RegisterUnitEvent` is the right answer. Reserve broad event registrations for cases where you genuinely need raid-wide visibility.

## 9. Hard lockouts beat clever per-event guards

CCC has a 50-second hard lockout from ENCOUNTER_START — past 50s, the addon refuses to announce regardless of state. Why?

The boss has multiple Silverstrike waves; we only want the first. Many edge cases could theoretically cause a second-wave aura to slip through:
- `/reload` mid-pull desyncs `firstWaveSeen`
- A peer's broadcast arrives late
- Polling detects an aura that the event handler missed

Trying to enumerate every edge case and gate against it is fragile. The hard lockout is dumb-simple: "after 50s, shut up." Combined with `pullGen` to invalidate it on encounter restart, this is bulletproof:

```lua
if event == "ENCOUNTER_START" then
    -- ...
    local gen = pullGen
    C_Timer.After(HARD_LOCKOUT, function()
        if pullGen == gen then locked = true end
    end)
end
```

The pattern: when correctness depends on "this thing happens at most once per X", set a deterministic time limit and ignore everything past it.

## 10. Prefer single-file addons until they outgrow themselves

CCC is 836 lines of Lua in one file plus a 9-line TOC. There's a temptation to split into:
- `Core.lua` (events)
- `Coordination.lua` (addon comms)
- `UI.lua` (options panel)
- `Test.lua` (test harness)

Resist until it actually helps. Single-file means:
- One `local`-namespaced module; no need for `addon.foo = ...` plumbing.
- Forward declarations stay close to use sites.
- One file to grep when debugging.
- No TOC dependency ordering puzzles.

Split when the file crosses ~1500 lines or when sub-features have genuinely independent reasons to evolve. CCC's 836 lines is comfortably one file.

## 11. Print on load, with diagnostic info

CCC prints on every load:

```
[CrownCosmosCallout] loaded. Pool: Vorelus, Morium. UNIT_AURA: yes. Other events: 3/3.
```

The pool reminds the user what their config is. The event-registration counts confirm the OnEvent-before-RegisterEvent + deferred-registration pattern actually worked — if `0/3` were ever shown, that's an immediate "broken" signal without needing BugSack.

Print in green (`|cff00ff00`) for normal, yellow (`|cffffff00`) for warnings, red (`|cffff4040`) for errors. Diagnostic-style output should go to print, not chat — never `SendChatMessage` for status.

## 12. Provide a `/diag` or `/options` command that opens a copy-pasteable diagnostic dump

CCC's `/ccc diag` opens a Settings panel containing a multi-line EditBox with everything diagnostic:

```
=== Crown Cosmos Callout ===
version: 1.23
client:  12.0.5  interface=120005
player:  Player-Realm
GUID:    Player-1234-ABCDEF
inRaid:  true   inGroup: true

settings:
  fixed:    (none, random)
  pool:     Vorelus, Morium
  channel:  RAID
  onScreen: true

pull state:
  firstWaveSeen: false
  locked:        false
  pullGen:       0
  hardLockout:   50s after ENCOUNTER_START

events (registered yes/no):
  UNIT_AURA (player)              yes
  ENCOUNTER_START                 yes
  ENCOUNTER_END                   yes
  CHAT_MSG_ADDON                  yes

addon msg prefix registered: true
```

When a user reports "it didn't work", they paste this in. You see the full state without a back-and-forth. The EditBox is selectable/copyable; the user does Ctrl+A, Ctrl+C, paste.
