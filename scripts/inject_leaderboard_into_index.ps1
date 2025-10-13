# inject_leaderboard_into_index.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$indexPath = Join-Path $root "index.html"
if (!(Test-Path $indexPath)) { throw "index.html not found at $indexPath" }

# Read current landing
$html = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8

# If already injected, exit cleanly
if ($html -match 'id="wholehog-leaderboard-btn"') {
  Write-Host "Leaderboard button already present. No changes made." -ForegroundColor Yellow
  exit 0
}

# Minimal snippet (keeps your styling; you can style .btn if you already have it)
$snippet = @'
<!-- WHOLEHOG: Leaderboard Button -->
<div id="wholehog-leaderboard-btn" style="margin-top:12px;">
  <a href="./leaderboard.html" class="btn btn-leaderboard">Go to Leaderboard</a>
</div>
<!-- /WHOLEHOG -->
'@

# Find insertion point: before </main>, else before </body>, else append
$inserted = $false
$rxMain  = [regex]'(?i)</main>'
$rxBody  = [regex]'(?i)</body>'

if (($m = $rxMain.Match($html)).Success) {
  $html2 = $html.Insert($m.Index, "$snippet`r`n")
  $inserted = $true
}
elseif (($m = $rxBody.Match($html)).Success) {
  $html2 = $html.Insert($m.Index, "$snippet`r`n")
  $inserted = $true
}
else {
  $html2 = $html + "`r`n" + $snippet
  $inserted = $true
}

if (-not $inserted) { throw "Could not determine insertion point." }

# Backup + write
$bak = "$indexPath.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Set-Content -LiteralPath $bak -Encoding UTF8 -Value $html
Set-Content -LiteralPath $indexPath -Encoding UTF8 -Value $html2

Write-Host "Injected Leaderboard button into index.html (backup created: $bak)" -ForegroundColor Green
