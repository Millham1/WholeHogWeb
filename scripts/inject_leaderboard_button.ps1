# inject_leaderboard_button.ps1 — add ONE "Go to Leaderboard" button to your landing page(s)
# Run from: C:\Users\millh_y3006x1\Desktop\WholeHogWeb
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"

function Say($msg,[ConsoleColor]$c=[ConsoleColor]::Cyan){ Write-Host "`n==> $msg" -ForegroundColor $c }
function Info($msg){ Write-Host "   • $msg" -ForegroundColor DarkGray }
function Ok($msg){ Write-Host "   • $msg" -ForegroundColor Green }
function Warn($msg){ Write-Host "   • $msg" -ForegroundColor Yellow }

# ----- guards -----
$here = [System.IO.Path]::GetFullPath((Get-Location).Path)
if ($here -ne $Root) { throw "Run this script from: $Root (current: $here)" }
if (-not (Test-Path (Join-Path $Root "package.json"))) { throw "package.json not found in $Root." }

# ----- helpers -----
function Is-RouteGroupPath([string]$appDir,[string]$fullPath){
  $rel = [IO.Path]::GetRelativePath($appDir, $fullPath)
  $dir = Split-Path $rel
  if ([string]::IsNullOrEmpty($dir)) { return $true } # directly under /app
  $segs = $dir.Split([char][IO.Path]::DirectorySeparatorChar)
  foreach($s in $segs){ if ($s -notmatch '^\(.*\)$') { return $false } }
  return $true
}

function Find-LandingCandidates([string]$root){
  $targets = @()
  foreach($base in @($root, (Join-Path $root "src"))){
    if (-not (Test-Path $base)) { continue }
    $app   = Join-Path $base "app"
    $pages = Join-Path $base "pages"

    if (Test-Path $app) {
      foreach($f in @("page.tsx","page.jsx")){
        $p = Join-Path $app $f
        if (Test-Path $p) { $targets += $p }
      }
      $allPages = Get-ChildItem -Path $app -Recurse -Include page.tsx,page.jsx -File -ErrorAction SilentlyContinue
      foreach($pg in $allPages){
        if (Is-RouteGroupPath $app $pg.FullName) { $targets += $pg.FullName }
      }
    }

    if (Test-Path $pages) {
      foreach($f in @("index.tsx","index.jsx")){
        $p = Join-Path $pages $f
        if (Test-Path $p) { $targets += $p }
      }
    }
  }
  return ($targets | Sort-Object -Unique)
}

function Insert-Lines([string[]]$arr, [int]$index, [string[]]$newLines){
  if ($index -lt 0) { $index = 0 }
  if ($index -gt $arr.Count) { $index = $arr.Count }
  $before = if ($index -eq 0) { @() } else { $arr[0..($index-1)] }
  $after  = if ($index -ge $arr.Count) { @() } else { $arr[$index..($arr.Count-1)] }
  return @($before + $newLines + $after)
}

function Patch-LandingFile([string]$filePath){
  Info "Patching: $filePath"
  $orig = Get-Content $filePath -Raw
  $bak = "$filePath.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
  $orig | Set-Content -Path $bak -Encoding UTF8
  Info "Backup: $bak"

  $lines = $orig -split "`r?`n"

  # 1) ensure Link import (keep 'use client' on top if present)
  $hasImport = ($orig -like '*from "next/link"*') -or ($orig -like "*from 'next/link'*")
  if (-not $hasImport){
    $insertIdx = 0
    if ($lines.Count -gt 0) {
      $first = $lines[0].Trim()
      if ($first -eq "'use client'" -or $first -eq '"use client"') { $insertIdx = 1 }
      $lastImportIdx = -1
      for ($i=0; $i -lt $lines.Count; $i++){
        if ($lines[$i].TrimStart().StartsWith("import ")) { $lastImportIdx = $i }
      }
      if ($lastImportIdx -ge 0 -and $lastImportIdx + 1 -gt $insertIdx) { $insertIdx = $lastImportIdx + 1 }
    }
    $lines = Insert-Lines $lines $insertIdx @('import Link from "next/link";')
  }

  # 2) insert ONE small button block if not already present
  $already = ($lines -join "`n") -like '*data-wholehog-leaderboard-btn*'
  if (-not $already){
@'
{/* WHOLEHOG_LEADERBOARD_BTN_START */}
<div className="mt-4" data-wholehog-leaderboard-btn>
  <Link href="/leaderboard" className="inline-flex items-center rounded-2xl border px-4 py-2 text-sm hover:shadow">
    Go to Leaderboard
  </Link>
</div>
{/* WHOLEHOG_LEADERBOARD_BTN_END */}
'@ | Out-String | ForEach-Object {
      $snippet = ($_ -split "`r?`n")
      # find an insertion anchor: first <section ...>, else first <main ...>, else end
      $insertAt = -1
      for ($i=0; $i -lt $lines.Count; $i++){ if ($lines[$i].Contains("<section")) { $insertAt = $i + 1; break } }
      if ($insertAt -eq -1){ for ($i=0; $i -lt $lines.Count; $i++){ if ($lines[$i].Contains("<main")) { $insertAt = $i + 1; break } } }
      if ($insertAt -eq -1){ $insertAt = $lines.Count } # append
      $lines = Insert-Lines $lines $insertAt $snippet
    }
  }

  $finalText = $lines -join "`r`n"
  Set-Content -Path $filePath -Encoding UTF8 -Value $finalText

  # 3) verify
  $final = Get-Content $filePath -Raw
  $hasLink = ($final -like '*from "next/link"*') -or ($final -like "*from 'next/link'*")
  if (-not $hasLink) { throw "File ${filePath} missing import Link after patch." }
  if ($final -notlike '*href="/leaderboard"*') { throw "File ${filePath} missing /leaderboard link after patch." }

  Ok "Patched OK: $filePath"
}

# ----- run -----
Say "Finding landing candidates"
$cands = Find-LandingCandidates $Root
if (-not $cands -or $cands.Count -eq 0){
  Warn "No landing candidates found under app/ or pages/ (including src/ variants)."
  $scan = Get-ChildItem -Recurse -Include page.tsx,page.jsx,index.tsx,index.jsx -File -ErrorAction SilentlyContinue
  if ($scan){ $scan | ForEach-Object { Write-Host "   • found: $($_.FullName)" } }
  throw "Tell me the exact path to your landing file and I will patch that single file."
}

Write-Host "   • Candidates:" -ForegroundColor DarkGray
$cands | ForEach-Object { Write-Host "     - $_" -ForegroundColor DarkGray }

Say "Injecting 'Go to Leaderboard' button"
foreach($p in $cands){ Patch-LandingFile $p }

Say "Done"
Write-Host "Reload your app (Ctrl+F5). The landing now contains a 'Go to Leaderboard' button." -ForegroundColor Yellow
