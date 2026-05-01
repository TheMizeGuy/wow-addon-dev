# Debugging WoW Addons & Taint

There is no built-in debugger. The community workflow is BugSack + ViragDevTool + console commands.

## Always-on tooling

The user already has these installed; lean on them:

- **!BugGrabber** — the bare grabber. Captures every Lua error with full stack and context. Saves to `WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua`. The exclamation point makes it sort first alphabetically so it loads before any other addon's errors can fire.
- **BugSack** — the display layer for !BugGrabber. Slash command `/bug` opens the error list. `/bug all` shows past sessions, `/bug me` filters to errors implicating your addons.
- **DBM** — DBM has its own diagnostic mode: `/dbm debug 3` enables verbose internal logging.
- **Details!** — most useful here for sanity-checking damage events when CLEU replacements behave oddly.

## The fastest debugging loop

1. Have BugSack visible. Reproduce.
2. Read the error: file, line, and the offending value.
3. `/dump <value>` to inspect anything in scope.
4. Edit Lua. Save. `/reload`.
5. Reproduce again.

Don't fully restart WoW unless the TOC changed.

## Slash commands for debugging

```
/run <Lua>          -- execute a Lua chunk in the global environment
/dump <expr>        -- pretty-print an expression's value
/script <Lua>       -- alias for /run
/console scriptErrors 1   -- show Lua errors in default UI (off by default in retail)
/console taintLog 1       -- log taint propagation to Logs/taint.log
/eventtrace               -- live event log (filters with /etrace block <event>)
/framestack               -- ALT-click any frame to inspect its hierarchy
/fstack                   -- alias
/reload                   -- reload Lua + UI without exiting WoW
/console reloadui         -- equivalent
```

`/dump` serializes any Lua value (table, function, frame) to chat. For complex tables, copy-paste the chat output into a text editor:

```
/dump _G["MyAddonDB"]
/dump CreateFrame
/dump UIParent:GetChildren()
```

## ViragDevTool (recommended add-on)

If the user doesn't have it, suggest installing — it's a live tree-view of any Lua value with auto-updating fields. The killer feature is `ViragDevTool_AddData(value, "MyLabel")` which pins a watch expression in a sidebar.

```lua
ViragDevTool_AddData(MyAddonDB, "MyAddonDB")
ViragDevTool_AddData(_G, "_G")  -- the entire global environment
```

Tree-explore by clicking; every frame's textures, scripts, and child frames are visible.

## Reading BugSack manually

When the user reports "I got a Lua error" without showing it, read the file directly:

```powershell
Get-Content "C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua"
```

The format is a Lua table assignment. Each error has:
- `message` — the raw Lua error text
- `stack` — call stack with file:line entries
- `locals` — if available, local variable values at the throw site
- `time` — timestamp
- `session` — session counter

The `scripts/read-bugsack.ps1` utility parses this and returns errors most-recent-first.

## Common error patterns and fixes

### `attempt to call a nil value`

A function name is wrong or the API was removed. Check whether the function moved to a `C_*` namespace. `LoadAddOn` → `C_AddOns.LoadAddOn`, `GetSpellInfo` → `C_Spell.GetSpellInfo`. Or it's a local that was never assigned.

### `attempt to index a nil value (field 'X')`

A table you expected to be populated is nil. Most common cause: SavedVariables not loaded yet because the file ran before `ADDON_LOADED`. Use the `MyAddonDB = MyAddonDB or {}` pattern at file scope.

### `attempt to compare two nil values`

A function returned nil where you expected a number. `UnitHealth("nottargeted")` returns 0 in some cases but nil in others. Always coerce: `(UnitHealth(u) or 0) >= threshold`.

### `attempt to compare/index 'X' (a secret <type> value tainted by 'Addon')`

The 12.0 Secret Values trap. See `references/midnight-12.md`. Don't read fields off `UnitAura`-style results; use `C_UnitAuras.GetPlayerAuraBySpellID` truthy-check, or `tonumber()` to scrub.

### `Interface action failed because of an AddOn`

Taint propagated to a Blizzard execution path. The notification names the addon Blizzard *blames* — which is often the last addon to taint the path, not the root cause. Enable taint logging:

