-- Modern Settings API options panel with the legacy InterfaceOptions_AddCategory
-- fallback for Classic. Drop this in a Lua file, register the file in your TOC.

local ADDON_NAME = "MyAddon"

-- Forward-declare so OnShow can call BuildContent before it's defined further
-- down. Useful when assembling diagnostic dumps from late-bound state.
local BuildContent

-- =========================================================================
-- Build the panel frame
-- =========================================================================

local panel = CreateFrame("Frame", ADDON_NAME .. "OptionsPanel")
panel.name = ADDON_NAME

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(ADDON_NAME)

local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
hint:SetText("Click inside the box, Ctrl+A then Ctrl+C to copy.")

-- Scrollable read-only-ish text area for diagnostics.
local scroll = CreateFrame("ScrollFrame", "$parentScroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 16, -56)
scroll:SetPoint("BOTTOMRIGHT", -36, 60)

local edit = CreateFrame("EditBox", nil, scroll)
edit:SetMultiLine(true)
edit:SetFontObject("ChatFontNormal")
edit:SetSize(560, 600)
edit:SetAutoFocus(false)
edit:EnableMouse(true)
edit:SetScript("OnEscapePressed", edit.ClearFocus)
scroll:SetScrollChild(edit)

-- A toggle.
local toggle = CreateFrame("CheckButton", "$parentEnabled", panel, "InterfaceOptionsCheckButtonTemplate")
toggle:SetPoint("BOTTOMLEFT", 16, 30)
_G[toggle:GetName() .. "Text"]:SetText("Enabled")
toggle:SetScript("OnClick", function(self)
    -- example uses MyAddonDB; replace with your own DB
    MyAddonDB = MyAddonDB or {}
    MyAddonDB.enabled = self:GetChecked()
end)

panel:SetScript("OnShow", function()
    MyAddonDB = MyAddonDB or {}
    if MyAddonDB.enabled == nil then MyAddonDB.enabled = true end
    toggle:SetChecked(MyAddonDB.enabled)
    edit:SetText(BuildContent())
    edit:SetCursorPosition(0)
end)

-- =========================================================================
-- Register with the Settings API (12.0+) with a Classic fallback
-- =========================================================================

local optionsCategoryID

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_NAME)
    category.ID = ADDON_NAME
    Settings.RegisterAddOnCategory(category)
    optionsCategoryID = category.ID
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
    optionsCategoryID = panel.name
end

-- Helper to open the panel programmatically (e.g. from a slash command).
local function OpenOptions()
    if Settings and Settings.OpenToCategory and optionsCategoryID then
        Settings.OpenToCategory(optionsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory and panel then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)  -- old API quirk
    end
end

_G[ADDON_NAME .. "_OpenOptions"] = OpenOptions  -- expose if you want to call from /run

-- =========================================================================
-- Diagnostic dump (rebuilt every time the panel opens)
-- =========================================================================

BuildContent = function()
    local _, _, _, ifaceNum = GetBuildInfo()
    return ([[=== %s ===
client interface: %s
player:           %s-%s
GUID:             %s
in raid:          %s   in group: %s

settings:
  enabled:        %s
]]):format(
        ADDON_NAME,
        tostring(ifaceNum),
        UnitName("player") or "?", GetRealmName() or "?",
        UnitGUID("player") or "?",
        tostring(IsInRaid()), tostring(IsInGroup()),
        tostring(MyAddonDB and MyAddonDB.enabled)
    )
end
