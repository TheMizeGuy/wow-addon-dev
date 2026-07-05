# Changelog

This skill has no `plugin.json` or version field (it's a plain [Agent Skill](https://agentskills.io), not a Claude Code plugin) — entries below are dated instead of versioned.

## 2026-07-05

- Verification step added: `SKILL.md` now spells out what "done" requires per change type — `validate-toc.ps1` after a `.toc` edit, a Lua syntax check plus `read-bugsack.ps1` after a Lua edit, a zip-structure check after packaging, and an explicit "in-game testing wasn't possible" fallback pointing at the test-harness pattern in `references/lessons-from-ccc.md`.
- Example directory names in `SKILL.md` corrected to match the actual folders on disk (`MinimalAddon/`, `MyAce3Addon/`, `EncounterMod/` — previously referenced as lowercase-hyphenated names that didn't exist).
- Repo hygiene: `.gitignore` entries added; no functional change to the skill content.

## 2026-05-01

- Initial release: the `wow-addon-dev` skill covering addon authoring (minimal, Ace3, encounter-mod, options-panel, addon-message, multi-version-TOC templates), the TOC format, the WoW Lua API, Patch 12.0 (Midnight) migration, debugging, SavedVariables, Ace3/libraries, UI/secure templates, slash commands, localization, and distribution — plus PowerShell utility scripts and lessons distilled from a real production addon (CrownCosmosCallout).
- README rewritten with install instructions verified per-agent (Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, and a generic fallback).