```
/console taintLog 1
/reload
[reproduce the action]
```

Then read `WoW\Logs\taint.log`. Search for `blocked` to find the protected call that failed, and walk back through the taint chain (the file marks each function call's taint origin).

### `ADDON_ACTION_FORBIDDEN`

Your addon called a protected function from an insecure context. Most often:
- Calling `Hide()` / `Show()` on a `Blizzard_*` frame in combat
- Setting attributes on a secure frame in combat
- Modifying raid frame layout via reparenting

Fix: gate on `InCombatLockdown()` and defer to `PLAYER_REGEN_ENABLED` if needed. Or use `hooksecurefunc` (post-hook, no return-value mutation, no taint propagation backward) instead of `frame:SetScript("OnX", myFn)` style replacement.

### `script ran too long`

Default 30s instruction-count budget exceeded — almost always an infinite loop. Comment out chunks until it stops, then narrow.

### `frame is protected and cannot be modified during combat`

A specific case of `ADDON_ACTION_FORBIDDEN`. Same fix.

## Taint diagnosis workflow

The full procedure:

1. `/console taintLog 1`
2. `/reload`
3. Disable all addons except the one you suspect.
4. Reproduce the failing action.
5. Examine `Logs\taint.log` — search backwards from the `blocked` line.
6. Each line names the function and the addon that tainted it. Walk back to find which of your addon's calls poisoned a Blizzard path.
7. Common culprits: `securecall` misuse, modifying a saved variable that Blizzard reads, hooking with `frame:SetScript` instead of `hooksecurefunc`.

To re-enable the previously broken state without `/reload`: there's no way. Taint is one-way per session.

## Hook safely

Three hook styles, ordered by safety:

```lua
-- 1. hooksecurefunc — safest. Post-hook only. Cannot change return values.
--    Doesn't propagate taint backward to Blizzard.
hooksecurefunc("ChatFrame_OnEvent", function(self, event, ...)
    -- runs after Blizzard's handler; can't modify behavior
end)

-- 2. SetScript replacement — replaces the original. Pre/post wrapper required.
local orig = frame:GetScript("OnEvent")
frame:SetScript("OnEvent", function(...)
    -- pre
    if orig then orig(...) end
    -- post
end)
-- This taints frame's OnEvent. Avoid for Blizzard frames.

-- 3. Direct mutation of Blizzard tables — never. Taints the entire UI session.
```

Default to `hooksecurefunc` whenever the addon doesn't need to change return values or block the original.

## Frame inspection

`/framestack` (or alt-click any element with the cmd open): walk the hierarchy of a frame on screen. Useful for:
- Finding the name of an unnamed frame (Blizzard's anonymous frames have generated names like `LossOfControlFrame.MaskBorder`)
- Seeing parent chains to understand inheritance
- Spotting unintended overlap

`/dump <FrameName>:GetPoint(1)` returns the anchor — useful for repositioning addons that anchor relative to other addons' frames.

## Live testing without restarting

Most behaviors can be tested via `/run` snippets:

```
/run print(UnitName("target"))
/run for i = 1, 40 do print(i, UnitGUID("raid"..i)) end
/run C_Timer.After(2, function() print("2s elapsed") end)
/run for i, name in ipairs(C_AddOns.GetAddOnInfo) do print(i, name) end
```

For repeatable scenarios, copy multi-line snippets into your addon's slash command (`/myaddon test`) and call them from there. CrownCosmosCallout's `/ccc test all` is a great example of a built-in test harness.

## Performance profiling

```lua
/console scriptProfile 1   -- enable per-addon CPU/memory profiling
/reload
-- exercise the addon
GetAddOnCPUUsage("MyAddon")     -- ms used since last UpdateAddOnCPUUsage
GetAddOnMemoryUsage("MyAddon")  -- KB used
UpdateAddOnCPUUsage()           -- refresh stats
UpdateAddOnMemoryUsage()
```

The built-in addon `addonusage` and external `OmniCC`/`ElvUI` performance tabs visualize this. If your addon shows up >1ms average CPU, it's doing too much per frame.
