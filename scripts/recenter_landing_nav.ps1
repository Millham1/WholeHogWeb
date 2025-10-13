# recenter_landing_nav.ps1
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

# 1) Update ONLY the href for the anchor whose text mentions “Go to On-Site”
$rxA      = [regex]::new('(?is)<a\b[^>]*>[\s\S]*?</a>')
$rxOnText = [regex]::new('(?i)go\s*to\s*on\s*-?\s*site')
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
    if ($a2 -ne $a) { $html = $html.Replace($a,$a2) }
    break
  }
}

# 2) Ensure centered, horizontal layout for the three buttons (scoped to #wholehog-nav only)
#    Replace any prior style with the same id, then insert fresh before </head> (or prepend if no head)
$styleBlock = @'
<style id="wholehog-nav-style">
  /* force centered horizontal row for the nav buttons only */
  #wholehog-nav{
    width:100%;
    margin:12px auto;
    display:flex;
    justify-content:center !important;
    align-items:center;
    gap:12px;
    flex-wrap:wrap;
    text-align:center;
  }
  #wholehog-nav a{
    display:inline-block;
    white-space:nowrap;
    width:auto !important;
    float:none !important;
  }
</style>
'@

# Remove any previous block with this id
$html = [regex]::Replace($html,'(?is)<style[^>]*id\s*=\s*"wholehog-nav-style"[^>]*>[\s\S]*?</style>','')

# Insert style block
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$styleBlock + "`r`n</head>",1)
} else {
  $html = $styleBlock + "`r`n" + $html
}

# Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Fixed On-Site link and re-centered nav without moving elements. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $file
