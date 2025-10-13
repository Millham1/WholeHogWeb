param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path $WebRoot)) { throw "Web root not found: $WebRoot" }

# Target common files; if you want to scan everything, switch to: Get-ChildItem -Recurse -Include *.html,*.js,*.css
$targets = @(
  'landing.html','onsite.html','blind.html',
  'landing-sb.js','onsite-sb.js','blind-sb.js',
  'styles.css'
) | ForEach-Object { Join-Path $WebRoot $_ } | Where-Object { Test-Path $_ }

if (-not $targets) {
  # fallback: all html/js/css in root
  $targets = Get-ChildItem -LiteralPath $WebRoot -File -Include *.html,*.js,*.css | Select-Object -Expand FullName
}

if (-not $targets) { throw "No HTML/JS/CSS files found under $WebRoot." }

# Backup
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$bak   = Join-Path $WebRoot "BACKUP_encoding_$stamp"
New-Item -ItemType Directory -Force -Path $bak | Out-Null
foreach($f in $targets){ Copy-Item $f (Join-Path $bak (Split-Path $f -Leaf)) -Force }
Write-Host "Backup saved: $bak" -ForegroundColor Yellow

$latin1 = [Text.Encoding]::GetEncoding(28591)  # ISO-8859-1
$utf8   = [Text.Encoding]::UTF8

function EnsureUtf8Meta([string]$htmlText){
  if ($htmlText -notmatch '(?i)<meta\s+charset\s*=\s*["' + "'" + ']utf-8["' + "'" + ']') {
    return ($htmlText -replace '(?is)(<head\b[^>]*>)', '$1' + "`r`n  <meta charset=`"utf-8`">")
  }
  return $htmlText
}

$fixedCount = 0
foreach($path in $targets){
  $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
  $text = Get-Content -LiteralPath $path -Raw -Encoding utf8

  # Heuristic: if we see typical mojibake lead chars (Ã or â), attempt round-trip fix
  $looksBad = $text -match 'Ã|â'
  $new = $text

  if ($looksBad) {
    $bytes = $latin1.GetBytes($text)          # treat current text as Latin-1 bytes
    $round = $utf8.GetString($bytes)          # decode as UTF-8 ➜ intended Unicode
    # accept if it actually improved things (i.e., removed Ã/â artifacts or changed)
    if (($round -ne $text) -and ($round -notmatch 'Ã|â')) {
      $new = $round
      $fixedCount++
      Write-Host ("Re-encoded: {0}" -f (Split-Path $path -Leaf)) -ForegroundColor Green
    } else {
      Write-Host ("Skipped (no improvement): {0}" -f (Split-Path $path -Leaf)) -ForegroundColor DarkGray
    }
  } else {
    Write-Host ("Clean already: {0}" -f (Split-Path $path -Leaf)) -ForegroundColor DarkGray
  }

  if ($ext -eq '.html') {
    $before = $new
    $new = EnsureUtf8Meta $new
    if ($new -ne $before) { Write-Host ("Inserted UTF-8 meta: {0}" -f (Split-Path $path -Leaf)) -ForegroundColor Cyan }
  }

  if ($new -ne $text) {
    # PS7 default is UTF8 without BOM; make it explicit
    Set-Content -LiteralPath $path -Value $new -Encoding utf8
  }
}

Write-Host ""
Write-Host ("Done. Files fixed: {0}. Now hard-refresh your pages (Ctrl+F5)." -f $fixedCount) -ForegroundColor Cyan
Write-Host "If anything still looks off, clear localStorage in the browser console:" -ForegroundColor DarkGray
Write-Host "localStorage.clear(); location.reload(true);" -ForegroundColor DarkGray

