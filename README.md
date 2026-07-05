# wow-addon-dev — a WoW addon-development skill for AI coding agents

A self-contained [Agent Skill](https://agentskills.io) that turns a general-purpose AI coding agent (Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, or anything else that loads `SKILL.md`-style packages) into a competent World of Warcraft addon developer and addon-folder manager.

Tuned for **retail Midnight (Interface 12.0+)** with explicit handling for the breaking changes that arrived with that patch (CLEU removal, Secret Values, private auras), plus Classic editions and multi-version TOCs.

## What it covers

- **Writing addons** — minimal, Ace3, encounter mod, options panel, addon-message, multi-version-TOC starter templates.
- **TOC format** — every directive, multi-edition syntax, current Interface numbers, localized variants, file-load conditionals.
- **WoW Lua API** — frame creation, event registration patterns, `C_Timer`, `C_ChatInfo` addon messages, common events.
- **Patch 12.0 (Midnight) migration** — Secret Values, private auras, CLEU removal, `C_Spell`/`C_ActionBar` namespace migration, `tonumber()` scrubbing.
- **Debugging** — BugSack/BugGrabber, taint diagnosis, `/console taintLog 1`, `/eventtrace`, `/dump`, ViragDevTool.
- **SavedVariables** — load order, `ADDON_LOADED` vs `PLAYER_LOGIN`, the `or {}` init pattern, schema migration.
- **Ace3 & libraries** — AceAddon/AceDB/AceConfig/AceEvent, LibStub, LibSharedMedia-3.0, LibDBIcon-1.0, LibDataBroker.
- **UI & secure templates** — `CreateFrame`, anchors, fonts, `Settings.RegisterCanvasLayoutCategory`, combat lockdown rules.
- **Slash commands** — `SLASH_X1`/`SlashCmdList` registration, argument parsing, multi-alias setup.
- **Localization** — TOC variants, AceLocale-3.0, GLOBAL_STRINGS, spell/item ID lookups.
- **Distribution** — BigWigs Packager (`pkgmeta.yaml`), GitHub Actions auto-release, manual zip structure, CurseForge/WoWInterface/Wago upload.
- **Hard-won lessons** — concrete gotchas from a real production addon (CrownCosmosCallout): private-aura taint, OnEvent-before-RegisterEvent, generation counters for `C_Timer` callbacks, broadcast-snapshot-not-live-state, addon-message coordination protocols.

## Repo structure

```
wow-addon-dev/
├── SKILL.md                # entry point + workflow router
├── references/             # progressive-disclosure deep dives (loaded as needed)
│   ├── toc-format.md
│   ├── api-events-frames.md
│   ├── midnight-12.md
│   ├── debugging-and-taint.md
│   ├── savedvariables-and-load-order.md
│   ├── ace3-and-libraries.md
│   ├── ui-and-secure-templates.md
│   ├── slash-commands.md
│   ├── localization.md
│   ├── distribution-and-packaging.md
│   └── lessons-from-ccc.md
├── examples/               # runnable starter templates
│   ├── MinimalAddon/       # single-file addon, no libs
│   ├── MyAce3Addon/        # Ace3 + AceDB + AceConfig
│   ├── EncounterMod/       # boss-fight handler with hard lockout pattern
│   ├── options-panel/      # modern Settings API panel snippet
│   ├── addon-message/      # versioned addon-comm protocol
│   └── multi-version-toc/  # per-edition TOCs sharing one Lua core
└── scripts/                # PowerShell utilities
    ├── list-installed-addons.ps1
    ├── get-interface-version.ps1
    ├── validate-toc.ps1
    ├── install-addon.ps1
    ├── read-bugsack.ps1
    ├── package-addon.ps1
    └── set-interface-version.ps1
```

## Installation

### Claude Code (recommended)

User-level skill (available across all your projects):

```bash
git clone https://github.com/TheMizeGuy/wow-addon-dev.git ~/.claude/skills/wow-addon-dev
```

On Windows PowerShell:

```powershell
git clone https://github.com/TheMizeGuy/wow-addon-dev.git "$env:USERPROFILE\.claude\skills\wow-addon-dev"
```

Then **fully restart Claude Code**. (Live change detection works for edits to existing watched dirs, but a freshly created top-level `~/.claude/skills/` directory needs the watcher to attach at session start.)

Verify by typing `/wow-addon-dev` (auto-completes from the skill menu) or asking something like *"how do I write a WoW addon"* — Claude Code's skill list at session start will include `wow-addon-dev` once auto-discovery picks it up.

Project-level install (skill scoped to one repo):

```bash
git clone https://github.com/TheMizeGuy/wow-addon-dev.git .claude/skills/wow-addon-dev
```

### Codex CLI

Personal skills live at `~/.codex/skills/` ([per OpenAI's Codex docs](https://developers.openai.com/codex/skills)). Easiest install via the `gh skill` command:

```bash
gh skill install TheMizeGuy/wow-addon-dev
```

Or clone manually:

```bash
git clone https://github.com/TheMizeGuy/wow-addon-dev.git ~/.codex/skills/wow-addon-dev
```

Override the Codex home with `CODEX_HOME` if you want a different location. Disable a skill without removing it via `[[skills.config]]` entries in `~/.codex/config.toml`.

### Gemini CLI

User-scoped skills live at `~/.gemini/skills/` ([per Gemini CLI docs](https://geminicli.com/docs/cli/skills/)). Gemini also accepts the tool-agnostic `.agents/skills/` alias at the same scope.

```bash
git clone https://github.com/TheMizeGuy/wow-addon-dev.git ~/.gemini/skills/wow-addon-dev
```

Restart Gemini CLI. When you ask a matching question, Gemini calls the `activate_skill` tool to load the full body and shows a confirmation prompt naming the skill and the directory it gains access to.

### GitHub Copilot CLI

Personal skills live at `~/.copilot/skills/` or the tool-agnostic alias `~/.agents/skills/` ([per GitHub's Copilot CLI docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)). Easiest install via `gh skill`:

```bash
gh skill install TheMizeGuy/wow-addon-dev
```

Or clone manually:

```bash
git clone https://github.com/TheMizeGuy/wow-addon-dev.git ~/.copilot/skills/wow-addon-dev
```

After installing, run `/skills reload` inside an existing Copilot CLI session, or just start a new session. Verify with `/skills info wow-addon-dev`.

### Generic / any other agent

The skill is a plain `SKILL.md` plus supporting markdown/code files. For agents that don't yet support the Agent Skills standard, point the agent at `SKILL.md` directly:

```
> Read https://raw.githubusercontent.com/TheMizeGuy/wow-addon-dev/main/SKILL.md
> and apply its workflow router when I ask about WoW addon development.
```

The skill body uses progressive disclosure — the agent reads `SKILL.md` first, then follows the workflow-router table to load specific reference files (`references/foo.md`) only when relevant.

## Usage

Once installed, the skill auto-loads on prompts like:

- *"Create a WoW addon that announces when I'm low on mana."*
- *"My addon is showing 'out of date' — what version do I bump it to?"*
- *"Here's a Lua error from BugSack: \[paste\] — what's wrong?"*
- *"How do I migrate my addon from CLEU to whatever 12.0 wants?"*
- *"Package my addon for CurseForge."*
- *"Why is `aura.spellId` throwing a secret-value error?"*

Or invoke explicitly: `/wow-addon-dev` (Claude Code) / `activate_skill('wow-addon-dev')` (Gemini).

The skill ships **PowerShell utility scripts** under `scripts/` that smoke-test against a real WoW install (verified: scans 73-addon directories, reads exe versions, parses BugGrabber SavedVariables). On macOS or Linux, PowerShell Core works (`pwsh`), or port the logic to bash — the operations are simple file reads.

### Walkthrough: fixing an "out of date" addon

A worked example, start to finish:

1. Install the skill (see Installation above) and restart the agent.
2. Prompt: *"My addon shows 'out of date' since the patch, what do I do?"*
3. The skill's description matches on "out of date" and the agent loads `SKILL.md`. The workflow router points an "out of date" / TOC question at `references/toc-format.md`.
4. The agent runs `scripts/get-interface-version.ps1` to read the current retail Interface number from the installed `Wow.exe` build (or asks the user to run `/dump select(4, GetBuildInfo())` in-game if the script can't reach the client).
5. The agent edits the addon's `## Interface:` line — directly, or via `scripts/set-interface-version.ps1 <addon-folder> <new-interface>` for multi-TOC addons — then runs `scripts/validate-toc.ps1 <path-to-.toc>` to confirm zero findings.
6. The agent tells the user to **fully restart WoW** (a TOC change is not picked up by `/reload`) and reports exactly what it verified (the interface number written, the validator's clean result) rather than claiming the fix "should work."

### Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Skill never activates on WoW-related prompts | Agent hasn't picked up a freshly created top-level skills directory | Fully restart the agent session after first install (live file-watch works for existing directories, not brand-new ones) |
| `/wow-addon-dev` doesn't autocomplete in Claude Code | Skill installed at the wrong scope, or session started before install | Confirm the clone landed in `~/.claude/skills/wow-addon-dev` (user) or `.claude/skills/wow-addon-dev` (project), then restart |
| PowerShell scripts fail with "not recognized" on macOS/Linux | No PowerShell runtime installed | Install PowerShell Core (`pwsh`) or port the script's logic to bash — the operations are plain file reads |
| Addon still shows "out of date" after bumping `## Interface:` | WoW was `/reload`ed instead of fully restarted, or a per-edition TOC file (`_Vanilla.toc`, `_Cata.toc`) was missed | Fully quit and relaunch WoW; run `scripts/set-interface-version.ps1` (not a hand-edit) so every TOC variant gets bumped together |
| Packaged zip won't load after CurseForge/manual install | Top-level folder name doesn't match the addon's own `.toc` base name | Rename the zip's root folder to exactly match `AddonName.toc`'s base name — WoW enforces this |
| Secret-value / private-aura errors after the 12.0 patch | Pre-Midnight code reading `aura.spellId` or similar directly | See `references/midnight-12.md` for the `C_Spell`/`C_ActionBar` migration and Secret Values handling |

## Compatibility

- **Claude Code** ≥ 2.0 (verified)
- **Codex CLI** — supports Agent Skills standard (untested with this skill specifically; report issues)
- **Gemini CLI** — supports Agent Skills standard (untested)
- **GitHub Copilot CLI** — supports Agent Skills standard (untested)
- **Other agents** — anything that can read a markdown file + follow a workflow

WoW client coverage:
- ✅ Retail (Midnight 12.0+) — primary target, all references current
- ✅ Classic Era / Vanilla — multi-version TOC examples included
- ✅ Cataclysm / Wrath / TBC Classic — covered in TOC reference and example
- ⚠ Anniversary realms — currently TBC-pinned; check the in-game build with `/dump select(4, GetBuildInfo())`

## Contributing

Issues and PRs welcome. Particularly useful contributions:

- **Bash/zsh ports of the PowerShell scripts** for macOS and Linux users.
- **Verified Patch 12.x API names** as Blizzard's API surface settles. The `references/midnight-12.md` doc currently hedges several function names ("likely named X — verify with `/dump`") because the secret-values API is still evolving.
- **More example addons** for niches like profession assistants, transmog browsers, group finders.
- **Localization references** for languages beyond the en-locale-centric examples.

When adding examples, ensure the folder name matches the TOC base name (WoW's hard rule). Run `scripts/validate-toc.ps1` to check.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

Built distilling lessons from the [CrownCosmosCallout](https://github.com/) production addon, the [Warcraft Wiki](https://warcraft.wiki.gg/) API documentation, the [BigWigs Packager](https://github.com/BigWigsMods/packager) toolchain, and the [Ace3](https://www.wowace.com/projects/ace3) framework.
