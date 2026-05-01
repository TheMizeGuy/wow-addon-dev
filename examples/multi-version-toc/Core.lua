-- Shared core. Branches on client edition for retail-only / classic-only APIs.

local _, _, _, INTERFACE = GetBuildInfo()
local IS_RETAIL  = INTERFACE >= 100000  -- Dragonflight (10.x) and later
local IS_MIDNIGHT = INTERFACE >= 120000  -- Midnight 12.x

MyAddonDB = MyAddonDB or {}

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local edition = IS_MIDNIGHT and "Midnight"
                     or IS_RETAIL  and "Retail (pre-12)"
                     or "Classic"
        print(("|cff00ff00[MyAddon]|r loaded on %s (interface %d)"):format(edition, INTERFACE))
    end
end)

C_Timer.After(0, function()
    frame:RegisterEvent("PLAYER_LOGIN")
end)
