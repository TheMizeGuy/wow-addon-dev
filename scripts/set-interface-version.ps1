<#
.SYNOPSIS
    Bump the ## Interface: directive across every TOC in an addon.

.DESCRIPTION
    Updates the Interface line in the addon's primary TOC and every per-edition
    variant (_Mainline.toc, _Classic.toc, etc.). Preserves comma-separated
    multi-edition lists by replacing only the matching segment.

.PARAMETER AddonFolder
    Path to the addon folder.

.PARAMETER NewInterface
    New interface number (e.g. 120005). Pass 'auto' to derive from
    get-interface-version.ps1 for the matching edition (default).

.PARAMETER WowPath
    Optional override for WoW install root.

.EXAMPLE
    .\set-interface-version.ps1 'C:\src\MyAddon' 120005
    .\set-interface-version.ps1 'C:\src\MyAddon' auto
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AddonFolder,

    [Parameter(Mandatory = $true)]
    [string]$NewInterface,

    [string]$WowPath = 'C:\Program Files (x86)\World of Warcraft'
)

if (-not (Test-Path -LiteralPath $AddonFolder -PathType Container)) {
    Write-Error "AddonFolder not found: $AddonFolder"
    exit 1
}

$addonItem = Get-Item -LiteralPath $AddonFolder

# Per-edition suffix → which auto-derived interface to use.
$suffixToEdition = @{
    '_Mainline'   = 'retail'
    '_Standard'   = 'retail'
    '_Mists'      = 'classic'
    '_Cata'       = 'classic'
    '_Wrath'      = 'classic'
    '_TBC'        = 'classic_era'
    '_Vanilla'    = 'classic_era'
    '_Classic'    = 'classic_era'
}

function Get-AutoInterface {
    param([string]$Edition)
    $editionMap = @{
        retail       = '_retail_'
        classic      = '_classic_'
        classic_era  = '_classic_era_'
        anniversary  = '_anniversary_'
    }
    $exePath = Join-Path $WowPath "$($editionMap[$Edition])\Wow.exe"
    if (-not (Test-Path -LiteralPath $exePath)) { return $null }
    $version = (Get-Item -LiteralPath $exePath).VersionInfo.FileVersion
    if ($version -match '^(\d+)\.(\d+)\.(\d+)') {
        return ([int]$Matches[1] * 10000) + ([int]$Matches[2] * 100) + [int]$Matches[3]
    }
    return $null
}

$tocFiles = Get-ChildItem -LiteralPath $addonItem.FullName -Filter '*.toc' -File
if ($tocFiles.Count -eq 0) {
    Write-Error "No .toc files in $($addonItem.FullName)"
    exit 1
}

foreach ($toc in $tocFiles) {
    # Determine target interface for this TOC.
    $iface = $NewInterface
    if ($iface -eq 'auto') {
        $base = $toc.BaseName  # e.g. MyAddon_Mainline
        $suffix = ($base -split '_', 2)[1]
        $edition = if ($suffix) { $suffixToEdition["_$suffix"] } else { 'retail' }
        if (-not $edition) { $edition = 'retail' }
        $iface = Get-AutoInterface $edition
        if (-not $iface) {
            Write-Warning "Could not auto-derive interface for $($toc.Name) (edition=$edition); skipping."
            continue
        }
    }

    $lines = Get-Content -LiteralPath $toc.FullName -Encoding UTF8
    $changed = $false
    $newLines = @()
    foreach ($line in $lines) {
        if ($line -match '^##\s*Interface:\s*(.+)$') {
            $oldVal = $Matches[1].Trim()
            $newLines += "## Interface: $iface"
            if ($oldVal -ne "$iface") {
                Write-Host "  $($toc.Name): $oldVal -> $iface" -ForegroundColor Cyan
                $changed = $true
            } else {
                Write-Host "  $($toc.Name): already $iface" -ForegroundColor DarkGray
            }
        } else {
            $newLines += $line
        }
    }

    if ($changed) {
        Set-Content -LiteralPath $toc.FullName -Value $newLines -Encoding UTF8
    }
}

Write-Host "Done." -ForegroundColor Green
