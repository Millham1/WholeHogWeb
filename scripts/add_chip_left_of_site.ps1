# add_chip_left_of_site.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# --- Backup ---
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# --- Read file ---
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# --- Helpers ---
function RX([string]$p){ return [regex]::new($p,[System.Text.RegularExpressions.RegexOptions] 'IgnoreCase, Singleline') }
function Remove-Match([ref]$text, $m){
  if($m -and $m.Success){ $text.Value = $text.Value.Remove($m.Index,$m.Length); return $true } else { return $false }
}

# --- 1) Find the Site # element we will anchor on ---
$rxSiteLabel = RX('(?is)(<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum)["''][^>]*>[\s\S]*?</label>)')
$rxSiteInput = RX('(?is)(<input\b[^>]*\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum)["''][^>]*>)')

$siteLabelM = $rxSiteLabel.Match($html)
$siteInputM = $rxSiteInput.Match($html)

if(-not $siteLabelM.Success -and -not $siteInputM.Success){
  throw "Couldn’t find a Site # field (no input with id site/site_number/siteNo/siteNum)."
}

# Standardize the Site block as a label + input wrapped in a span (so label is on same row)
if($siteLabelM.Success){
  $siteInner = $siteLabelM.Groups[1].Value
  # Ensure label text contains "Site #"
  if($siteInner -notmatch '(?i)Site\s*#'){
    $siteInner = $siteInner -replace '(?is)<label\b([^>]*)>','<label$1>Site # '
  }
  $siteBlock = '<span id="wh-site-wrap" style="display:flex;flex-direction:column;min-width:140px;">' + $siteInner + '</span>'
  $anchorIndex = $siteLabelM.Index
  # Remove original site label block
  $tmp = $html; Remove-Match ([ref]$tmp) $siteLabelM | Out-Null; $html = $tmp
} else {
  $siteInputTag = $siteInputM.Groups[1].Value
  $siteBlock = '<span id="wh-site-wrap" style="display:flex;flex-direction:column;min-width:140px;"><label>Site # ' + $siteInputTag + '</label></span>'
  $anchorIndex = $siteInputM.Index
  # Remove original bare input
  $html = $html.Remove($siteInputM.Index, $siteInputM.Length)
}

# --- 2) Find an existing Chip field; if none, create it. Then make it compact. ---
$rxChipLabel = RX('(?is)(<label\b[^>]*>[\s\S]*?Chip\s*#?[\s\S]*?<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>[\s\S]*?</label>)')
$rxChipInput = RX('(?is)(<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>)')

$chipBlock = $null

$chipLM = $rxChipLabel.Match($html)
if($chipLM.Success){
  $chipBlock = $chipLM.Groups[1].Value
  # Remove original location
  $tmp = $html; Remove-Match ([ref]$tmp) $chipLM | Out-Null; $html = $tmp
} else {
  $chipIM = $rxChipInput.Match($html)
  if($chipIM.Success){
    $chipTag = $chipIM.Groups[1].Value
    # Remove original location
    $html = $html.Remove($chipIM.Index,$chipIM.Length)
    $chipBlock = '<label>Chip # ' + $chipTag + '</label>'
  } else {
    # Create a fresh Chip input
    $chipBlock = '<label>Chip # <input id="chip" type="text" class="input" placeholder="A12"></label>'
  }
}

# Wrap the chip in a span and make it compact
# Also ensure the input itself isn’t huge via inline width
# (If the chip input already has a style, we leave it; otherwise we cap width)
$chipBlock = $chipBlock -replace '(?is)^<label','<label id="wh-chip-wrap"'
if($chipBlock -notmatch '(?is)\bid\s*=\s*["'']chip["''][^>]*\bstyle\s*='){
  $chipBlock = $chipBlock -replace '(?is)(<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*)(>)','$1 style="max-width:120px"$2'
}
$chipBlock = '<span id="wh-chip-wrap" style="display:flex;flex-direction:column;min-width:120px;">' + $chipBlock + '</span>'

# --- 3) Build a small inline row: [Chip #][Site #] and insert it where Site # used to be ---
$row = '<span id="wh-chip-site-row" style="display:inline-flex;gap:12px;align-items:flex-end;">' + $chipBlock + $siteBlock + '</span>'

# Insert at anchorIndex (where Site was originally found)
$html = $html.Substring(0,$anchorIndex) + $row + $html.Substring($anchorIndex)

# --- 4) Write back ---
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Inserted 'Chip #' to the left of 'Site #' and aligned both on one row. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
