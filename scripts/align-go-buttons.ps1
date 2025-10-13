param(
  [Parameter(Mandatory=$true)]
  [string[]]$Files
)

function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8NoBom([string]$p, [string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $s, $enc)
}
function Backup([string]$p){
  if (!(Test-Path $p)) { throw "File not found: $p" }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $bak = "$p.$stamp.bak"
  Copy-Item $p $bak -Force | Out-Null
  return $bak
}

# Minimal CSS that only affects nav containers and spacing
$styleBlock = @'
<style id="wh-go-buttons-align-override">
  /* Center and evenly space the nav row on this page only */
  #wholehog-nav,
  #top-go-buttons {
    max-width: 820px;                 /* pulls buttons toward center */
    margin: 12px auto;                 /* centers the whole row */
    display: flex;
    justify-content: center;           /* center row */
    align-items: center;
    gap: 12px;                         /* even spacing between buttons */
    flex-wrap: wrap;
    text-align: center;
  }
  /* Keep button widths visually consistent without changing existing colors */
  #wholehog-nav a,
  #top-go-buttons a,
  #top-go-buttons button,
  #wholehog-nav button {
    min-width: 180px;                  /* consistent width */
  }
</style>
'@

foreach ($f in $Files) {
  if (!(Test-Path $f)) { Write-Host "⚠️  Skipped (missing): $f"; continue }

  $html = Read-Utf8NoBom $f

  # Skip if already aligned
  if ($html -match '(?is)id\s*=\s*["'']wh-go-buttons-align-override["'']') {
    Write-Host "ℹ️ Already aligned: $f"
    continue
  }

  # Backup
  $bak = Backup $f
  Write-Host "🔒 Backup created: $bak"

  # Insert the style before </head> if possible; otherwise prepend
  if ($html -match '(?is)</head\s*>') {
    $html = [regex]::Replace($html, '(?is)</head\s*>', ($styleBlock + "`r`n</head>"), 1)
  } else {
    $html = $styleBlock + "`r`n" + $html
  }

  Write-Utf8NoBom $f $html
  Write-Host "✅ Aligned nav buttons: $f"
}
