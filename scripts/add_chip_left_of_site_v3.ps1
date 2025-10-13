# add_chip_left_of_site_v3.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# --- Backup ---
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# --- Read ---
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# Remove any prior injection to avoid duplicates
$html = [regex]::Replace($html,'(?is)<span[^>]*\bid\s*=\s*"wh-chip-site-row"[^>]*>[\s\S]*?</span>','')

# --- Helpers ---
function RX([string]$p){ return [regex]::new($p,[System.Text.RegularExpressions.RegexOptions] 'IgnoreCase, Singleline') }
function Remove-Match([ref]$text, $m){
  if($m -and $m.Success){ $text.Value = $text.Value.Remove($m.Index,$m.Length); return $true } else { return $false }
}

# --- 1) Locate the Site # field (be flexible) ---
# Prefer a <label> ... Site #/Number ... <input> ... </label>
$rxSiteLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?Site\s*(?:#|Number)[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
$rxSiteInput = @'
(?is)(<input\b[^>]*\b(?:id|name|placeholder)\s*=\s*["'][^"']*site[^"']*["'][^>]*>)
'@

$siteLabelM = [regex]::Match($html,$rxSiteLabel,'IgnoreCase,Singleline')
$siteBlockInner = $null
$anchorIndex = 0

if ($siteLabelM.Success) {
  $siteBlockInner = $siteLabelM.Groups[1].Value
  $anchorIndex = $siteLabelM.Index
  # Remove original block
  $tmp = $html; Remove-Match ([ref]$tmp) $siteLabelM | Out-Null; $html = $tmp
} else {
  $siteInputM = [regex]::Match($html,$rxSiteInput,'IgnoreCase,Singleline')
  if ($siteInputM.Success) {
    $siteInputTag = $siteInputM.Groups[1].Value
    $anchorIndex = $siteInputM.Index
    # Remove original input
    $html = $html.Remove($siteInputM.Index,$siteInputM.Length)
    $siteBlockInner = '<label>Site # ' + $siteInputTag + '</label>'
  } else {
    # No site found: synthesize a simple Site field and anchor near Add Team (or top)
    $siteBlockInner = '<label>Site # <input id="site" class="input" placeholder="7"></label>'
    $rxAdd1 = @'
(?is)(<button\b[^>]*>[\s\S]*?add\s*team[\s\S]*?</button>)
'@
    $rxAdd2 = @'
(?is)(<input\b[^>]*\btype\s*=\s*["']submit["'][^>]*\bvalue\s*=\s*["'][^"']*add\s*team[^"']*["'][^>]*>)
'@
    $mAdd = [regex]::Match($html,$rxAdd1,'IgnoreCase,Singleline')
    if (-not $mAdd.Success) { $mAdd = [regex]::Match($html,$rxAdd2,'IgnoreCase,Singleline') }
    $anchorIndex = if ($mAdd.Success) { $mAdd.Index } else { 0 }
  }
}

# --- 2) Get existing Chip field or create one; make it compact ---
$rxChipLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?Chip[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
$rxChipInput = @'
(?is)(<input\b[^>]*\b(?:id|name|placeholder)\s*=\s*["'][^"']*chip[^"']*["'][^>]*>)
'@

$chipBlockInner = $null
$chipLM = [regex]::Match($html,$rxChipLabel,'IgnoreCase,Singleline')
if ($chipLM.Success) {
  $chipBlockInner = $chipLM.Groups[1].Value
  $tmp = $html; Remove-Match ([ref]$tmp) $chipLM | Out-Null; $html = $tmp
} else {
  $chipIM = [regex]::Match($html,$rxChipInput,'IgnoreCase,Singleline')
  if ($chipIM.Success) {
    $chipTag = $chipIM.Groups[1].Value
    $html = $html.Remove($chipIM.Index,$chipIM.Length)
    $chipBlockInner = '<label>Chip # ' + $chipTag + '</label>'
  } else {
    $chipBlockInner = '<label>Chip # <input id="chip" type="text" class="input" placeholder="A12"></label>'
  }
}

# Ensure chip input has id="chip" and compact width
if ($chipBlockInner -notmatch '(?i)\bid\s*=\s*["'']chip["'']') {
  # Add id on the first input within chip label
  $chipBlockInner = [regex]::Replace($chipBlockInner,'(?is)<input\b','<input id="chip"',1)
}
if ($chipBlockInner -notmatch '(?is)\bid\s*=\s*["'']chip["''][^>]*\bstyle\s*=') {
  $chipBlockInner = [regex]::Replace($chipBlockInner,'(?is)(<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*)(>)','$1 style="max-width:120px"$2',1)
}

# --- 3) Build small inline row [Chip][Site] and insert at original site location ---
$siteBlock = '<span id="wh-site-wrap" style="display:flex;flex-direction:column;min-width:140px;">' + $siteBlockInner + '</span>'
$chipBlock = '<span id="wh-chip-wrap" style="display:flex;flex-direction:column;min-width:120px;">' + $chipBlockInner + '</span>'
$row = '<span id="wh-chip-site-row" style="display:inline-flex;gap:12px;align-items:flex-end;">' + $chipBlock + $siteBlock + '</span>'

$html = $html.Substring(0,$anchorIndex) + $row + $html.Substring($anchorIndex)

# --- 4) Write back ---
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Added 'Chip #' to the left of 'Site #', aligned in one row. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
