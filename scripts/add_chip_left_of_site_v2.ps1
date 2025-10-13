# add_chip_left_of_site_v2.ps1
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

# --- Helpers ---
function RX([string]$p){ return [regex]::new($p,[System.Text.RegularExpressions.RegexOptions] 'IgnoreCase, Singleline') }
function Remove-Match([ref]$text, $m){
  if($m -and $m.Success){ $text.Value = $text.Value.Remove($m.Index,$m.Length); return $true } else { return $false }
}

# Remove any prior injected chip/site row to avoid duplicates
$html = [regex]::Replace($html,'(?is)<span[^>]*\bid\s*=\s*"wh-chip-site-row"[^>]*>[\s\S]*?</span>','')

# 1) Locate existing Site field by id/name/placeholder containing "site" (case-insensitive)
$rxSiteInputByAttr = RX('(?is)(<input\b[^>]*?(?:id|name|placeholder)\s*=\s*["''][^"'']*site[^"'']*["''][^>]*>)')
$siteInputM = $rxSiteInputByAttr.Match($html)

# Try to capture a wrapping label if the input lives inside one
$siteLabelM = $null
$siteBlockInner = $null
$anchorIndex = 0
if ($siteInputM.Success) {
  $siteInputTag = $siteInputM.Groups[1].Value
  $esc = [regex]::Escape($siteInputTag)
  $rxLabelWrap = RX("(?is)(<label\b[^>]*>[\s\S]*?$esc[\s\S]*?</label>)")
  $siteLabelM = $rxLabelWrap.Match($html)
  if ($siteLabelM.Success) {
    $siteBlockInner = $siteLabelM.Groups[1].Value
    $anchorIndex = $siteLabelM.Index
    # Remove original label+input block
    $tmp = $html; Remove-Match ([ref]$tmp) $siteLabelM | Out-Null; $html = $tmp
  } else {
    # Use bare input; remove it and wrap in label with "Site #"
    $siteBlockInner = '<label>Site # ' + $siteInputTag + '</label>'
    $anchorIndex = $siteInputM.Index
    $html = $html.Remove($siteInputM.Index, $siteInputM.Length)
  }
} else {
  # No site found anywhere — synthesize a new one and place it before Add Team
  $siteBlockInner = '<label>Site # <input id="site" class="input" placeholder="7"></label>'
  # Anchor before Add Team button if present; else end of form; else top of page
  $rxAdd = RX('(?is)(<button\b[^>]*>[^<]*add\s*team[^<]*</button>|<input\b[^>]*type\s*=\s*["'']submit["''][^>]*\bvalue\s*=\s*["''][^"']*add\s*team[^"']*["'][^>]*>)')
  $mAdd = $rxAdd.Match($html)
  if ($mAdd.Success) { $anchorIndex = $mAdd.Index } else { $anchorIndex = 0 }
}

# 2) Get (or create) Chip field; keep existing input if found
$rxChipLabel = RX('(?is)(<label\b[^>]*>[\s\S]*?Chip\s*#?[\s\S]*?<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>[\s\S]*?</label>)')
$rxChipInput = RX('(?is)(<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>)')

$chipBlockInner = $null
$chipLM = $rxChipLabel.Match($html)
if ($chipLM.Success) {
  $chipBlockInner = $chipLM.Groups[1].Value
  $tmp = $html; Remove-Match ([ref]$tmp) $chipLM | Out-Null; $html = $tmp
} else {
  $chipIM = $rxChipInput.Match($html)
  if ($chipIM.Success) {
    $chipTag = $chipIM.Groups[1].Value
    $html = $html.Remove($chipIM.Index,$chipIM.Length)
    $chipBlockInner = '<label>Chip # ' + $chipTag + '</label>'
  } else {
    $chipBlockInner = '<label>Chip # <input id="chip" type="text" class="input" placeholder="A12"></label>'
  }
}

# Make Chip compact (max-width) if no style on the input already
$chipBlockInner = $chipBlockInner -replace '(?is)^<label','<label id="wh-chip-wrap"'
if ($chipBlockInner -notmatch '(?is)\bid\s*=\s*["'']chip["''][^>]*\bstyle\s*='){
  $chipBlockInner = $chipBlockInner -replace '(?is)(<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*)(>)','$1 style="max-width:120px"$2'
}

# 3) Wrap both fields into a neat inline row and insert where Site originally was
$siteBlock = '<span id="wh-site-wrap" style="display:flex;flex-direction:column;min-width:140px;">' + $siteBlockInner + '</span>'
$chipBlock = '<span style="display:flex;flex-direction:column;min-width:120px;">' + $chipBlockInner + '</span>'
$row = '<span id="wh-chip-site-row" style="display:inline-flex;gap:12px;align-items:flex-end;">' + $chipBlock + $siteBlock + '</span>'

# Insert at anchorIndex
$html = $html.Substring(0,$anchorIndex) + $row + $html.Substring($anchorIndex)

# 4) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Added 'Chip #' left of 'Site #' and aligned both on one row. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
