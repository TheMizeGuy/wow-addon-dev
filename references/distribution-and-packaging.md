# Distribution & Packaging

Once the addon works locally, getting it to other players. Three platforms (CurseForge, WoWInterface, Wago), three ways to upload (manual zip, BigWigs Packager, GitHub Actions).

## Distribution platforms

| Platform | URL | Notes |
|---|---|---|
| CurseForge | curseforge.com/wow/addons | Largest userbase. Standalone client + Overwolf. Owned by Twitch/Amazon. |
| WoWInterface | wowinterface.com | Original community site. Older interface, smaller audience but loyal. |
| Wago Addons | addons.wago.io | Newer, ad-light, used heavily by WeakAuras community. Author-friendly. |
| GitHub Releases | (your repo) | For manual installers and dev builds. No discoverability. |

Most addons publish to all three for reach. The BigWigs Packager + GitHub Actions setup uploads to all three from one tag push.

## Manual zip structure

The simplest distribution: a `.zip` containing your addon folder, ready to extract into `Interface\AddOns\`.

```
MyAddon.zip
└── MyAddon/
    ├── MyAddon.toc
    ├── Core.lua
    ├── README.md         (optional but conventional)
    ├── LICENSE           (optional but conventional)
    └── Libs/
        └── ...
```

The folder inside the zip MUST be named exactly the same as your addon (which must match the TOC filename). When the user extracts to `Interface\AddOns\`, they get `Interface\AddOns\MyAddon\MyAddon.toc`.

Common mistakes:
- Zipping the *contents* of the addon folder (`MyAddon.toc` at root of zip) instead of the folder. Users extract and end up with no folder.
- Including a parent directory like `MyAddon-1.2.3/MyAddon/`. Fixable but ugly.
- Including `.git/`, `.github/`, `.vscode/`. Not catastrophic but bloat.

`scripts/package-addon.ps1` handles all of this correctly.

## BigWigs Packager

The community-standard CI tool. Reads a `.pkgmeta` file in your repo root and produces uploadable zips.

Minimal `.pkgmeta`:

```yaml
package-as: MyAddon

externals:
    Libs/LibStub:
        url: https://repos.curseforge.com/wow/libstub/trunk
    Libs/Ace3:
        url: https://repos.curseforge.com/wow/ace3/trunk

ignore:
    - .github
    - .vscode
    - "*.bak"
    - "*.psd"

manual-changelog: CHANGELOG.md
```

The packager:
1. Clones/downloads externals (libraries) into `Libs/`.
2. Strips `.git/`, the `ignore`d files, and any `--@debug@`/`--@end-debug@` blocks (for debug code that shouldn't ship).
3. Bumps the `## Version:` directive to match the git tag.
4. Builds zips per game-edition (one for retail, one for Classic, etc., based on per-edition TOC files).
5. Uploads to CurseForge / WoWInterface / Wago via their APIs (auth tokens supplied via env vars).

Run locally with:
```bash
curl -sSL https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -d
```

`-d` is dry-run (skip uploads). Drop it for real publishing.

## GitHub Actions integration

Add `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: BigWigsMods/packager@v2
        env:
          CF_API_KEY: ${{ secrets.CF_API_KEY }}
          WOWI_API_TOKEN: ${{ secrets.WOWI_API_TOKEN }}
          WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Now `git tag v1.2.3 && git push --tags` triggers the workflow, which builds and uploads.

API tokens to put in repo Secrets:
- `CF_API_KEY` — CurseForge "API Token" from authors.curseforge.com
- `WOWI_API_TOKEN` — WoWInterface from your account profile API tab
- `WAGO_API_TOKEN` — addons.wago.io account API tokens

`GITHUB_TOKEN` is auto-provided; the packager uses it to attach the zip to a GitHub Release with the same tag.

## TOC fields the packager auto-fills

The packager processes `## Version:` and `## X-Curse-Project-ID:` etc. via these substitutions:

| Token | Replaced with |
|---|---|
| `@project-version@` | git tag (e.g. `v1.2.3` → `1.2.3`) |
| `@build-date@` | timestamp |
| `@build-revision@` | git commit short SHA |
| `@file-hash@` | content hash |

