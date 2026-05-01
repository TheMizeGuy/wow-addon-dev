<#
.SYNOPSIS
    List installed WoW addons and their TOC metadata.

.DESCRIPTION
    Walks the Interface\AddOns folder for the requested edition and prints each
    addon's Title, Version, Interface, and Author from its .toc file.

.PARAMETER Edition
    retail (default), classic (Mists), classic_era (Vanilla), or anniversary.

.PARAMETER WowPath
    Optional override for the WoW install root.

.PARAMETER Filter
    Optional substring filter on addon folder name.

.PARAMETER OutdatedOnly
    Show only addons whose Interface field is below the current client.

.EXAMPLE
    .\list-installed-addons.ps1
    .\list-installed-addons.ps1 -Edition classic
    .\list-installed-addons.ps1 -Filter DBM
    .\list-installed-addons.ps1 -OutdatedOnly
#>

[CmdletBinding()]
param(
    [ValidateSet('retail', 'classic', 'classic_era', 'anniversary')]
    [string]$Edition = 'retail',

    [string]$WowPath = 'C:\Program Files (x86)\World of Warcraft',

    [string]$Filter,

    [switch]$OutdatedOnly
)

$editionMap = @{
    retail       = '_retail_'
    classic      = '_classic_'
    classic_era  = '_classic_era_'
    anniversary  = '_anniversary_'
}

$editionDir = $editionMap[$Edition]
$addonsRoot = Join-Path $WowPath "$editionDir\Interface\AddOns"

if (-not (Test-Path -LiteralPath $addonsRoot)) {
    Write-Error "AddOns folder not found: $addonsRoot"
    exit 1
}

# Try to read the current build's interface number from the executable's version.
$currentInterface = $null
$exePath = Join-Path $WowPath "$editionDir\WowFoxer.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
    $exePath = Join-Path $WowPath "$editionDir\Wow.exe"
}
if (Test-Path -LiteralPath $exePath) {
    try {
        $info = (Get-Item -LiteralPath $exePath).VersionInfo
        $version = $info.FileVersion
        if ($version -match '^(\d+)\.(\d+)\.(\d+)') {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            $patch = [int]$Matches[3]
            $currentInterface = ($major * 10000) + ($minor * 100) + $patch
        }
    } catch {
        # Best-effort; silently continue without "outdated" comparison.
    }
}

function Read-TocMetadata {
    param([string]$Path)
    $meta = [ordered]@{}
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction SilentlyContinue) {
        if ($line -match '^##\s*([^:]+):\s*(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $meta[$key] = $value
        }
    }
    return $meta
}

$results = @()

Get-ChildItem -LiteralPath $addonsRoot -Directory | ForEach-Object {
    $folder = $_
    if ($Filter -and -not ($folder.Name -like "*$Filter*")) { return }

    # Pick the most-specific TOC for this edition.
    $tocCandidates = @(
        "$($folder.Name)_Mainline.toc",
        "$($folder.Name)_Standard.toc",
        "$($folder.Name).toc"
    )
    $tocPath = $null
    foreach ($candidate in $tocCandidates) {
        $maybe = Join-Path $folder.FullName $candidate
        if (Test-Path -LiteralPath $maybe) { $tocPath = $maybe; break }
    }
    if (-not $tocPath) { return }

    $meta = Read-TocMetadata $tocPath

    $interface = $meta['Interface']
    $isOutdated = $false
    if ($currentInterface -and $interface) {
        # Pick the highest in a comma-separated list.
        $tocInterfaces = $interface -split ',' | ForEach-Object { [int]($_.Trim()) }
        $maxToc = ($tocInterfaces | Measure-Object -Maximum).Maximum
        if ($maxToc -lt $currentInterface) { $isOutdated = $true }
    }

    if ($OutdatedOnly -and -not $isOutdated) { return }

    $results += [pscustomobject]@{
        Folder    = $folder.Name
        Title     = $meta['Title']
        Version   = $meta['Version']
        Interface = $interface
        Author    = $meta['Author']
        Outdated  = $isOutdated
    }
}

if ($currentInterface) {
    Write-Host "Current $Edition client interface: $currentInterface" -ForegroundColor Cyan
}
Write-Host "Found $($results.Count) addon(s) in $addonsRoot" -ForegroundColor Cyan
Write-Host ""

$results | Sort-Object Folder | Format-Table -AutoSize @(
    @{ Name = 'Folder';    Expression = 'Folder' }
    @{ Name = 'Title';     Expression = { if ($_.Title.Length -gt 40) { $_.Title.Substring(0,37) + '...' } else { $_.Title } } }
    @{ Name = 'Version';   Expression = 'Version' }
    @{ Name = 'Interface'; Expression = 'Interface' }
    @{ Name = 'Outdated';  Expression = { if ($_.Outdated) { 'YES' } else { '' } } }
    @{ Name = 'Author';    Expression = 'Author' }
)
