param([Parameter(Mandatory=$true)][string]$Path)

if(-not (Test-Path -LiteralPath $Path)){ Write-Error "File not found: $Path"; exit 1 }

# Backup first
$abs = (Resolve-Path -LiteralPath $Path).Path
$orig = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup: $bak"

# Helper: add display:none to the *opening* tag that contains the given id
function Hide-ByIdTag([string]$html, [string]$id){
  # Find opening tag with that id (button/div, etc.)
  $pat = "(?is)<(?<tag>[\w:-]+)(?<attrs>[^>]*\bid\s*=\s*['""]$([regex]::Escape($id))['""][^>]*)>"
  return [regex]::Replace($html, $pat, {
    param($m)
    $tag   = $m.Groups['tag'].Value
    $attrs = $m.Groups['attrs'].Value
    # If style exists, append display:none; else add a new style attribute
    if($attrs -match '(?i)\bstyle\s*=\s*["'']'){
      $attrs = [regex]::Replace($attrs, '(?is)\bstyle\s*=\s*([\'"])(.*?)\1', {
        param($n)
        $q=$n.Groups[1].Value; $val=$n.Groups[2].Value
        "$([string]::Format('style={0}{1}{0}', $q, ($val.TrimEnd(';') + '; display:none;')))"
      }, 1)
    } else {
      $attrs += ' style="display:none"'
    }
    # Strip any inline onclick to avoid accidental downloads
    $attrs = [regex]::Replace($attrs, '(?is)\s+onclick\s*=\s*([\'"]).*?\1', '')
    "<$tag$attrs>"
  }, 1)
}

$updated = $orig
$idsToHide = @(
  'wh-build-report-btn',     # original button id
  'wh-build-report2-btn',    # detailed button id
  'wh-report-hint'           # tip block id
)

foreach($id in $idsToHide){
  $new = Hide-ByIdTag $updated $id
  if($new -ne $updated){
    $updated = $new
    Write-Host "• Hid element id='$id'"
  } else {
    # Fallback: hide by button text if id missing
    if($id -eq 'wh-build-report-btn'){
      $updated = [regex]::Replace($updated, '(?is)<button\b([^>]*)>\s*Build\s+Report\s*\(CSV\)\s*</button>', '<button$1 style="display:none">Build Report (CSV)</button>', 1)
    }
    if($id -eq 'wh-build-report2-btn'){
      $updated = [regex]::Replace($updated, '(?is)<button\b([^>]*)>\s*Build\s+Detailed\s+Report\s*\(CSV\)\s*</button>', '<button$1 style="display:none">Build Detailed Report (CSV)</button>', 1)
    }
  }
}

if($updated -ne $orig){
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Report buttons/tip are now hidden (page structure untouched)."
} else {
  Write-Host "ℹ️ No matching report UI found; nothing changed."
}
