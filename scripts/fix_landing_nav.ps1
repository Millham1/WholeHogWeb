# fix_landing_nav.ps1 — surgically patch landing page with 3 nav buttons (no DB changes)
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

# --- 0) Verify path & find landing file ---
Step "Verifying project root"
$here = [IO.Path]::GetFullPath((Get-Location).Path)
if ($here -ne (Resolve-Path $ProjectRoot)) { throw "Run this script from: $ProjectRoot (current: $here)" }
if (-not (Test-Path (Join-Path $here "package.json"))) { throw "package.json not found. This assumes an existing Next.js project." }

Step "Locating landing file"
$candidates = @(
  "app\page.tsx","app\page.jsx",
  "src\app\page.tsx","src\app\page.jsx",
  "pages\index.tsx","pages\index.jsx",
  "src\pages\index.tsx","src\pages\index.jsx"
) | ForEach-Object { Join-Path $here $_ }

$found = $candidates | Where-Object { Test-Path $_ }
if (-not $found) {
  Warn "No standard landing file found."
  $scan = Get-ChildItem -Recurse -Include page.tsx,page.jsx,index.tsx,index.jsx -File -ErrorAction SilentlyContinue
  if ($scan) { $scan | ForEach-Object { Write-Host "   • found: $($_.FullName)" } }
  throw "Could not find app/page.* or pages/index.*. Tell me the exact path of your landing file and I’ll target it."
}

# Prefer app/page over pages/index; prefer tsx over jsx
$landingPath =
  ($found | Where-Object { $_ -match "\\app\\page\.tsx$" } | Select-Object -First 1) `
  ?? ($found | Where-Object { $_ -match "\\app\\page\.jsx$" } | Select-Object -First 1) `
  ?? ($found | Where-Object { $_ -match "\\pages\\index\.tsx$" } | Select-Object -First 1) `
  ?? ($found | Where-Object { $_ -match "\\pages\\index\.jsx$" } | Select-Object -First 1)

Write-Host "   • Using landing file: $landingPath"

# --- 1) Read + backup file ---
$original = Get-Content $landingPath -Raw
$bak = "$landingPath.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
$original | Set-Content -Path $bak -Encoding UTF8
Info "Backup created: $bak"

# --- 2) Ensure `import Link from "next/link";` exists (respect 'use client' on top) ---
$needsLinkImport = -not ($original -match "from\s+[`"']next/link[`"']")
$lines = $original -split "`r?`n"

if ($needsLinkImport) {
  # Look for 'use client' on the very first line (regex must use doubled single quotes inside a single-quoted string)
  $insertIdx = 0
  if ($lines.Length -gt 0 -and $lines[0] -match '^\s*((''use client'')|"use client");?\s*$') {
    $insertIdx = 1
  }
  # Else insert after the last existing import
  $lastImportIdx = -1
  for ($i=0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^\s*import\s+.*;?\s*$') { $lastImportIdx = $i }
  }
  if ($lastImportIdx -ge 0) { $insertIdx = [Math]::Max($insertIdx, $lastImportIdx + 1) }
  $lines = Insert-LineAt $lines $insertIdx 'import Link from "next/link";'
  $patched = $lines -join "`r`n"
} else {
  $patched = $original
}

# --- 3) Insert/replace the nav block ---
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
  # Replace existing block
  $patched = [regex]::Replace(
    $patched,
    '\{\s*\/\* WHOLEHOG_NAV_START \*\/\}[\s\S]*?\{\s*\/\* WHOLEHOG_NAV_END \*\/\}',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $navBlock }
  )
} else {
  # Insert after <section ...> if present; else after <main ...>; else append at end
  $patchedLines = $patched -split "`r?`n"
  $mSection = $patchedLines | Select-String -Pattern '<section\b' | Select-Object -First 1
  if ($mSection) {
    $insertAt = [int]$mSection.LineNumber  # insert *after* the <section> line
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

# --- 4) Write back & verify ---
$patched | Set-Content -Path $landingPath -Encoding UTF8
Ok "Patched landing file: $landingPath"

Step "Verifying links"
$final = Get-Content $landingPath -Raw
$must = @('href="/on-site"','href="/blind-taste"','href="/leaderboard"','from "next/link"')
foreach($m in $must){
  if (-not ($final -match [regex]::Escape($m))) {
    throw "Verification failed: missing '$m' in $landingPath"
  }
}
Ok "Landing page contains all three buttons and Link import."

# --- 5) Show a quick preview (first 30 lines) ---
Step "Preview (first 30 lines)"
(Get-Content $landingPath -TotalCount 30) | ForEach-Object { Write-Host "   $_" }

Step "Done"
Write-Host "Reload your app (Ctrl+F5). If the buttons still don't show, your app might be rendering a different file; tell me the real landing path and I’ll target it." -ForegroundColor Yellow

