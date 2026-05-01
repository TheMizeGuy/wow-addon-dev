<#
.SYNOPSIS
    Validate a WoW addon TOC file.

.DESCRIPTION
    Checks:
      - File / folder name match
      - Required directives present (Interface, Title)
      - Interface field is numeric (or comma-separated numeric)
      - Each referenced file exists in the addon folder
      - SavedVariables names look like valid Lua identifiers
      - Optional dependencies resolve to existing addons (best-effort)

.PARAMETER TocPath
    Path to a .toc file. Required.

.PARAMETER AddonsRoot
    Optional AddOns folder for cross-checking dependency existence.
    Defaults to the parent-of-parent of TocPath.

.EXAMPLE
    .\validate-toc.ps1 'C:\...\Interface\AddOns\MyAddon\MyAddon.toc'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TocPath,

    [string]$AddonsRoot
)

if (-not (Test-Path -LiteralPath $TocPath -PathType Leaf)) {
    Write-Error "Not a file: $TocPath"
    exit 1
}

$tocFile = Get-Item -LiteralPath $TocPath
$addonFolder = $tocFile.Directory
$addonName = $addonFolder.Name

if (-not $AddonsRoot) {
    $AddonsRoot = $addonFolder.Parent.FullName
}

$problems = @()
$warnings = @()
$ok = @()

# 1. File / folder name match
$validTocNames = @(
    "$addonName.toc"
    "$addonName`_Mainline.toc"
    "$addonName`_Standard.toc"
    "$addonName`_Mists.toc"
    "$addonName`_Cata.toc"
    "$addonName`_Wrath.toc"
    "$addonName`_TBC.toc"
    "$addonName`_Vanilla.toc"
    "$addonName`_Classic.toc"
)
if ($tocFile.Name -in $validTocNames) {
    $ok += "TOC name '$($tocFile.Name)' matches folder '$addonName'."
} else {
    $problems += "TOC name '$($tocFile.Name)' does not match folder '$addonName'. Expected one of: $($validTocNames -join ', ')"
}

# 2. Parse the TOC
$lines = Get-Content -LiteralPath $TocPath -Encoding UTF8
$directives = [ordered]@{}
$fileReferences = @()

foreach ($rawLine in $lines) {
    $line = $rawLine.TrimStart()
    if ($line -eq '') { continue }
    if ($line.StartsWith('##')) {
        if ($line -match '^##\s*([^:]+):\s*(.*?)\s*$') {
            $directives[$Matches[1].Trim()] = $Matches[2]
        } else {
            $warnings += "Line looks like a directive but doesn't parse: $rawLine"
        }
    } elseif ($line.StartsWith('#')) {
        # comment
        continue
    } else {
        # File reference. May have [AllowLoadGameType ...] suffix.
        $fileLine = $line -replace '\s*\[[^\]]+\]\s*$', ''
        $fileLine = $fileLine.Trim()
        if ($fileLine -ne '') { $fileReferences += $fileLine }
    }
}

# 3. Required directives
foreach ($req in @('Interface', 'Title')) {
    if (-not $directives.Contains($req)) {
        $problems += "Missing required directive: ## $req"
    } else {
        $ok += "Has ## $req`: $($directives[$req])"
    }
}

# 4. Interface number format
if ($directives.Contains('Interface')) {
    $iface = $directives['Interface']
    $parts = $iface -split ',' | ForEach-Object { $_.Trim() }
    foreach ($p in $parts) {
        if ($p -notmatch '^\d{5,6}$') {
            $problems += "Interface part '$p' is not a 5-6 digit number."
        }
    }
}

# 5. File references exist
foreach ($f in $fileReferences) {
    $fullPath = Join-Path $addonFolder.FullName $f
    if (Test-Path -LiteralPath $fullPath) {
        $ok += "File exists: $f"
    } else {
        $problems += "TOC references missing file: $f (expected at $fullPath)"
    }
}

# 6. SavedVariables look like Lua identifiers
foreach ($k in @('SavedVariables', 'SavedVariablesPerCharacter')) {
    if ($directives.Contains($k)) {
        $names = $directives[$k] -split ',' | ForEach-Object { $_.Trim() }
        foreach ($n in $names) {
            if ($n -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                $problems += "$k entry '$n' is not a valid Lua identifier."
            }
        }
    }
}

# 7. Dependency existence (best-effort)
foreach ($k in @('Dependencies', 'RequiredDeps', 'OptionalDeps', 'LoadWith')) {
    if ($directives.Contains($k)) {
        $deps = $directives[$k] -split ',' | ForEach-Object { $_.Trim() }
        foreach ($d in $deps) {
            if ($d -eq '') { continue }
            if ($d.StartsWith('Blizzard_')) { continue }  # built-in LoD addons
            $depPath = Join-Path $AddonsRoot $d
            if (-not (Test-Path -LiteralPath $depPath)) {
                if ($k -eq 'OptionalDeps') {
                    $warnings += "OptionalDep '$d' not found in $AddonsRoot (optional, fine if intentional)."
                } else {
                    $problems += "$k '$d' not found in $AddonsRoot."
                }
            }
        }
    }
}

# Output
Write-Host "Validating $TocPath" -ForegroundColor Cyan
Write-Host ""

if ($ok.Count -gt 0) {
    foreach ($m in $ok) { Write-Host "  ok    $m" -ForegroundColor Green }
}
if ($warnings.Count -gt 0) {
    Write-Host ""
    foreach ($m in $warnings) { Write-Host "  warn  $m" -ForegroundColor Yellow }
}
if ($problems.Count -gt 0) {
    Write-Host ""
    foreach ($m in $problems) { Write-Host "  FAIL  $m" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Validation FAILED with $($problems.Count) problem(s)." -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "Validation PASSED." -ForegroundColor Green
    exit 0
}
