# wow-addon-dev

Public, standalone, cross-agent Agent Skill package (SKILL.md format) that turns any compatible coding agent — Claude Code, Codex CLI, Gemini CLI, Copilot CLI — into a competent WoW addon developer and addon-folder manager. Tuned for retail Midnight (Interface 12.0+) breaking changes (CLEU removal, Secret Values, private auras) plus Classic editions and multi-version TOCs. Content repo: markdown + example Lua (not executed here) + PowerShell utility scripts. No build, no tests, no CI.

## Ship path

Commit + push IS the full ship path: no plugin cache, no marketplace registration, no sync step — deliberately, because this is a cross-agent package, not a Claude-Code-only plugin. Consumers install per the README (a direct clone into their agent's skills directory). Maintainer note: if the maintainer's own machines route skills through plugin channels instead of skills-dir clones, that routing is a consumer-side choice — the README instruction targets external users and stays as-is.

## Layout

- `SKILL.md` — entry point + workflow router table. Keep the router table and `references/` file list in sync (documented completion check).
- `references/` — 11 deep-dive files (toc-format, api-events-frames, midnight-12, debugging-and-taint, savedvariables-and-load-order, ace3-and-libraries, ui-and-secure-templates, slash-commands, localization, distribution-and-packaging, lessons-from-ccc).
- `examples/` — 6 runnable starter templates (MinimalAddon → EncounterMod → multi-version-toc).
- `scripts/` — 7 PowerShell utilities (get/set-interface-version, install-addon, list-installed-addons, package-addon, read-bugsack, validate-toc); every one takes `-WowPath` — preserve that override in any edit.

## Verification (no automated tooling — these ARE the gate)

Check SKILL.md frontmatter delimiters; check router-table ↔ references/ ↔ README tree sync; eyeball TOC/Lua syntax (no linter is wired in — Lua examples target WoW's Lua 5.1, so no 5.4-only syntax); dry-read PowerShell diffs for `-WowPath` regressions. `.gitignore` excludes `.claude/`, `.serena/`, `.anti-slop/`, `.remember/` — agent-tool state is local-only and never ships in this portable package; keep it that way (those untracked directories may hold richer maintainer notes on a dev machine).
