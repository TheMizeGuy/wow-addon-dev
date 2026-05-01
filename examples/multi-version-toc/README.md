# Multi-version TOC example

This addon ships one folder that loads correctly on retail, Cataclysm Classic,
and Vanilla / Classic Era. WoW picks the most-specific TOC for the running
client.

## Files

- `MyAddon.toc` — fallback if no edition-specific TOC matches
- `MyAddon_Mainline.toc` — retail (any 12.x build)
- `MyAddon_Cata.toc` — Cataclysm Classic
- `MyAddon_Vanilla.toc` — Vanilla / Classic Era
- `Core.lua` — shared core code; conditionally branches on client edition
- `Retail.lua` — retail-only code, never loaded on Classic
- `Vanilla.lua` — Vanilla-only code, never loaded on retail

The `[AllowLoadGameType ...]` annotation per file line lets a single TOC
include only the right per-edition files.

## How to test

Copy this folder to all three of:
- `_retail_\Interface\AddOns\MyAddon\`
- `_classic_\Interface\AddOns\MyAddon\` (for Cata Classic)
- `_classic_era_\Interface\AddOns\MyAddon\`

Launch each client. Each loads only the appropriate TOC.

## Adding more editions

Add new per-edition TOC files following the suffix table in
`references/toc-format.md`:

| Suffix | Edition |
|---|---|
| `_Mainline.toc` | Retail |
| `_Mists.toc` | Mists Classic |
| `_Cata.toc` | Cataclysm Classic |
| `_Wrath.toc` | Wrath Classic |
| `_TBC.toc` | TBC Classic |
| `_Vanilla.toc` | Vanilla / Classic Era |
| `_Classic.toc` | Any Classic (fallback) |
