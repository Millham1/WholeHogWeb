# fix_onsite_href_only.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Backup
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# Read file
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# Find the anchor whose VISIBLE TEXT mentions "Go to On-Site" (dash optional)
$rxA      = '(?is)<a\b[^>]*>[\s\S]*?<\/a>'
$rxOnText = '(?i)go\s*to\s*on\s*-?\s*site'

$matches = [regex]::Matches($html, $rxA)
$changed = $false

foreach ($m in $matches) {
  $a = $m.Value
  # get inner text and strip tags
  $inner = [regex]::Replace($a,'(?is)^<a\b[^>]*>|</a>$','')
  $innerText = [regex]::Replace($inner,'<[^>]+>',' ')
  if ([regex]::IsMatch($innerText, $rxOnText)) {
    $a2 = $a
    if ($a2 -match '(?i)href\s*=\s*"[^"]*"') {
      $a2 = [regex]::Replace($a2,'(?i)href\s*=\s*"[^"]*"','href="./onsite.html"',1)
    } elseif ($a2 -match "(?i)href\s*=\s*'[^']*'") {
      $a2 = [regex]::Replace($a2,"(?i)href\s*=\s*'[^']*'","href='./onsite.html'",1)
    } else {
      $a2 = [regex]::Replace($a2,'(?is)^<a\b','<a href="./onsite.html"',1)
    }

    if ($a2 -ne $a) {
      $html = $html.Replace($a, $a2)
      $changed = $true
    }
    break
  }
}

# Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host ("Done. " + ($(if($changed){"Updated On-Site href."}else{"No matching On-Site button text found."})) + " Backup: $([IO.Path]::GetFileName($bak))") -ForegroundColor Green
Start-Process $file
