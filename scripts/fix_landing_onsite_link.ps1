# fix_landing_onsite_link.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Backup
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# Read
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8
$changes = 0

# 1) If href points to on-site.html (with/without ./), switch to ./onsite.html
$rxDbl = '(?i)href\s*=\s*"(?:\./)?on-?site\.html"'
$rxSgl = "(?i)href\s*=\s*'(?:\./)?on-?site\.html'"

$h2 = [regex]::Replace($html,$rxDbl,'href="./onsite.html"')
if ($h2 -ne $html) { $changes++; $html = $h2 }
$h2 = [regex]::Replace($html,$rxSgl,"href='./onsite.html'")
if ($h2 -ne $html) { $changes++; $html = $h2 }

# 2) Ensure the anchor whose text mentions "Go to On-Site" points to ./onsite.html
$rxA      = [regex]::new('(?is)<a\b[^>]*>[\s\S]*?</a>')
$rxOnText = [regex]::new('(?i)go\s*to\s*on\s*-?\s*site|on\s*-?\s*site\s*(?:\s*scoring)?')

foreach ($m in $rxA.Matches($html)) {
  $a = $m.Value
  $inner = [regex]::Replace($a,'(?is)^<a\b[^>]*>|</a>$','')
  $innerText = [regex]::Replace($inner,'<[^>]+>',' ')
  if ($rxOnText.IsMatch($innerText)) {
    $a2 = $a
    if ($a2 -match '(?i)href\s*=\s*"[^"]*"') {
      $a2 = [regex]::Replace($a2,'(?i)href\s*=\s*"[^"]*"','href="./onsite.html"',1)
    } elseif ($a2 -match "(?i)href\s*=\s*'[^']*'") {
      $a2 = [regex]::Replace($a2,"(?i)href\s*=\s*'[^']*'","href='./onsite.html'",1)
    } else {
      $a2 = $a2 -replace '(?i)^<a\b','<a href="./onsite.html"'
    }
    if ($a2 -ne $a) {
      $html = $html.Replace($a,$a2)
      $changes++
    }
  }
}

# Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "Updated landing.html. Changes made: $changes (backup: $([IO.Path]::GetFileName($bak)))." -ForegroundColor Green
Start-Process $file
