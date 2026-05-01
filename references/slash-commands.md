# Slash Commands

The user-facing way to interact with an addon. Trivial to set up; powerful with good argument parsing.

## Basic registration

```lua
SLASH_MYADDON1 = "/myaddon"
SLASH_MYADDON2 = "/ma"   -- second alias
SlashCmdList.MYADDON = function(msg, editBox)
    print("got:", msg)
end
```

The suffix on `SLASH_MYADDON1` is what links to `SlashCmdList.MYADDON`. They must match.

The handler receives the entire trailing string (without the slash and command word) as `msg`. WoW does no further parsing.

## Argument parsing pattern

```lua
SLASH_MYADDON1 = "/myaddon"
SlashCmdList.MYADDON = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")  -- trim
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "help" then
        ShowHelp()

    elseif cmd == "set" then
        if rest == "" then
            print("usage: /myaddon set <value>")
        else
            DoSet(rest)
        end

    elseif cmd == "toggle" then
        local v = rest:lower()
        if v == "on" then DoToggle(true)
        elseif v == "off" then DoToggle(false)
        else print("usage: /myaddon toggle on|off") end

    elseif cmd == "list" then
        local names = {}
        for name in rest:gmatch("[^,%s]+") do names[#names+1] = name end
        DoList(names)

    elseif cmd == "reset" then
        DoReset()
        print("|cff00ff00[MyAddon]|r reset.")

    else
        print("Unknown command. Try /myaddon help.")
    end
end
```

The `:gsub` trim is idiomatic Lua — no built-in `trim` function. The `match("^(%S+)%s*(.*)$")` extracts the first whitespace-delimited token as `cmd` and the remainder as `rest`.

## Help output convention

```lua
local function ShowHelp()
    print("|cff00ff00[MyAddon]|r commands:")
    print("  /myaddon set <name>        -- set the active target")
    print("  /myaddon toggle on|off     -- enable/disable")
    print("  /myaddon list a, b, c      -- comma-separated list")
    print("  /myaddon reset             -- reset to defaults")
    print("  /myaddon help              -- this message")
end
```

Indent two spaces, command first, double-space, description. Matches WoW's convention.

## AceConsole-3.0 alternative

If using Ace3, slash commands integrate with chat output and per-addon prefixing:

```lua
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MyAddon", "AceConsole-3.0")

function MyAddon:OnInitialize()
    self:RegisterChatCommand("myaddon", "OnSlashCommand")
    self:RegisterChatCommand("ma", "OnSlashCommand")
end

function MyAddon:OnSlashCommand(msg)
    -- AceConsole has self:GetArgs(msg, n) for tokenizing
    local cmd, arg1 = self:GetArgs(msg, 2)
    -- ...
end
```

`AceConsole:Print(...)` automatically prefixes output with the addon name in color.

## Multiple slash commands for the same addon

```lua
SLASH_MYADDON1 = "/myaddon"
SLASH_MYADDON2 = "/ma"
SlashCmdList.MYADDON = MainHandler

-- separate command for a sub-feature:
SLASH_MYADDONDEBUG1 = "/madebug"
SlashCmdList.MYADDONDEBUG = function(msg)
    -- debug-specific
end
```

Each pair is independent. Useful when one slash command handles user actions and another handles diagnostic output you don't want surfaced in help.

## Argument types and parsing helpers

```lua
-- single number
local n = tonumber(rest)
if not n then ... end

-- bool
local function parseBool(s)
    s = s:lower()
    if s == "on" or s == "true" or s == "1" or s == "yes" then return true end
    if s == "off" or s == "false" or s == "0" or s == "no" then return false end
    return nil
end

-- list (comma- or space-separated)
local items = {}
for item in rest:gmatch("[^,%s]+") do items[#items+1] = item end

-- key=value pairs
local kvs = {}
for k, v in rest:gmatch("(%w+)=(%S+)") do kvs[k] = v end

-- quoted string
local quoted = rest:match('^"([^"]*)"%s*(.*)$')
```

## Linking to other commands

A slash handler can run another:

```lua
elseif cmd == "everything" then
    SlashCmdList.MYADDON("reset")
    SlashCmdList.MYADDON("toggle on")
    SlashCmdList.MYADDON("set default")
end
```

But prefer factoring shared logic into a Lua function and calling that from each handler — it's easier to test and doesn't double-process `msg`.

## Tab completion (rare, useful)

There's no native API for slash command tab-completion in retail. WeakAuras and a few other major addons hook the chat editbox to add suggestions:

```lua
ChatEdit_GetActiveWindow():HookScript("OnTabPressed", function(self)
    local text = self:GetText()
    if text:sub(1, 9) == "/myaddon " then
        -- suggest completions
    end
end)
```

This is ~50 lines of code and rarely worth it for a small addon. Skip unless the addon has many commands.

## Slash command best practices

- **Always handle empty `msg`** — print help.
- **Always lowercase the command word** before comparison; keep arguments as-is for things like names.
- **Always print confirmation on actions** — silent success is confusing.
- **Color-code addon name in output** with `|cff00ff00[MyAddon]|r` for instant visual recognition.
- **Reserve `/myaddon test`** for a built-in test harness. CrownCosmosCallout's pattern: `/ccc test`, `/ccc test all`, `/ccc test live` — quick, full, and live-coordination tests.
- **Use `/myaddon status`** as a diagnostic dump command. Print every relevant config and state value in one line per item.
- **Use `/myaddon config` or `/myaddon options`** to open the settings panel. Don't make users navigate Escape → Options → AddOns.
- **Pick a unique top-level slash.** `/m` collides with `/macro`; `/mod` collides; `/r` is a reply alias. Three letters minimum, ideally an obvious abbreviation. Check `/help` from in-game to see existing chat commands first.
