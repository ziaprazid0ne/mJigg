<#
.SYNOPSIS
    Combines the multi-file Start-mJig module into a single .psm1 for release.
.DESCRIPTION
    Reads Start-mJig.psm1 (the skeleton), finds every dot-source line that
    references a file under Private\, replaces it with the referenced file's
    contents (preserving the skeleton line's leading whitespace), and writes
    the combined output to dist\Start-mJig\Start-mJig.psm1.
#>
[CmdletBinding()]
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Split-Path $PSScriptRoot -Parent          # Start-mJig/
$projectRoot = Split-Path $moduleRoot -Parent            # repo root
if (-not $OutputDir) { $OutputDir = Join-Path $projectRoot 'dist' }
$skeletonPath = Join-Path $moduleRoot 'Start-mJig.psm1'
$manifestPath = Join-Path $moduleRoot 'Start-mJig.psd1'

if (-not (Test-Path $skeletonPath)) {
    throw "Skeleton not found: $skeletonPath"
}

$skeletonLines = Get-Content $skeletonPath
$outputLines = [System.Collections.Generic.List[string]]::new($skeletonLines.Count * 2)

$dotSourcePattern = '^\s*\.\s+"?\$PSScriptRoot\\Private\\.+\.ps1"?\s*$'

foreach ($line in $skeletonLines) {
    if ($line -match $dotSourcePattern) {
        $relPath = $line -replace '^\s*\.\s+"?\$PSScriptRoot\\', '' -replace '"?\s*$', ''
        $absPath = Join-Path $moduleRoot $relPath

        if (-not (Test-Path $absPath)) {
            throw "Referenced file not found: $absPath (from line: $line)"
        }

        $fileLines = Get-Content $absPath
        foreach ($fl in $fileLines) {
            $outputLines.Add($fl)
        }
    } else {
        $outputLines.Add($line)
    }
}

$outModuleDir = Join-Path $OutputDir 'Start-mJig'
if (-not (Test-Path $outModuleDir)) {
    New-Item -ItemType Directory -Path $outModuleDir -Force | Out-Null
}

$outPsm1 = Join-Path $outModuleDir 'Start-mJig.psm1'
$outputLines | Set-Content -Path $outPsm1 -Encoding UTF8
Write-Host "Built: $outPsm1 ($($outputLines.Count) lines)"

Copy-Item $manifestPath (Join-Path $outModuleDir 'Start-mJig.psd1') -Force
Write-Host "Copied manifest to: $(Join-Path $outModuleDir 'Start-mJig.psd1')"

Write-Host "`nBuild complete. Output in: $outModuleDir"
