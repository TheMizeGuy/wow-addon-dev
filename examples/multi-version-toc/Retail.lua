-- Retail-only code. Loaded only when [AllowLoadGameType mainline] is satisfied
-- by the running client.

-- Use modern C_AddOns namespace freely; it's available on retail.
print(("|cff00ff00[MyAddon]|r retail features active. (%d addons loaded)")
    :format(C_AddOns.GetNumAddOns()))
