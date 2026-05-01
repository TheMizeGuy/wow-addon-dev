# Ace3 and Common Libraries

Ace3 is the de-facto framework for medium-to-large WoW addons. ~80% of community addons (DBM, BigWigs, ElvUI, WeakAuras, Plater, Skada, Recount, Auctionator, RaiderIO, etc.) use it.

## When to use Ace3

| Addon size / complexity | Recommendation |
|---|---|
| 1 file, <300 lines, single feature | Plain Lua, no Ace |
| 2-5 files, options menu, profile support | Ace3 |
| Library that other addons depend on | LibStub-only (no AceAddon) |
| Boss mod / encounter handler | DBM / BigWigs framework (their own) |

Ace3 adds ~200KB (loaded once across all addons via LibStub), provides idiomatic event/DB/options handling, and gives users a consistent profile UI. The trade-off is the indirection — `MyAddon:OnEnable()` instead of `f:RegisterEvent(...)` requires understanding how AceAddon hooks events under the hood.

## LibStub: the universal version stub

Every Ace library (and most others) lives behind LibStub:

```lua
local AceAddon = LibStub("AceAddon-3.0")
local LibSharedMedia = LibStub("LibSharedMedia-3.0", true)  -- silent if missing
```

LibStub picks the highest-version copy of a library among all addons that bundled it, so addons don't need to coordinate versions. Bundled in `Libs\LibStub\LibStub.lua`.

## AceAddon-3.0: lifecycle

```lua
-- Core.lua
local addonName, ns = ...   -- the addon-private namespace passed by WoW

local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceEvent-3.0", "AceConsole-3.0")
ns.MyAddon = MyAddon  -- expose for other files

function MyAddon:OnInitialize()
    -- Once per session, after SVs loaded. Safe place to set up DB.
    self.db = LibStub("AceDB-3.0"):New("MyAddonDB", DEFAULTS, true)
    self:RegisterChatCommand("myaddon", "OnSlashCommand")
end

function MyAddon:OnEnable()
    -- Each time addon is enabled (after OnInitialize, plus any /reload).
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("ENCOUNTER_START")
end

function MyAddon:OnDisable()
    -- AceEvent automatically unregisters on disable. Don't repeat that here.
end

function MyAddon:PLAYER_REGEN_DISABLED()
    -- AceEvent dispatches by event name — no string-compare in OnEvent
end

function MyAddon:ENCOUNTER_START(event, encounterID, ...)
    if encounterID == TARGET then ... end
end
```

Lifecycle order:
1. `OnInitialize` — once, after SVs loaded.
2. `OnEnable` — once, after `OnInitialize`. Also re-fires after `addon:Enable()` if user disabled and re-enabled.
3. `OnDisable` — when user disables via Ace's profile UI or your own toggle.

The mixins (`AceEvent-3.0`, `AceConsole-3.0`, etc.) attach methods to `self`. Pick whichever the addon actually uses:

| Mixin | Provides |
|---|---|
| `AceEvent-3.0` | `:RegisterEvent`, `:UnregisterEvent`, `:RegisterMessage`, `:SendMessage` (in-process pub/sub) |
| `AceConsole-3.0` | `:Print`, `:Printf`, `:RegisterChatCommand` |
| `AceTimer-3.0` | `:ScheduleTimer`, `:ScheduleRepeatingTimer`, `:CancelTimer` (alternative to `C_Timer`) |
| `AceComm-3.0` | `:SendCommMessage`, `:RegisterComm` (addon-message wrapper with auto-fragmentation for >255 char payloads) |
| `AceHook-3.0` | `:Hook`, `:HookScript`, `:SecureHook`, `:SecureHookScript` (auto-cleanup on disable) |
| `AceBucket-3.0` | `:RegisterBucketEvent` (debounce burst events into one callback) |
| `AceSerializer-3.0` | `:Serialize(value)`, `:Deserialize(str)` (round-trip for AceComm payloads) |

## AceDB-3.0: profile-aware saved variables

AceDB wraps `SavedVariables` with named scopes. The DB has 8 standard sub-tables, all populated automatically:

| Sub-table | Scope |
|---|---|
| `db.global` | Same value for all characters on the account |
| `db.profile` | Current named profile (default: char-named profile, but switchable) |
| `db.char` | Per character |
| `db.realm` | Per realm |
| `db.class` | Per class |
| `db.race` | Per race |
| `db.faction` | Per faction |
| `db.factionrealm` | Per faction-on-realm |

```lua
local DEFAULTS = {
    profile = {
        enabled = true,
        threshold = 50,
        colors = { bg = { 0, 0, 0, 0.6 } },
    },
    char = {
        keybinds = {},
    },
}

self.db = LibStub("AceDB-3.0"):New("MyAddonDB", DEFAULTS, true)
-- third arg: 'true' = use character profile by default
--            'string' = use this profile name
--            'nil' = use 'Default' profile

-- Read:
print(self.db.profile.threshold)

-- Write:
self.db.profile.threshold = 75
-- (no save call — AceDB writes through to MyAddonDB which WoW persists at logout)

-- Switch profile:
self.db:SetProfile("Healer")

-- React to profile changes:
self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
function MyAddon:RefreshConfig()
    -- re-apply settings from new profile
end
```

