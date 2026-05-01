-- Addon-to-addon messaging example. Versioned protocol with prefix
-- registration, payload parsing, and 1-second resolve window for distributed
-- coordination.

local PREFIX = "MyAddonComms"  -- max 16 chars
local RESOLVE_WAIT = 1.0       -- seconds to collect peer broadcasts

-- =========================================================================
-- Register prefix
-- =========================================================================

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end

-- =========================================================================
-- Send
-- =========================================================================

-- Sample protocol: "v1:GUID:mode:data"
-- - v1 = protocol version (lets us add v2 without breaking peers)
-- - GUID = sender's player GUID (so receivers know who's who)
-- - mode = "f" (fixed pick) or "r" (random)
-- - data = pipe-separated fields specific to the mode

local function BroadcastIntent(mode, data)
    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then return end  -- not grouped; nothing to broadcast to
    local payload = ("v1:%s:%s:%s"):format(UnitGUID("player") or "?", mode, data or "")
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX, payload, channel)
    end
end

-- =========================================================================
-- Receive & parse
-- =========================================================================

local remotePicks = {}  -- [guid] = { mode = "f"/"r", data = string }
local resolveQueued = false

local function ResolveAndAnnounce()
    -- Once the resolve window closes, decide what to do based on collected
    -- remote picks plus your own state.
    -- Example: print everyone's intent.
    print("|cff60c0ff[comms]|r resolved peers:")
    local count = 0
    for guid, info in pairs(remotePicks) do
        count = count + 1
        print(("  %s -> mode=%s data=%q"):format(guid:sub(-8), info.mode, info.data))
    end
    if count == 0 then
        print("  (no other addon users found)")
    end
    -- Reset for next round
    remotePicks = {}
    resolveQueued = false
end

local frame = CreateFrame("Frame", "MyAddonCommsFrame")
frame:SetScript("OnEvent", function(self, event, ...)
    if event ~= "CHAT_MSG_ADDON" then return end
    local prefix, text, channel, sender = ...
    if prefix ~= PREFIX then return end

    -- Parse v1: format
    local version, guid, mode, data = text:match("^v(%d+):([^:]+):([^:]+):(.*)$")
    if not version then return end  -- malformed or future version we don't understand

    if guid == (UnitGUID("player") or "") then return end  -- skip my own echo

    -- Remember peer's intent
    remotePicks[guid] = { mode = mode, data = data }

    -- Open resolve window if not already open
    if not resolveQueued then
        resolveQueued = true
        C_Timer.After(RESOLVE_WAIT, ResolveAndAnnounce)
    end
end)

C_Timer.After(0, function()
    frame:RegisterEvent("CHAT_MSG_ADDON")
end)

-- =========================================================================
-- Trigger via slash command
-- =========================================================================

SLASH_MYCOMMS1 = "/mycomms"
SlashCmdList.MYCOMMS = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "send" then
        BroadcastIntent("r", rest ~= "" and rest or "hello")
        -- Open my own resolve window so I see peers + announce too
        if not resolveQueued then
            resolveQueued = true
            C_Timer.After(RESOLVE_WAIT, ResolveAndAnnounce)
        end
        print("|cff60c0ff[comms]|r broadcast sent. Listening for " .. RESOLVE_WAIT .. "s...")

    elseif cmd == "fixed" then
        if rest == "" then print("|cffff4040[comms]|r usage: /mycomms fixed <name>"); return end
        BroadcastIntent("f", rest)
        if not resolveQueued then
            resolveQueued = true
            C_Timer.After(RESOLVE_WAIT, ResolveAndAnnounce)
        end
        print("|cff60c0ff[comms]|r fixed broadcast sent.")

    else
        print("|cff60c0ff[comms]|r commands:")
        print("  /mycomms send [data]  -- broadcast random intent")
        print("  /mycomms fixed <name> -- broadcast fixed intent")
    end
end

print("|cff00ff00[MyAddonComms]|r loaded. Prefix: " .. PREFIX)
