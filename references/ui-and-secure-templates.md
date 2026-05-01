# UI Frames, Settings Panels, Secure Templates

The UI half of addon development. Frames, anchors, fonts, textures, buttons, and the rules around what you can do in combat.

## Frame anchors

Every frame needs at least one anchor (`:SetPoint`). Anchors specify how the frame attaches to a parent (or sibling) frame.

```lua
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
-- argument 1: anchor point on this frame
-- argument 2: relative-to frame (defaults to parent if omitted)
-- argument 3: anchor point on the relative frame
-- arguments 4, 5: x, y offset

-- shorthand:
frame:SetPoint("CENTER")  -- equivalent to ("CENTER", parent, "CENTER", 0, 0)
```

Anchor points: `TOPLEFT`, `TOP`, `TOPRIGHT`, `LEFT`, `CENTER`, `RIGHT`, `BOTTOMLEFT`, `BOTTOM`, `BOTTOMRIGHT`.

Multiple `SetPoint` calls combine — a frame anchored TOPLEFT and BOTTOMRIGHT to the same parent stretches with it. Use `:ClearAllPoints()` before re-anchoring to avoid mixing.

```lua
frame:ClearAllPoints()
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -16)
frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
```

`UIParent` is the canonical "screen-sized" parent. Use it for top-level windows.

## Font strings

```lua
local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
fs:SetPoint("CENTER")
fs:SetText("Hello")
fs:SetTextColor(1, 1, 0, 1)  -- yellow
fs:SetJustifyH("CENTER")
fs:SetWidth(200)
fs:SetWordWrap(true)
```

Layer values: `BACKGROUND`, `BORDER`, `ARTWORK`, `OVERLAY`, `HIGHLIGHT`. Higher layers draw on top.

Built-in font objects (font + size + outline preset):
- `GameFontNormal` (default white)
- `GameFontHighlight` (slightly brighter)
- `GameFontHighlightLarge`, `GameFontNormalLarge`, `GameFontHighlightSmall`
- `ChatFontNormal`, `ChatFontSmall`
- `Game24Font`, `Game18Font`, `Game12Font`

For a custom font:
```lua
fs:SetFont("Interface\\AddOns\\MyAddon\\fonts\\Roboto.ttf", 14, "OUTLINE")
```

## Textures

```lua
local tex = frame:CreateTexture(nil, "BACKGROUND")
tex:SetAllPoints()                    -- fills the frame
tex:SetTexture("Interface\\Buttons\\WHITE8x8")
tex:SetVertexColor(0, 0, 0, 0.7)      -- black, 70% alpha
```

Texture modes:
- File path: `Interface\Icons\INV_Misc_QuestionMark` (WoW omits `.blp` extension automatically)
- Color block: `Interface\Buttons\WHITE8x8` + `SetVertexColor` for a solid colored panel
- Atlas: `tex:SetAtlas("worldquest-icon-pvp")` — use atlases for Blizzard UI consistency

`tex:SetTexCoord(left, right, top, bottom)` crops the texture (values 0-1).

## Backdrops (Dragonflight+)

Old `frame:SetBackdrop(...)` was deprecated; use `BackdropTemplate`:

```lua
local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
frame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0, 0, 0, 0.8)
frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
```

For a simpler look, skip backdrops and stack a `BACKGROUND` texture under your content.

## Buttons

```lua
local btn = CreateFrame("Button", "MyButton", parent, "UIPanelButtonTemplate")
btn:SetSize(120, 24)
btn:SetPoint("CENTER")
btn:SetText("Click me")
btn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        print("clicked")
    end
end)
```

`UIPanelButtonTemplate` gives you Blizzard's standard button look. For a flat custom button, use `Button` with no template, attach textures yourself.

## EditBox (text input)

```lua
local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
edit:SetSize(200, 24)
edit:SetPoint("CENTER")
edit:SetAutoFocus(false)
edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
edit:SetText("default")
edit:HighlightText()  -- select all
```

For multi-line input, omit the template and:

```lua
local edit = CreateFrame("EditBox", nil, parent)
edit:SetMultiLine(true)
edit:SetFontObject("ChatFontNormal")
edit:SetSize(560, 600)
edit:EnableMouse(true)
edit:SetAutoFocus(false)
```

Pair with a ScrollFrame for long text.

## Scrollable text panel

```lua
local scroll = CreateFrame("ScrollFrame", "$parentScroll", parent, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 16, -16)
scroll:SetPoint("BOTTOMRIGHT", -36, 16)  -- leave room for scrollbar

local content = CreateFrame("EditBox", nil, scroll)
content:SetMultiLine(true)
content:SetFontObject("ChatFontNormal")
content:SetSize(560, 600)
content:SetAutoFocus(false)
scroll:SetScrollChild(content)

content:SetText(longText)
```

`$parentScroll` is a name-template substitution — at runtime, `$parent` resolves to the parent frame's name.

## Settings API (12.0+)

