-- EncounterMod - boss-fight handler skeleton. Distilled from CrownCosmosCallout.
-- Demonstrates the bulletproof per-pull state pattern: ENCOUNTER_START gate +
-- generation counter for stale C_Timer callbacks + hard lockout safety net.

-- Replace these with your boss's actual values:
local TARGET_ENCOUNTER_ID = 3181  -- look up on Wowhead or in DBM module source
local TARGET_SPELL_ID     = 1233602  -- the aura/cast you care about
local SPELL_DISPLAY_NAME  = "ExampleSpell"  -- only used for human-readable output

local WAVE_WINDOW   = 2.0    -- seconds to listen for the first wave
local HARD_LOCKOUT  = 50.0   -- seconds after ENCOUNTER_START past which addon goes silent

EncounterModDB = EncounterModDB or {}
local function db()
    local d = EncounterModDB
    if d.announce == nil then d.announce = true end
    if d.channel  == nil then d.channel  = "PARTY" end
    return d
end

-- =========================================================================
-- Per-pull state
-- =========================================================================

local active        = false  -- true between ENCOUNTER_START and ENCOUNTER_END
local firstWaveSeen = false
local locked        = false
local pullGen       = 0

local function ResetPull()
    pullGen = pullGen + 1
    firstWaveSeen, locked = false, false
end

-- =========================================================================
-- Output helpers
-- =========================================================================

local function ShowOnScreen(text)
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
    else
        UIErrorsFrame:AddMessage(text, 1, 0.8, 0.1, 1, 5)
    end
end

local function SafeSend(text, channel)
    if channel == "RAID" and not IsInRaid() then
        channel = IsInGroup() and "PARTY" or "SAY"
    elseif channel == "PARTY" and not IsInGroup() then
        channel = "SAY"
    end
    SendChatMessage(text, channel)
end

local function DoAnnounce()
    if locked then return end
    locked = true
    local text = SPELL_DISPLAY_NAME .. "!"
    ShowOnScreen(text)
    if db().announce then
        SafeSend(text, db().channel)
    end
end

-- =========================================================================
-- Detection
-- =========================================================================

local function OnSpellDetected()
    if locked then return end
    if not firstWaveSeen then
        firstWaveSeen = true
        local gen = pullGen
        C_Timer.After(WAVE_WINDOW, function()
            if pullGen == gen then locked = true end
        end)
    end
    DoAnnounce()
end

-- =========================================================================
-- Events
-- =========================================================================

local frame = CreateFrame("Frame", "EncounterModEvents")

local function OnEvent(self, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID = ...
        if encounterID ~= TARGET_ENCOUNTER_ID then return end
        active = true
        ResetPull()
        local gen = pullGen
        C_Timer.After(HARD_LOCKOUT, function()
            if pullGen == gen then locked = true end
        end)

    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        if encounterID ~= TARGET_ENCOUNTER_ID then return end
        active = false
        ResetPull()

    elseif event == "UNIT_AURA" then
        if not active or locked then return end
        local unit = ...
        if unit ~= "player" then return end
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
           and C_UnitAuras.GetPlayerAuraBySpellID(TARGET_SPELL_ID) then
            OnSpellDetected()
        end
    end
end

frame:SetScript("OnEvent", OnEvent)
frame:RegisterUnitEvent("UNIT_AURA", "player")

C_Timer.After(0, function()
    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
end)

-- =========================================================================
-- Polling backup
-- =========================================================================

-- UNIT_AURA doesn't always fire reliably for private auras. Poll as backup.
C_Timer.NewTicker(0.2, function()
    if not active or locked then return end
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
       and C_UnitAuras.GetPlayerAuraBySpellID(TARGET_SPELL_ID) then
        OnSpellDetected()
    end
end)

-- =========================================================================
-- Slash command (test harness)
-- =========================================================================

SLASH_ENCMOD1 = "/encmod"
SlashCmdList.ENCMOD = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "test" then
        print("|cff60c0ff[encmod test]|r firing one-shot")
        ShowOnScreen(SPELL_DISPLAY_NAME .. "!")
        SafeSend(SPELL_DISPLAY_NAME .. "!", db().channel)
    elseif msg == "status" then
        print(("|cff00ff00[encmod]|r active=%s firstWave=%s locked=%s pullGen=%d")
            :format(tostring(active), tostring(firstWaveSeen), tostring(locked), pullGen))
    elseif msg == "reset" then
        ResetPull()
        print("|cff00ff00[encmod]|r state reset")
    else
        print("|cff00ff00[encmod]|r commands: /encmod test | status | reset")
    end
end

print("|cff00ff00[EncounterMod]|r loaded.")
