# SavedVariables & Addon Load Order

The most common source of "my settings don't persist" bugs is misunderstanding when SVs are populated.

## File locations

| Type | TOC directive | File path |
|---|---|---|
| Per-account | `## SavedVariables: MyAddonDB` | `WTF\Account\<ACCT>\SavedVariables\<AddonName>.lua` |
| Per-character | `## SavedVariablesPerCharacter: MyCharDB` | `WTF\Account\<ACCT>\<Realm>\<Character>\SavedVariables\<AddonName>.lua` |

The file is plain Lua. WoW emits an assignment statement per declared SV table:

```lua
-- WTF\Account\<ACCOUNT>\SavedVariables\MyAddon.lua
MyAddonDB = {
    ["enabled"] = true,
    ["pool"] = { "Vorelus", "Morium" },
}
```

When the file loads on next session, `MyAddonDB` becomes a global with that value.

## When SVs are available

Two sources of confusion:

1. **The TOC declares which globals to save**, not where they live. The variable doesn't exist until either (a) WoW loads the SavedVariables file at addon-load time, or (b) the addon's own Lua code assigns to it.

2. **By default SVs load AFTER the last file in the TOC**, but addon code starts running as files load. So at the top of `Core.lua`, `MyAddonDB` may still be `nil`.

This is why you see the universal pattern:

```lua
MyAddonDB = MyAddonDB or {}   -- "if SVs already loaded with values, keep; else init empty"
```

## The init pattern (do this every time)

```lua
-- top of Core.lua (or wherever first; runs as the file loads)
MyAddonDB = MyAddonDB or {}
local function db()
    local d = MyAddonDB
    if d.enabled  == nil then d.enabled  = true end
    if d.threshold == nil then d.threshold = 50  end
    if d.pool     == nil then d.pool     = { "Default" } end
    return d
end
```

`db()` returns the same table every call but lazily fills missing fields with defaults. This handles:
- Fresh install: `MyAddonDB = nil`, becomes `{}`, then `db()` populates defaults.
- Upgrade with new fields: existing fields preserved, new fields added on first call.
- Downgrade: old extra fields stay (harmless), missing fields backfilled.

The `if d.x == nil then` guard is intentional — `if not d.x` would overwrite an explicit `false`, which matters for boolean toggles.

## Event timeline (cheat sheet)

```
Game launch
  ↓
[for each non-LoadOnDemand addon, in dependency order]
   ├─ TOC parsed
   ├─ SavedVariables file loaded → globals populated
   ├─ Lua files run in TOC order
   ├─ ADDON_LOADED fires (this addon's name as arg)
  ↓
[after all non-LoD addons]
   ├─ VARIABLES_LOADED fires (deprecated; covers all global SVs)
   ├─ PLAYER_LOGIN fires
  ↓
PLAYER_ENTERING_WORLD fires (also fires on /reload, zone changes)
  ↓
[normal play]
  ↓
[on logout/reload/quit]
   ├─ PLAYER_LOGOUT fires
   ├─ SVs serialized to disk
```

### When to do what

| Need | Do it in |
|---|---|
| Define globals, slash commands, frames | File scope (no event needed) |
| Read SavedVariables for first time | `ADDON_LOADED` (filtered to your addon name) — or just use the `or {}` pattern at file scope |
| Inspect player info (name, class, realm) | `PLAYER_LOGIN` |
| Inspect zone, group composition | `PLAYER_ENTERING_WORLD` |
| Last chance to mutate SVs | `PLAYER_LOGOUT` |

### `ADDON_LOADED` filtering pattern

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon ~= "MyAddon" then return end  -- fires for every addon; filter
    -- now SVs are guaranteed loaded; safe to read MyAddonDB
    self:UnregisterEvent("ADDON_LOADED")
end)
```

Note: most simple addons can skip `ADDON_LOADED` entirely. The `MyAddonDB = MyAddonDB or {}` pattern at file scope works because by the time WoW *runs* your Lua file, your SVs file has already been parsed (default behavior). The exception is `## LoadSavedVariablesFirst: 1` — then SVs load before files, and the inverse is true.

## What can be saved

Saved variables must be plain Lua values that serialize cleanly. Allowed:

- `nil`, `boolean`, `number`, `string`
- Tables containing only the above (recursively)

Disallowed:

- Functions
- Frames or any userdata (lightuserdata included)
- Coroutines
- Tables with non-string/non-number keys (NaN keys, metatables)
- Cyclic references — WoW will infinite-loop or truncate

If you have a frame reference you want to "remember", save its name (string) and look it up at load time:

```lua
-- save:
MyAddonDB.myFrame = frame:GetName()
-- restore:
local frame = _G[MyAddonDB.myFrame]
```

## Multiple SV tables

```
## SavedVariables: MyAddonDB, MyAddonOptions, MyAddonHistory
## SavedVariablesPerCharacter: MyAddonCharDB, MyAddonCharLog
```

Comma-separated. Each becomes a separate global. Useful when you want different scopes — e.g., shared profile across characters but per-character key bindings.

## Migrating SV schema

When you change the structure between versions:

```lua
local SCHEMA_VERSION = 3

local function migrate(d)
    d.schema = d.schema or 1
    if d.schema < 2 then
        -- v1 → v2: rename "color" → "colors"
        d.colors = d.color
        d.color = nil
    end
    if d.schema < 3 then
        -- v2 → v3: split colors table
        d.colors.bg = d.colors.bg or { 0, 0, 0, 0.6 }
    end
    d.schema = SCHEMA_VERSION
end

MyAddonDB = MyAddonDB or {}
migrate(MyAddonDB)
```

The migrator runs once per load. New installs get the latest schema directly via the defaults; upgrades walk through every step.

## Profile management (when to use AceDB)

Once you have multiple characters with different settings *and* want shared profiles users can switch between, hand-rolling the index gets painful. AceDB-3.0 (`references/ace3-and-libraries.md`) provides:

- `db.profile.X` — current named profile
- `db.char.X` — per-character
- `db.realm.X` — per-realm
- `db.class.X`, `db.race.X`, `db.faction.X`, `db.factionrealm.X`, `db.global.X`
- Profile create/copy/reset/delete
- Profile sharing across characters via name

Below ~3 settings, plain SVs are fine. Above that, AceDB pays for itself.

## Per-character vs per-account decisions

| Use per-character (`SavedVariablesPerCharacter`) for | Use per-account (`SavedVariables`) for |
|---|---|
| Bindings tied to a class/spec | Window positions |
| Quest tracker state | Color schemes |
| Inventory layout (if class-specific) | Default chat channel |
| Chat tab arrangement | Loot threshold preferences |
| Spell-specific cooldown filters | Library cache (e.g., LibSharedMedia entries) |

When in doubt: per-character is reversible (deletable per char), per-account is not. Lean per-character.

## Disk size and pruning

Saved variable files grow until you prune them. A spell history that adds an entry per cast and never trims will eventually take seconds to serialize on logout, freezing the client.

Cap any growth-prone table:

```lua
local MAX_HISTORY = 1000

table.insert(MyAddonDB.history, entry)
while #MyAddonDB.history > MAX_HISTORY do
    table.remove(MyAddonDB.history, 1)
end
```

Or trim at load time:

```lua
if #MyAddonDB.history > MAX_HISTORY then
    -- keep most recent
    local keep = {}
    for i = #MyAddonDB.history - MAX_HISTORY + 1, #MyAddonDB.history do
        keep[#keep+1] = MyAddonDB.history[i]
    end
    MyAddonDB.history = keep
end
```
