<#
.SYNOPSIS
    Print the current Interface number for each installed WoW edition.

.DESCRIPTION
    Reads the Wow.exe (or equivalent) file version for each edition and
    converts it to the Interface number addons should use in their TOC.

.PARAMETER WowPath
    Optional override for the WoW install root.

.EXAMPLE
    .\get-interface-version.ps1
#>

[CmdletBinding()]
param(
    [string]$WowPath = 'C:\Program Files (x86)\World of Warcraft'
)

$editions = @(
    @{ Name = 'retail';       Dir = '_retail_';      DisplayName = 'Retail (Mainline)' }
    @{ Name = 'classic';      Dir = '_classic_';     DisplayName = 'Classic (current expansion)' }
    @{ Name = 'classic_era';  Dir = '_classic_era_'; DisplayName = 'Classic Era / Vanilla' }
    @{ Name = 'anniversary';  Dir = '_anniversary_'; DisplayName = 'Anniversary' }
)

$results = @()

foreach ($e in $editions) {
    $editionPath = Join-Path $WowPath $e.Dir
    if (-not (Test-Path -LiteralPath $editionPath)) { continue }

    $exeCandidates = @('Wow.exe', 'WowClassic.exe', 'WowB.exe', 'WowT.exe')
    $exePath = $null
    foreach ($c in $exeCandidates) {
        $maybe = Join-Path $editionPath $c
        if (Test-Path -LiteralPath $maybe) { $exePath = $maybe; break }
    }
    if (-not $exePath) {
        # As a fallback, find any .exe in the edition root
        $exePath = Get-ChildItem -LiteralPath $editionPath -Filter '*.exe' -File |
                   Where-Object { $_.Name -ne 'WowError.exe' } |
                   Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $exePath) { continue }

    $version = (Get-Item -LiteralPath $exePath).VersionInfo.FileVersion
    $interface = $null
    $patch = $null
    if ($version -match '^(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        $patch = [int]$Matches[3]
        $interface = ($major * 10000) + ($minor * 100) + $patch
    }

    $results += [pscustomobject]@{
        Edition       = $e.DisplayName
        Folder        = $e.Dir
        ExeVersion    = $version
        InterfaceNumber = $interface
        TocLine       = if ($interface) { "## Interface: $interface" } else { '(could not derive)' }
    }
}

if ($results.Count -eq 0) {
    Write-Error "No WoW editions found under $WowPath"
    exit 1
}

$results | Format-Table -AutoSize -Property Edition, Folder, ExeVersion, InterfaceNumber, TocLine
