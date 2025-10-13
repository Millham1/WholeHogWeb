param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) { Write-Error "File not found: $Path"; exit 1 }

# --- Read + backup ---
$abs  = (Resolve-Path -LiteralPath $Path).Path
$html = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup: $bak"

# --- Landing-style CSS blocks (single-quoted here-strings; no interpolation) ---
$styleHeader = @'
<!-- WH HARD HEADER START -->
<style id="wh-hard-header">
  :root { --wh-header-h: 2.25in; }
  header, .header, .app-header, .site-header, #header {
    min-height: var(--wh-header-h) !important;
    height: var(--wh-header-h) !important;
    position: relative !important;
    display: flex !important;
    align-items: center !important;
    justify-content: center !important;
  }
  header h1, .header h1, .app-header h1, .site-header h1, #header h1 {
    margin: 0 !important; line-height: 1.1 !important;
  }
  /* Left logo */
  header img#logoLeft, #header img#logoLeft, header .left-img, #header .left-img,
  header .brand-left img, #header .brand-left img, header img:first-of-type {
    position: absolute !important; left: 14px !important; top: 50% !important;
    transform: translateY(-50%) !important; height: calc(100% - 20px) !important; width: auto !important;
  }
  /* Right logo */
  header img.right-img, #header img.right-img, header .brand-right img, #header .brand-right img,
  header img:last-of-type {
    position: absolute !important; right: 14px !important; top: 50% !important;
    transform: translateY(-50%) !important; height: calc(100% - 20px) !important; width: auto !important;
  }
</style>
<!-- WH HARD HEADER END -->
'@

$styleNav = @'
<!-- WH NAV STYLE (red buttons centered) -->
<style id="wh-nav-style">
  #top-go-buttons{
    width:100%; margin:12px auto;
    display:flex; justify-content:center; align-items:center;
    gap:12px; flex-wrap:wrap; text-align:center;
  }
  #top-go-buttons a{
    background:#e53935 !important; color:#000 !important; font-weight:800 !important;
    border:2px solid #000 !important; border-radius:10px !important; padding:10px 14px !important;
    text-decoration:none !important; display:inline-flex !important; align-items:center !important; gap:8px !important;
  }
  #top-go-buttons a:hover{ filter: brightness(0.9); }
</style>
'@

$headerHtml = @'
<header class="header" style="height:2.25in; min-height:2.25in; position:relative; display:flex; align-items:center; justify-content:center;">
  <img id="logoLeft" src="Legion whole hog logo.png" alt="Logo" />
  <h1 style="margin:0; text-align:center;">Reports</h1>
  <img class="right-img" src="AL Medallion.png" alt="Logo" />
  <div class="page-title" style="font-weight:700;font-size:1.4rem;margin-left:8px">Reports</div>
</header>
'@

# Helper: regex replace with flags
function RxReplace([string]$input, [string]$pattern, [string]$replacement) {
  return [regex]::Replace($input, $pattern, $replacement, 'IgnoreCase, Singleline')
}

$updated = $html
$changed = $false

# --- 1) Ensure styles inside <head> ---
# Replace existing style blocks by id, else insert before </head>
$hasHead = $updated -match '(?is)</head\s*>'

# Replace or insert wh-hard-header
if ($updated -match '(?is)<style[^>]*\bid\s*=\s*["'']wh-hard-header["''][^>]*>.*?</style>') {
  $updated = RxReplace $updated '(?is)<style[^>]*\bid\s*=\s*["'']wh-hard-header["''][^>]*>.*?</style>' $styleHeader
  $changed = $true
} elseif ($hasHead) {
  $updated = RxReplace $updated '(?is)</head\s*>' ($styleHeader + "`r`n</head>")
  $changed = $true
} else {
  # No head? Prepend at top as last resort
  $updated = $styleHeader + "`r`n" + $updated
  $changed = $true
}

# Replace or insert wh-nav-style
if ($updated -match '(?is)<style[^>]*\bid\s*=\s*["'']wh-nav-style["''][^>]*>.*?</style>') {
  $updated = RxReplace $updated '(?is)<style[^>]*\bid\s*=\s*["'']wh-nav-style["''][^>]*>.*?</style>' $styleNav
  $changed = $true
} elseif ($hasHead) {
  $updated = RxReplace $updated '(?is)</head\s*>' ($styleNav + "`r`n</head>")
  $changed = $true
} else {
  $updated = $styleNav + "`r`n" + $updated
  $changed = $true
}

# --- 2) Replace existing <header>…</header> with landing-style header ---
if ($updated -match '(?is)<header\b[^>]*>.*?</header>') {
  $updated = RxReplace $updated '(?is)<header\b[^>]*>.*?</header>' $headerHtml
  $changed = $true
} elseif ($updated -match '(?is)<body\b[^>]*>') {
  # Insert immediately after <body> if no header exists
  $updated = RxReplace $updated '(?is)(<body\b[^>]*>)' ("`$1`r`n" + $headerHtml)
  $changed = $true
} else {
  # As a last resort, prepend header
  $updated = $headerHtml + "`r`n" + $updated
  $changed = $true
}

# --- Save ---
if ($changed) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Applied landing-style header and nav button styles to $abs" -ForegroundColor Green
} else {
  Write-Host "ℹ️ No changes made (content already matched)." -ForegroundColor Yellow
}
