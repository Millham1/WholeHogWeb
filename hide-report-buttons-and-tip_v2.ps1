param([Parameter(Mandatory=$true)][string]$Path)

if(-not (Test-Path -LiteralPath $Path)){ Write-Error "File not found: $Path"; exit 1 }

# Backup first
$abs  = (Resolve-Path -LiteralPath $Path).Path
$orig = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup: $bak"

function Hide-ByIdTag {
  param([string]$html,[string]$id)

  # Build an id-targeting regex pattern safely
  $idEsc = [regex]::Escape($id)
  $pat   = "(?is)<(?<tag>[\w:-]+)(?<attrs>[^>]*\bid\s*=\s*['`"]$idEsc['`"][^>]*)>"

  return [regex]::Replace($html, $pat, {
    param($m)
    $tag   = $m.Groups['tag'].Value
    $attrs = $m.Groups['attrs'].Value

    # If style attribute exists, append 'display:none'; otherwise add new style
    if ($attrs -match "(?i)\bstyle\s*=\s*['`"]") {
      $attrs = [regex]::Replace(
        $attrs,
        "(?is)\bstyle\s*=\s*(['`"])(.*?)\1",
        {
          param($n)
          $q   = $n.Groups[1].Value
          $val = $n.Groups[2].Value
          "style=$q$($val.TrimEnd(';')); display:none;$q"
        },
        1
      )
    } else {
      $attrs += ' style="display:none"'
    }

    # Remove inline onclick to prevent old handlers from firing
    $attrs = [regex]::Replace($attrs, "(?is)\s+onclick\s*=\s*(['`"]).*?\1", "")

    "<$tag$attrs>"
  }, 1)
}

$updated = $orig

# Target IDs to hide (only these)
$idsToHide = @(
  'wh-build-report-btn',     # original report button
  'wh-build-report2-btn',    # detailed report button
  'wh-report-hint'           # tip block
)

foreach($id in $idsToHide){
  $new = Hide-ByIdTag -html $updated -id $id
  if($new -ne $updated){
    $updated = $new
    Write-Host "• Hid element id='$id'"
  } else {
    # Fallback by visible text if the id isn't present
    if($id -eq 'wh-build-report-btn'){
      $updated = [regex]::Replace(
        $updated,
        '(?is)<button\b([^>]*)>\s*Build\s+Report\s*\(CSV\)\s*</button>',
        '<button$1 style="display:none">Build Report (CSV)</button>',
        'IgnoreCase'
      )
    }
    if($id -eq 'wh-build-report2-btn'){
      $updated = [regex]::Replace(
        $updated,
        '(?is)<button\b([^>]*)>\s*Build\s+Detailed\s+Report\s*\(CSV\)\s*</button>',
        '<button$1 style="display:none">Build Detailed Report (CSV)</button>',
        'IgnoreCase'
      )
    }
    if($id -eq 'wh-report-hint'){
      $updated = [regex]::Replace(
        $updated,
        '(?is)<div\b([^>]*)>\s*Tip:\s*Press\s*<strong>Ctrl\s*\+\s*Alt\s*\+\s*R</strong>.*?</div>',
        '<div$1 style="display:none"></div>',
        'IgnoreCase'
      )
    }
  }
}

if($updated -ne $orig){
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Report buttons/tip are now hidden (page structure untouched)."
} else {
  Write-Host "ℹ️ No matching report UI found; nothing changed."
}
