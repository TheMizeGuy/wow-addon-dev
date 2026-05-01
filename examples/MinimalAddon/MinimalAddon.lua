-- MinimalAddon - minimal single-file addon template.
-- Demonstrates: SavedVariables init, frame + event handler, slash command,
-- coloured print output, deferred event registration.
--
-- To use: rename this folder + its TOC + this file + the SavedVariables
-- global to your real addon name (folder name and TOC base must match).

local ADDON_NAME = "MinimalAddon"

-- =========================================================================
-- SavedVariables
-- =========================================================================

MinimalAddonDB = MinimalAddonDB or {}

local function db()
    local d = MinimalAddonDB
    if d.enabled  == nil then d.enabled  = true end
    if d.greeting == nil then d.greeting = "Hello, %s!" end
    if d.count    == nil then d.count    = 0 end
    return d
end

-- =========================================================================
-- Events
-- =========================================================================

local frame = CreateFrame("Frame", ADDON_NAME .. "EventFrame")

local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local d = db()
        d.count = d.count + 1
        local greeting = d.greeting:format(UnitName("player") or "stranger")
        print(("|cff00ff00[%s]|r %s (login #%d)"):format(ADDON_NAME, greeting, d.count))
    elseif event == "PLAYER_REGEN_DISABLED" then
        if db().enabled then
            print(("|cffffff00[%s]|r combat started."):format(ADDON_NAME))
        end
    end
end

frame:SetScript("OnEvent", OnEvent)

-- Defer registrations to next frame tick to sidestep load-time taint.
C_Timer.After(0, function()
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
end)

-- =========================================================================
-- Slash command
-- =========================================================================

SLASH_MINIMALADDON1 = "/minimaladdon"
SLASH_MINIMALADDON2 = "/mn"
SlashCmdList.MINIMALADDON = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    local d = db()

    if cmd == "" or cmd == "help" then
        print(("|cff00ff00[%s]|r commands:"):format(ADDON_NAME))
        print("  /minimaladdon toggle on|off  -- enable/disable")
        print("  /minimaladdon greeting <fmt> -- greeting format string (use %s for name)")
        print("  /minimaladdon status         -- show current settings")
        print("  /minimaladdon reset          -- reset count to 0")

    elseif cmd == "toggle" then
        local v = rest:lower()
        if v == "on" or v == "1" or v == "true" then
            d.enabled = true
            print(("|cff00ff00[%s]|r enabled."):format(ADDON_NAME))
        elseif v == "off" or v == "0" or v == "false" then
            d.enabled = false
            print(("|cff00ff00[%s]|r disabled."):format(ADDON_NAME))
        else
            print(("|cffff4040[%s]|r toggle requires 'on' or 'off'."):format(ADDON_NAME))
        end

    elseif cmd == "greeting" then
        if rest == "" then
            print(("|cffff4040[%s]|r greeting format required."):format(ADDON_NAME))
        else
            d.greeting = rest
            print(("|cff00ff00[%s]|r greeting set."):format(ADDON_NAME))
        end

    elseif cmd == "status" then
        print(("|cff00ff00[%s]|r enabled=%s greeting=%q count=%d")
            :format(ADDON_NAME, tostring(d.enabled), d.greeting, d.count))

    elseif cmd == "reset" then
        d.count = 0
        print(("|cff00ff00[%s]|r count reset."):format(ADDON_NAME))

    else
        print(("|cffff4040[%s]|r unknown command. Try /minimaladdon help."):format(ADDON_NAME))
    end
end