The modern way to register an options panel that appears in Escape → Options → AddOns:

```lua
local panel = CreateFrame("Frame")
panel.name = "MyAddon"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("MyAddon")

-- ... add controls (check buttons, sliders) anchored within panel ...

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "MyAddon")
    category.ID = "MyAddon"
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    -- Classic / pre-12.0 fallback
    InterfaceOptions_AddCategory(panel)
end
```

Open programmatically:
```lua
if Settings and Settings.OpenToCategory then
    Settings.OpenToCategory("MyAddon")  -- the category ID
elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory("MyAddon")
    InterfaceOptionsFrame_OpenToCategory("MyAddon")  -- double-call quirk for old API
end
```

`Settings.RegisterVerticalLayoutCategory` is the simpler alternative for non-canvas layouts (auto-arranges checkboxes/sliders).

## Combat lockdown

Three categories of frame:

1. **Insecure frames** — anything you `CreateFrame("Frame", ...)` with no template. Fully mutable in or out of combat.
2. **Inheriting templates** — like `BackdropTemplate`, `UIPanelButtonTemplate`. Insecure unless they explicitly inherit a `Secure*Template`.
3. **Secure frames** — inherit `SecureActionButtonTemplate`, `SecureGroupHeaderTemplate`, `SecureUnitButtonTemplate`, etc. **Cannot be mutated in combat.**

Forbidden in combat (on protected frames or their parents/anchors):
- `:Hide()`, `:Show()` (use `:SetAlpha(0)` on insecure parents instead)
- `:SetSize`, `:SetWidth`, `:SetHeight`
- `:SetPoint`, `:ClearAllPoints`
- `:SetParent`
- `:SetAttribute(...)` (most common combat-locked operation)

The defer pattern:

```lua
local pendingChanges = {}

local function ApplyChange(thunk)
    if InCombatLockdown() then
        pendingChanges[#pendingChanges+1] = thunk
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        thunk()
    end
end

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        for _, thunk in ipairs(pendingChanges) do thunk() end
        pendingChanges = {}
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)

-- usage:
ApplyChange(function() myButton:SetAttribute("type", "macro") end)
```

## Secure templates: clicking buttons safely

To make a button cast a spell or run a macro, you cannot just `:SetScript("OnClick", function() CastSpellByName(...) end)` — that fails with `ADDON_ACTION_FORBIDDEN` because casting is a protected action.

Use `SecureActionButtonTemplate` and set attributes:

```lua
local btn = CreateFrame("Button", "MyCastButton", UIParent, "SecureActionButtonTemplate")
btn:SetSize(40, 40)
btn:SetPoint("CENTER")
btn:RegisterForClicks("AnyDown")
btn:SetAttribute("type", "spell")
btn:SetAttribute("spell", "Frostbolt")
-- now left-clicking the button casts Frostbolt as if you'd clicked an action bar slot
```

Other types:
- `"macro"` + `"macrotext"` — runs an inline macro
- `"item"` + `"item"` — uses an item by name
- `"target"` + `"unit"` — selects a unit
- `"action"` + `"action"` — triggers an action bar slot

The catch: attributes can ONLY be set out of combat. So set them up before combat starts.

## Hiding Blizzard frames

The wrong way:
```lua
ChatFrame1:Hide()  -- might cause Hide-while-protected errors elsewhere
```

The right way:
```lua
ChatFrame1:SetAlpha(0)
ChatFrame1:EnableMouse(false)
```

Or strip its anchors so it's effectively invisible:
```lua
ChatFrame1:ClearAllPoints()
ChatFrame1:SetPoint("CENTER", UIParent, "CENTER", -10000, -10000)
```

For some frames there are explicit override APIs (`HideUIPanel`, etc). Check the wiki before brute-forcing.

## Custom positioning the user can drag

```lua
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    MyAddonDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end)

-- restore on load:
local pos = MyAddonDB.position
if pos then
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
end
```

## Common UI utility frames

| Frame | Purpose |
|---|---|
| `UIParent` | Screen-sized root for unparented windows |
| `WorldFrame` | The 3D viewport behind the UI |
| `RaidWarningFrame` | Red boss-emote-style flashing message at top of screen (`RaidNotice_AddMessage`) |
| `UIErrorsFrame` | Red error text mid-screen (`AddMessage(text, r, g, b, id, duration)`) |
| `DEFAULT_CHAT_FRAME` | The user's main chat window |
| `GameTooltip` | The standard tooltip — call `:Show` after `:SetOwner(...)` and `:AddLine` |
| `MainMenuBar`, `ChatFrame1`, `MinimapCluster` | Major Blizzard UI elements; named for use as anchor targets |

## Tooltips

```lua
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Title", 1, 1, 1)
    GameTooltip:AddLine("Body line", nil, nil, nil, true)  -- last arg = wrap
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)
```

For item tooltips: `GameTooltip:SetItemByID(itemID)`. For spells: `:SetSpellByID(spellID)`.
