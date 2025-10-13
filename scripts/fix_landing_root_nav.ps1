
# fix_landing_root_nav.ps1 — patch ALL possible root landing pages with 3 nav buttons (no DB changes)
# Run from: C:\Users\millh_y3006x1\Desktop\WholeHogWeb
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"

function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "   • $m" -ForegroundColor Green }
function Warn($m){ Write-Host "   • $m" -ForegroundColor Yellow }
function Info($m){ Write-Host "   • $m" -ForegroundColor DarkGray }

function Insert-LineAt([string[]]$arr, [int]$index, [string]$line) {
  if ($index -lt 0) { $index = 0 }
  if ($index -gt $arr.Count) { $index = $arr.Count }
  $before = if ($index -eq 0) { @() } else { $arr[0..($index-1)] }
  $after  = if ($index -ge $arr.Count) { @() } else { $arr[$index..($arr.Count-1)] }
  return @($before + $line + $after)
}

function Patch-Landing([string]$filePath) {
  Info "Patching: $filePath"

  $original = Get-Content $filePath -Raw
  $bak = "$filePath.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
  $original | Set-Content -Path $bak -Encoding UTF8
  Info "Backup: $bak"

  # 1) Ensure Link import (respect 'use client' at the very top if present)
  $needsLinkImport = -not ($original -match "from\s+[`"']next/link[`"']")
  $lines = $original -split "`r?`n"
  $patched = $original

  if ($needsLinkImport) {
    $insertIdx = 0
    if ($lines.Length -gt 0 -and $lines[0] -match '^\s*((''use client'')|"use client");?\s*$') { $insertIdx = 1 }
    $lastImportIdx = -1
    for ($i=0; $i -lt $lines.Length; $i++) { if ($lines[$i] -match '^\s*import\s+.*;?\s*$') { $lastImportIdx = $i } }
    if ($lastImportIdx -ge 0) { $insertIdx = [Math]::Max($insertIdx, $lastImportIdx + 1) }
    $lines = Insert-LineAt $lines $insertIdx 'import Link from "next/link";'
    $patched = $lines -join "`r`n"
  }

  # 2) Insert/replace nav block
  $navBlock = @'
{/* WHOLEHOG_NAV_START */}
<div className="flex flex-wrap items-center gap-3">
  <Link href="/on-site" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to On-Site</Link>
  <Link href="/blind-taste" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Blind Taste</Link>
  <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">Go to Leaderboard</Link>
</div>
{/* WHOLEHOG_NAV_END */}
'@

  if ($patched -match '\{\s*\/\* WHOLEHOG_NAV_START \*\/\}[\s\S]*?\{\s*\/\* WHOLEHOG_NAV_END \*\/\}') {
    $patched = [regex]::Replace(
      $patched,
      '\{\s*\/\* WHOLEHOG_NAV_START \*\/\}[\s\S]*?\{\s*\/\* WHOLEHOG_NAV_END \*\/\}',
      [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $navBlock }
    )
  } else {
    $patchedLines = $patched -split "`r?`n"
    $mSection = $patchedLines | Select-String -Pattern '<section\b' | Select-Object -First 1
    if ($mSection) {
      $insertAt = [int]$mSection.LineNumber
      $before = if ($insertAt -lt 1) { @() } else { $patchedLines[0..($insertAt-1)] }
      $after  = $patchedLines[$insertAt..($patchedLines.Length-1)]
      $patchedLines = @($before + $navBlock + $after)
    } else {
      $mMain = $patchedLines | Select-String -Pattern '<main\b' | Select-Object -First 1
      if ($mMain) {
        $insertAt = [int]$mMain.LineNumber
        $before = if ($insertAt -lt 1) { @() } else { $patchedLines[0..$insertAt] }
        $after  = $patchedLines[($insertAt+1)..($patchedLines.Length-1)]
        $patchedLines = @($before + $navBlock + $after)
      } else {
        $patchedLines += $navBlock
      }
    }
    $patched = $patchedLines -join "`r`n"
  }

  $patched | Set-Content -Path $filePath -Encoding UTF8

  # 3) Verify
  $final = Get-Content $filePath -Raw
  foreach($m in @('href="/on-site"','href="/blind-taste"','href="/leaderboard"','from "next/link"')){
    if (-not ($final -match [regex]::Escape($m))) {
      throw "Verification failed in ${filePath}: missing '$m'"
    }
  }
  Ok "Patched OK: $filePath"
}

# --- Verify root and discover all root landing files (support route groups) ---
Step "Verifying project root"
$here = [IO.Path]::GetFullPath((Get-Location).Path)
if ($here -ne (Resolve-Path $ProjectRoot)) { throw "Run this script from: $ProjectRoot (current: $here)" }
if (-not (Test-Path (Join-Path $here "package.json"))) { throw "package.json not found. This assumes an existing Next.js project." }

Step "Discovering root landing files"
$baseDirs = @($here, (Join-Path $here "src")) | Where-Object { Test-Path $_ }
$targets = @()

foreach($base in $baseDirs){
  $appDir   = Join-Path $base "app"
  $pagesDir = Join-Path $base "pages"

  if (Test-Path $appDir) {
    foreach($f in @("page.tsx","page.jsx")){
      $p = Join-Path $appDir $f
      if (Test-Path $p) { $targets += $p }
    }
    # Find app/(...)/page.* where all subfolders are route groups (wrapped in parentheses)
    $allPages = Get-ChildItem -Path $appDir -Recurse -Include page.tsx,page.jsx -File -ErrorAction SilentlyContinue
    foreach($pg in $allPages){
      $rel = [IO.Path]::GetRelativePath($appDir, $pg.FullName)
      $dir = Split-Path $rel
      if ([string]::IsNullOrEmpty($dir)) { continue }
      # FIX: don't use -split '\' (regex). Use .Split(char) to handle backslashes literally.
      $segments = $dir.Split([char][IO.Path]::DirectorySeparatorChar)
      $isOnlyGroups = $true
      foreach($seg in $segments){
        if ($seg -notmatch '^\(.*\)$') { $isOnlyGroups = $false; break }
      }
      if ($isOnlyGroups) { $targets += $pg.FullName }
    }
  }

  if (Test-Path $pagesDir) {
    foreach($f in @("index.tsx","index.jsx")){
      $p = Join-Path $pagesDir $f
      if (Test-Path $p) { $targets += $p }
    }
  }
}

$targets = $targets | Sort-Object -Unique
if (-not $targets) {
  Warn "No root landing candidates found."
  $scan = Get-ChildItem -Recurse -Include page.tsx,page.jsx,index.tsx,index.jsx -File -ErrorAction SilentlyContinue
  if ($scan) { $scan | ForEach-Object { Write-Host "   • found: $($_.FullName)" } }
  throw "Tell me which file is your landing page and I’ll target it."
}

Write-Host "   • Candidates:"
$targets | ForEach-Object { Write-Host "     - $_" }

# --- Patch each candidate (safe: each has its own .bak) ---
Step "Patching candidates"
foreach($t in $targets){ Patch-Landing $t }

Step "Done"
Write-Host "Reload the app (Ctrl+F5). One of the patched files is your actual '/' route. If nothing changes, paste the 'Candidates' list above here." -ForegroundColor Yellow

