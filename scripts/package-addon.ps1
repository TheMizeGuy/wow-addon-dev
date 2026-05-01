<#
.SYNOPSIS
    Build a clean release zip for a WoW addon.

.DESCRIPTION
    Produces AddonName-VERSION.zip with the standard
    AddonName/AddonName.toc structure that addon managers and manual installers
    expect. Strips dev junk (.git, .github, .vscode, *.bak, *.psd).

.PARAMETER AddonFolder
    Path to the addon folder (the one containing .toc).

.PARAMETER OutputDir
    Where to drop the zip. Defaults to current working directory.

.PARAMETER Version
    Version string for the zip name. If omitted, reads from the TOC.

.EXAMPLE
    .\package-addon.ps1 'C:\src\MyAddon'
    .\package-addon.ps1 'C:\src\MyAddon' -OutputDir 'C:\out' -Version '1.2.3'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AddonFolder,

    [string]$OutputDir = (Get-Location).Path,

    [string]$Version
)

if (-not (Test-Path -LiteralPath $AddonFolder -PathType Container)) {
    Write-Error "AddonFolder not found: $AddonFolder"
    exit 1
}

$addonItem = Get-Item -LiteralPath $AddonFolder
$addonName = $addonItem.Name

# Locate primary TOC.
$tocFile = Get-ChildItem -LiteralPath $addonItem.FullName -Filter "$addonName*.toc" -File |
           Sort-Object Name |
           Select-Object -First 1
if (-not $tocFile) {
    Write-Error "No .toc matching '$addonName*.toc' in $($addonItem.FullName)"
    exit 1
}

# Extract Version from TOC if not supplied.
if (-not $Version) {
    foreach ($line in Get-Content -LiteralPath $tocFile.FullName -Encoding UTF8) {
        if ($line -match '^##\s*Version:\s*(.+?)\s*$') {
            $Version = $Matches[1]
            break
        }
    }
}
if (-not $Version) {
    $Version = '0.0.0'
    Write-Warning "No Version in TOC; using $Version"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$zipName = "$addonName-$Version.zip"
$zipPath = Join-Path $OutputDir $zipName
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

# Build a staging copy excluding dev junk.
$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) "wow-pkg-$([guid]::NewGuid().ToString('n'))"
$stagedAddon = Join-Path $stagingRoot $addonName
New-Item -ItemType Directory -Path $stagedAddon -Force | Out-Null

$exclude = @('.git', '.github', '.vscode', 'node_modules', '.idea')
$excludeFiles = @('*.bak', '*.psd', '*.ai', '*.tmp', '.DS_Store', 'Thumbs.db')

$robocopyArgs = @(
    $addonItem.FullName,
    $stagedAddon,
    '/E',
    '/XD'
) + $exclude + @(
    '/XF'
) + $excludeFiles + @(
    '/NFL', '/NDL', '/NJH', '/NJS', '/NC', '/NS', '/NP'
)
& robocopy.exe @robocopyArgs | Out-Null
if ($LASTEXITCODE -gt 7) {
    Write-Error "robocopy failed (exit $LASTEXITCODE)"
    exit 1
}

# Compress to zip.
Compress-Archive -Path $stagedAddon -DestinationPath $zipPath -Force

# Clean up staging.
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

$zipSize = (Get-Item -LiteralPath $zipPath).Length
Write-Host "Built $zipPath ($([math]::Round($zipSize / 1KB, 1)) KB)" -ForegroundColor Green
Write-Host "Layout: $addonName/$($tocFile.Name) [+ other addon files]" -ForegroundColor Cyan
