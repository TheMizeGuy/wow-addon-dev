<#
.SYNOPSIS
    Install a WoW addon by copying its folder into Interface\AddOns.

.DESCRIPTION
    Copies the source folder (or all addon folders inside it, if it's a release
    extract that contains multiple addons side-by-side) into the requested
    edition's Interface\AddOns. Asks for confirmation before overwriting an
    existing addon. Excludes .git, .github, .vscode, and *.bak files.

.PARAMETER Source
    Source folder. Either a single addon folder (contains .toc) or a parent
    folder containing multiple addon folders side-by-side.

.PARAMETER Edition
    Target WoW edition. Defaults to retail.

.PARAMETER WowPath
    Optional override for WoW install root.

.PARAMETER Force
    Overwrite existing addon folder without prompting.

.EXAMPLE
    .\install-addon.ps1 'C:\src\MyAddon'
    .\install-addon.ps1 'C:\Downloads\AddonRelease' -Edition classic
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [ValidateSet('retail', 'classic', 'classic_era', 'anniversary')]
    [string]$Edition = 'retail',

    [string]$WowPath = 'C:\Program Files (x86)\World of Warcraft',

    [switch]$Force
)

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    Write-Error "Source folder not found: $Source"
    exit 1
}

$editionMap = @{
    retail       = '_retail_'
    classic      = '_classic_'
    classic_era  = '_classic_era_'
    anniversary  = '_anniversary_'
}

$addonsRoot = Join-Path $WowPath "$($editionMap[$Edition])\Interface\AddOns"
if (-not (Test-Path -LiteralPath $addonsRoot)) {
    Write-Error "AddOns folder not found: $addonsRoot"
    exit 1
}

$srcItem = Get-Item -LiteralPath $Source

# Determine: is Source a single addon or a parent of multiple addons?
$tocsHere = Get-ChildItem -LiteralPath $Source -Filter '*.toc' -File -ErrorAction SilentlyContinue
$childAddons = @()
if ($tocsHere.Count -gt 0) {
    # Single addon
    $childAddons += $srcItem
} else {
    # Parent: gather subfolders that contain a TOC
    Get-ChildItem -LiteralPath $Source -Directory | ForEach-Object {
        if (Get-ChildItem -LiteralPath $_.FullName -Filter '*.toc' -File -ErrorAction SilentlyContinue) {
            $childAddons += $_
        }
    }
}

if ($childAddons.Count -eq 0) {
    Write-Error "No addon folder (with .toc) found at or under $Source"
    exit 1
}

Write-Host "Installing $($childAddons.Count) addon(s) into $addonsRoot" -ForegroundColor Cyan

$exclude = @('.git', '.github', '.vscode', 'node_modules')

foreach ($addon in $childAddons) {
    $dest = Join-Path $addonsRoot $addon.Name
    if (Test-Path -LiteralPath $dest) {
        if (-not $Force) {
            $resp = Read-Host "Addon '$($addon.Name)' already installed at $dest. Overwrite? [y/N]"
            if ($resp -notmatch '^[Yy]') {
                Write-Host "  skipped: $($addon.Name)" -ForegroundColor Yellow
                continue
            }
        }
        Remove-Item -LiteralPath $dest -Recurse -Force
    }

    Write-Host "  installing $($addon.Name)..." -ForegroundColor Cyan

    # Use robocopy for the main copy (handles long paths, excludes)
    $robocopyArgs = @(
        $addon.FullName,
        $dest,
        '/E',
        '/XD'
        ) + $exclude + @(
        '/XF', '*.bak', '*.psd', '*.ai',
        '/NFL', '/NDL', '/NJH', '/NJS', '/NC', '/NS', '/NP'
    )
    & robocopy.exe @robocopyArgs | Out-Null

    if ($LASTEXITCODE -gt 7) {
        Write-Error "robocopy failed (exit $LASTEXITCODE) for $($addon.Name)"
        continue
    }

    Write-Host "  ok: $($addon.Name) -> $dest" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Fully restart WoW (not /reload) for new addons to be detected." -ForegroundColor Yellow
