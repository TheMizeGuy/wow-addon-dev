# API: Events, Frames, Timers, Addon Messages

Procedural reference for how an addon talks to the game.

## Frames are the substrate

Almost everything an addon does — listening for events, drawing UI, running timers — flows through a Frame. `CreateFrame(frameType, name, parent, template)` returns a frame object.

```lua
local f = CreateFrame("Frame", "MyAddonEventFrame")
```

- `name` — global name (optional but useful for `/dump _G.MyAddonEventFrame`).
- `parent` — anchor target; defaults to `UIParent`.
- `template` — XML template name; rarely needed for non-UI frames.

Frame types: `Frame`, `Button`, `CheckButton`, `EditBox`, `Slider`, `StatusBar`, `ScrollFrame`, `Cooldown`, `MessageFrame`, `Model`, `PlayerModel`, `DressUpModel`, `Texture` (via `:CreateTexture`), `FontString` (via `:CreateFontString`).

## The event handler pattern

```lua
local f = CreateFrame("Frame")

local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- one-time setup
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName, difficultyID, groupSize = ...
    end
end

f:SetScript("OnEvent", OnEvent)        -- handler FIRST
f:RegisterEvent("PLAYER_LOGIN")        -- registrations AFTER
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ENCOUNTER_START")
```

Why handler first: some load-time event protections silently disable a frame that has registrations but no handler. The order is cheap to get right; getting it wrong loses events without an error.

## Unit events: scope to one unit

`RegisterUnitEvent` filters server-side, dramatically reducing event volume:

```lua
f:RegisterUnitEvent("UNIT_AURA", "player")          -- one unit
f:RegisterUnitEvent("UNIT_HEALTH", "player", "pet") -- multiple units
```

Use this for `UNIT_AURA`, `UNIT_HEALTH`, `UNIT_POWER_UPDATE`, `UNIT_SPELLCAST_*` — anything where you only care about a specific unit. `RegisterEvent("UNIT_AURA")` fires for *every* unit in the raid; that's almost never what you want.

## Common events cheat sheet

| Event | When | First arg |
|---|---|---|
| `ADDON_LOADED` | An addon's files have run | `addonName` |
| `PLAYER_LOGIN` | Initial login complete, before world load | (none) |
| `PLAYER_ENTERING_WORLD` | Each zone load / reload | `isInitialLogin, isReloadingUi` |
| `PLAYER_LOGOUT` | Last chance before SVs save | (none) |
| `PLAYER_REGEN_ENABLED` | Combat ended | (none) |
| `PLAYER_REGEN_DISABLED` | Combat started | (none) |
| `ENCOUNTER_START` | Boss pulled | `encounterID, encounterName, difficultyID, groupSize` |
| `ENCOUNTER_END` | Boss died/wiped | `encounterID, encounterName, difficultyID, groupSize, success` |
| `UNIT_AURA` | Unit's auras changed (use `RegisterUnitEvent`) | `unit, updateInfo` |
| `UNIT_SPELLCAST_SUCCEEDED` | Cast finished | `unit, castGUID, spellID` |
| `CHAT_MSG_ADDON` | Addon message received | `prefix, text, channel, sender` |
| `CHAT_MSG_RAID_BOSS_EMOTE` | Boss emote text | `text, sender, lang, channel, target, ...` |
| `RAID_TARGET_UPDATE` | Raid icon assignment changed | (none) |
| `GROUP_ROSTER_UPDATE` | Party/raid composition changed | (none) |
| `LOOT_OPENED` | Loot window opened | `autoloot` |
| `BAG_UPDATE` | Bag contents changed | `bagID` |

Full list: in-game `/eventtrace` shows live events as they fire.

## Encounter detection pattern

The robust pattern, distilled from CrownCosmosCallout:

```lua
local TARGET_ENCOUNTER_ID = 3181  -- look up on Wowhead or DBM module

local active = false
local pullGen = 0  -- bumps each pull to invalidate stale C_Timer.After callbacks

local function ResetPull()
    pullGen = pullGen + 1
    -- reset any wave/state booleans here
end

local function OnEvent(self, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID = ...
        if encounterID ~= TARGET_ENCOUNTER_ID then return end
        active = true
        ResetPull()
        local gen = pullGen
        C_Timer.After(50, function()
            if pullGen == gen then
                -- still the same pull, do hard-lockout work
            end
        end)
    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        if encounterID ~= TARGET_ENCOUNTER_ID then return end
        active = false
        ResetPull()
    end
end
```

The `pullGen` generation counter lets pending `C_Timer.After` callbacks tell whether they're stale across pulls — without this, a callback queued on pull 1 will fire on pull 2 with stale state.

## Aura detection (12.0+)

Don't read fields off `UnitAura` results — they may be secret values. Truthy-check only:

```lua
-- WRONG (taints addon if aura is private):
local _, _, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i)
if spellId == TARGET_SPELL_ID then ... end

-- RIGHT (no field access):
if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
   and C_UnitAuras.GetPlayerAuraBySpellID(TARGET_SPELL_ID) then
    -- aura is up; we don't know its details, but presence is enough
end
```

`GetPlayerAuraBySpellID` returns the AuraData table or nil. Compare nothing on the result; just check truthiness.

For non-private auras (most buffs/debuffs), the older API works fine but `C_UnitAuras.GetAuraDataBySpellName` is the modern path.

## Timers

