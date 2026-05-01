-- Vanilla/TBC code. Loaded only when [AllowLoadGameType vanilla, tbc] is
-- satisfied. The C_AddOns namespace doesn't exist on Vanilla; use legacy
-- globals here (or a polyfill at the top of Core.lua).

local n = (GetNumAddOns and GetNumAddOns()) or (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
print(("|cff00ff00[MyAddon]|r classic features active. (%d addons loaded)"):format(n))