Example TOC with substitution:
```
## Interface: 120005
## Title: My Addon
## Version: @project-version@
## X-Curse-Project-ID: 123456
## X-WoWI-ID: 26000
## X-Wago-ID: AbCdEf
```

The `X-` prefix is convention for non-standard / tooling metadata; WoW ignores them.

## Per-edition zips

If you support multiple editions via per-edition TOC files (`MyAddon_Mainline.toc`, `MyAddon_Vanilla.toc`), the packager produces one zip per edition with the right TOC included and others excluded.

`pkgmeta` driven via:
```yaml
package-as: MyAddon

split:
    Mainline:
        toc-suffix: _Mainline
    Vanilla:
        toc-suffix: _Vanilla
```

Each platform (CurseForge etc.) accepts the per-edition zips with edition tags so the addon manager downloads the right one.

## Versioning

Tag format: `vMAJOR.MINOR.PATCH` (e.g. `v1.2.3`). The packager strips the `v` for `## Version:`.

Semantic versioning principles:
- **MAJOR**: incompatible changes — saved variable schema break, addon-message protocol break, removed slash commands.
- **MINOR**: new features, backwards-compatible.
- **PATCH**: bug fixes only.

For an addon with active addon-message coordination (CrownCosmosCallout's case), bump MINOR when introducing a new field in the protocol *with* a fallback for old peers, MAJOR when removing a field old peers depend on.

## Changelogs

Conventional location: `CHANGELOG.md` at repo root, BBCode or Markdown.

```markdown
# Changelog

## 1.2.3 (2026-04-29)
- Fixed nil error when leaving the encounter mid-cast.
- Updated for Patch 12.0.5 (Interface 120005).

## 1.2.2 (2026-04-15)
- Added `/myaddon test live` for cross-raid coordination testing.
```

The packager extracts the most recent entry and uploads it as the platform-specific changelog. WoWInterface uses BBCode; CurseForge accepts Markdown.

`manual-changelog: CHANGELOG.md` in `.pkgmeta` tells the packager to read this file.

## Addon manager UX

End users mostly use addon managers, not manual installs:

- **CurseForge App** (curseforge.com/download) — official client, Windows/Mac. Handles install/update/profiles. Recently stripped Overwolf, lighter than past versions.
- **WowUp** (wowup.io) — third-party, multi-source (CF, Wago, WoWI, GitHub). Open-source. Works on Windows/Mac/Linux.
- **Ajour** (ajour.app) — minimal Rust-based; Linux-friendly.
- **CurseBreaker** (CLI) — terminal-based; popular with power users.

For your addon to be discoverable by these managers, you must have a CurseForge or Wago project page (the project ID is what the manager queries). WoWInterface IDs work too but are less universally supported.

## Manual install path (for the user)

If the user is local-installing for testing:

```
1. Close WoW completely (not just /reload).
2. Copy the addon folder to:
   C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\
3. Launch WoW.
4. At character select, click "AddOns" (lower-left).
5. Find the addon, check the box, click "Reload UI" or just log in.
```

For Classic, replace `_retail_` with `_classic_` (Mists Classic), `_classic_era_` (Vanilla Classic), or `_anniversary_` (current Anniversary realms).

`scripts/install-addon.ps1` automates the copy step.

## Updating an addon manually

```
1. Close WoW.
2. Delete the old addon folder from Interface\AddOns\.
3. Drop the new folder in.
4. Launch.
```

Don't merge directories — file removals between versions stay around if you don't delete first. SavedVariables in `WTF\` are unaffected; settings persist across updates.

## SavedVariables backup before major updates

Before installing a major version of any addon, back up:

```powershell
Copy-Item -Path "C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account\<ACCT>\SavedVariables" -Destination "<backup-dest>" -Recurse
```

If the new version mishandles old SVs, restoring is one copy.

## Addon Studio (Visual Studio plugin)

For Windows users who prefer IDE workflow: Microsoft AddOn Studio for WoW (the project's still maintained though much community work happens in VS Code with Lua language server). Provides syntax highlighting, debugger integration with live game (limited), and `.toc` template scaffolding.

Most modern dev happens in VS Code with the Lua extension and Sumneko's lua-language-server, which understands WoW's API via type stubs (search `vscode-wow-bundle` or `sumneko.lua` Wowfile bundles).
