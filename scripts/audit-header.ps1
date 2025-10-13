[CmdletBinding()]
param(
  [string]$Root = ".",
  [switch]$FixMissing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path -LiteralPath $Root).Path
Set-Location -LiteralPath $Root

function New-Backup {
  param([Parameter(Mandatory)][string]$Path)
  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
  }
}

function Has-SiteHeader { param([string]$Html) return [Regex]::IsMatch($Html, '<header[^>]*\bid\s*=\s*["'']site-header["'']', 'IgnoreCase') }
function Has-AnyHeader  { param([string]$Html) return [Regex]::IsMatch($Html, '<header\b', 'IgnoreCase') }

$files = Get-ChildItem -LiteralPath $Root -Recurse -Include *.html -File

$report = foreach ($f in $files) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw
  $hasSiteHeader = Has-SiteHeader $raw
  $hasAnyHeader  = Has-AnyHeader  $raw
  $fixed = $false

  if (-not $hasSiteHeader -and $FixMissing) {
    if ($raw -match '<body[^>]*>') {
      New-Backup -Path $f.FullName
      $new = [Regex]::Replace(
        $raw,
        '(<body[^>]*>)',
        "`$1`n  <header id=""site-header""></header>",
        'IgnoreCase'
      )
      [IO.File]::WriteAllText($f.FullName, $new, [Text.UTF8Encoding]::new($false))
      $hasSiteHeader = $true
      $fixed = $true
    }
  }

  [PSCustomObject]@{
    File            = $f.FullName.Replace($Root, '.')
    HasSiteHeader   = $hasSiteHeader
    HasAnyHeaderTag = $hasAnyHeader
    FixedNow        = $fixed
  }
}

# Proper multi-key sort: primary HasSiteHeader (desc), then File (asc)
$report |
  Sort-Object -Property @{Expression='HasSiteHeader';Descending=$true}, @{Expression='File';Descending=$false} |
  Format-Table -AutoSize

# Summary
$with   = ($report | Where-Object HasSiteHeader).Count
$without= ($report | Where-Object { -not $_.HasSiteHeader }).Count
$fixed  = ($report | Where-Object FixedNow).Count

Write-Host ""
Write-Host "Pages with <header id=""site-header""> : $with"
Write-Host "Pages missing it                 : $without"
if ($FixMissing) { Write-Host "Pages updated this run           : $fixed" }