`C_Timer.After(seconds, callback)` — one-shot. `C_Timer.NewTicker(seconds, callback, [iterations])` — repeating; returns a ticker you can `:Cancel()`.

```lua
C_Timer.After(1.5, function() print("1.5s later") end)

local ticker = C_Timer.NewTicker(0.2, function() PollSomething() end)
-- later:
ticker:Cancel()
```

Sub-frame precision is not guaranteed. Minimum tick is roughly the frame duration (~16ms at 60 FPS). For polling that needs to fire at most once per frame, use `OnUpdate` on a frame:

```lua
local elapsed = 0
f:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed > 0.2 then
        elapsed = 0
        PollSomething()
    end
end)
```

## Addon messages: addon-to-addon comms

The mechanism for two instances of your addon (in the same group) to talk to each other.

### Sending

```lua
local PREFIX = "MyAddonPrfx"  -- max 16 chars

-- One-time registration (anywhere on load):
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- Send:
local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
if channel then
    C_ChatInfo.SendAddonMessage(PREFIX, "v2:hello world", channel)
end
```

### Receiving

```lua
f:RegisterEvent("CHAT_MSG_ADDON")
-- in OnEvent:
if event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, sender = ...
    if prefix ~= PREFIX then return end
    if sender == UnitName("player") then return end  -- skip echo
    -- parse text
end
```

### Limits

- Prefix: ≤ 16 chars. Any longer is silently truncated.
- Message: ≤ 255 chars per send. Split larger payloads.
- Rate: 10-message burst, refilling at 1/sec per prefix. Bursting past triggers throttle (silent drops or error).
- Visibility: only addons that registered the prefix see the message. The chat window doesn't show it.
- Sender format: `Name-Realm` for cross-realm, `Name` for same-realm. Use `UnitGUID` if you need a stable identifier (account-bound, not a name).
- Channels: `RAID`, `PARTY`, `INSTANCE_CHAT`, `GUILD`, `OFFICER`, `WHISPER` (with target). `RAID` falls back to silent failure if not in a raid; check first.

### Versioning the protocol

Embed a version tag so future protocol changes don't break old peers:

```lua
-- Send v2 with new field
SendAddonMessage(PREFIX, "v2:" .. guid .. ":" .. mode .. "|" .. extraField, channel)

-- Receive: support both v1 and v2 formats
local v, payload = text:match("^v(%d+):(.*)$")
if not v then payload = text end  -- legacy
```

## Slash commands

```lua
SLASH_MYADDON1 = "/myaddon"
SLASH_MYADDON2 = "/ma"
SlashCmdList.MYADDON = function(msg, editBox)
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    -- dispatch
end
```

The `MYADDON` after `SlashCmdList.` must match the suffix of `SLASH_MYADDON1`. Multiple aliases via `SLASH_MYADDON2`, `SLASH_MYADDON3`, etc.

## Print and chat output

```lua
-- to your default chat frame
print("|cff00ff00[MyAddon]|r loaded")

-- to a specific frame
DEFAULT_CHAT_FRAME:AddMessage("text", 1, 1, 0)  -- yellow

-- to a chat channel (visible to others)
SendChatMessage("text", "RAID")  -- channel: SAY/YELL/PARTY/RAID/INSTANCE_CHAT/GUILD/OFFICER/WHISPER

-- on-screen popup (raid-warning style)
RaidNotice_AddMessage(RaidWarningFrame, "text", ChatTypeInfo["RAID_WARNING"])

-- error frame (red flashing)
UIErrorsFrame:AddMessage("text", 1, 0.1, 0.1, 1, 5)  -- r,g,b,id,duration
```

Color codes: `|cAARRGGBB...|r` where `AA` is alpha (usually `ff`). `|cff00ff00green|r`, `|cffff4040red|r`, `|cff60c0ffcyan|r`.

## Group / raid info

```lua
IsInGroup()           -- true if in party or raid
IsInRaid()            -- true only if in raid
GetNumGroupMembers()  -- size of party/raid (1 if solo)

UnitName("player")
UnitGUID("player")    -- "Player-1234-ABCDEF12" stable across renames
GetRealmName()
UnitClass("player")   -- localizedClass, fileClass, classID

UnitInRaid("Bob")     -- index 1-40 if in raid, else nil
UnitInParty("Bob")    -- bool

for i = 1, GetNumGroupMembers() do
    local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
    -- last party slot ("party" .. GetNumGroupMembers()) doesn't include the player; "player" is implicit
end
```

## Combat lockdown gate

Before mutating any protected/secure frame:

```lua
if InCombatLockdown() then
    -- defer
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- in handler, do the work and unregister
else
    -- do it now
end
```

## Game state queries

```lua
GetTime()                          -- monotonic seconds since session start; for elapsed measurement
GetServerTime()                    -- unix timestamp; for absolute time
date("%Y-%m-%d %H:%M:%S")          -- formatted local time
GetBuildInfo()                     -- version, build, datestr, interfaceNumber
C_AddOns.IsAddOnLoaded("Other")    -- detect peer addons (returns loadedOrLoading, loaded)
GetAddOnMetadata("MyAddon", "Version")  -- read your own TOC at runtime
```

`C_AddOns.LoadAddOn(name)`, `C_AddOns.IsAddOnLoaded(name)`, `C_AddOns.GetNumAddOns()`, `C_AddOns.GetAddOnInfo(idxOrName)` — the modern namespace as of patch 10.2.0. Old globals `LoadAddOn`/`IsAddOnLoaded` are deprecated aliases that may be removed.