The TOC must declare `## SavedVariables: MyAddonDB`. AceDB adds its own structure under that key — addons should not write to `MyAddonDB` directly; go through `db.profile` / `db.char` / etc.

## AceConfig-3.0: declarative options

Define options as a Lua table; AceConfig generates a working settings panel:

```lua
local options = {
    name = "MyAddon",
    type = "group",
    args = {
        enabled = {
            name = "Enabled",
            type = "toggle",
            order = 1,
            get = function() return MyAddon.db.profile.enabled end,
            set = function(_, val) MyAddon.db.profile.enabled = val end,
        },
        threshold = {
            name = "Threshold",
            type = "range",
            min = 0, max = 100, step = 1,
            order = 2,
            get = function() return MyAddon.db.profile.threshold end,
            set = function(_, val) MyAddon.db.profile.threshold = val end,
        },
        spacer1 = { name = "", type = "header", order = 3 },
        profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(MyAddon.db),
    },
}

function MyAddon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MyAddonDB", DEFAULTS, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("MyAddon", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MyAddon", "MyAddon")
end
```

`AddToBlizOptions` registers the panel in WoW's Settings UI (Escape → Options → AddOns → MyAddon). The user-facing "profiles" sub-panel is free via `AceDBOptions-3.0`.

Option types: `toggle`, `range`, `select`, `multiselect`, `input`, `color`, `keybinding`, `group`, `header`, `description`, `execute`.

Each option supports: `get`, `set`, `disabled`, `hidden`, `confirm`, `validate`, `width` (`"normal"`, `"double"`, `"full"`), `multiline` (for input), `softMin`/`softMax` (for range).

## Common standalone libraries

### LibSharedMedia-3.0

Shared registry for fonts, sounds, statusbar textures, borders. Other addons (and the user) register media; your addon picks from a unified list.

```lua
local LSM = LibStub("LibSharedMedia-3.0")
LSM:Register("font", "MyAddon Font", "Interface\\AddOns\\MyAddon\\fonts\\thing.ttf")

-- consume:
local font = LSM:Fetch("font", self.db.profile.fontName)
text:SetFont(font, 14)
```

### LibDBIcon-1.0

Minimap icon button with built-in show/hide and drag positioning.

```lua
local LDB = LibStub("LibDataBroker-1.1")
local dataObject = LDB:NewDataObject("MyAddon", {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    OnClick = function(self, button)
        if button == "LeftButton" then OpenMyAddon()
        elseif button == "RightButton" then OpenMyAddonOptions() end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("MyAddon")
        tooltip:AddLine("Left-click: open. Right-click: options.")
    end,
})

local LibDBIcon = LibStub("LibDBIcon-1.0")
LibDBIcon:Register("MyAddon", dataObject, MyAddon.db.profile.minimap)  -- minimap = { hide = false, minimapPos = 220 }
```

### LibDataBroker-1.1

The data-display layer — many other UI addons (Bagnon, ElvUI, ChocolateBar, ButtonBin) consume LDB feeds. Provide one `:NewDataObject` and your addon plugs into all of them automatically.

### CallbackHandler-1.0

Ace3 internals use this for the `RegisterCallback` machinery. You won't call it directly unless writing a library.

### LibAceConfig-3.0 (alias for AceConfig)

Same thing, depending on which addon's `embeds.xml` declared it.

## Embedding libraries

Libraries are typically not standalone addons — they're files copied into your addon's `Libs\` directory and referenced from your TOC:

```
## OptionalDeps: Ace3
## SavedVariables: MyAddonDB

embeds.xml
Core.lua
```

Where `embeds.xml`:

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
    <Include file="Libs\LibStub\LibStub.lua"/>
    <Include file="Libs\CallbackHandler-1.0\CallbackHandler-1.0.xml"/>
    <Include file="Libs\AceAddon-3.0\AceAddon-3.0.xml"/>
    <Include file="Libs\AceEvent-3.0\AceEvent-3.0.xml"/>
    <Include file="Libs\AceDB-3.0\AceDB-3.0.xml"/>
</Ui>
```

You can also list `.lua` files directly in the TOC instead of using `embeds.xml` — works the same; XML is just convention.

If a user has Ace3 installed as a standalone addon, your bundled copy is shadowed by LibStub picking the higher version. That's fine.

## When NOT to use Ace3

- Writing a library. Use raw LibStub for the version stub; build a custom callback layer if pub/sub is needed.
- The addon is a one-off boss-fight handler with no settings (like CrownCosmosCallout). The Ace3 indirection is overhead for no benefit.
- Performance-critical inner loops (combat data processing). Ace's event dispatch adds a function call per event; raw `frame:SetScript("OnEvent", fn)` is faster.

For 90%+ of "I want a settings panel and persistent prefs across characters" use cases, Ace3 is the right answer.
