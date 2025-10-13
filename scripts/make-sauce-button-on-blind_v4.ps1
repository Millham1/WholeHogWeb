param(
  [Parameter(Mandatory=$true)] [string]$BlindPath
)

function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8NoBom([string]$p,[string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p,$s,$enc)
}
function Backup([string]$p){
  if (!(Test-Path $p)) { throw "File not found: $p" }
  $bak = "$p.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
  Copy-Item $p $bak -Force | Out-Null
  Write-Host "🔒 Backup: $bak"
  return $bak
}

# Regex scopes for the nav containers we’ve seen
$navScope = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
$topScope = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'

# Build a Sauce button that reuses the first existing nav button/anchor classes
function Build-SauceButton([string]$innerHtml){
  $class = $null
  $mClass = [regex]::Match($innerHtml, '(?is)<(?:a|button)\b[^>]*\bclass\s*=\s*["'']([^"'']+)["'']')
  if ($mClass.Success) { $class = $mClass.Groups[1].Value.Trim() }

  $classPart = ''
  if ($class -and $class.Length -gt 0) { $classPart = ' class="' + $class + '"' }

  # Proper BUTTON (not <a>), navigates like the others
  $btn = "<button type=""button"" onclick=""location.href='./sauce.html'""" + $classPart + ">Go to Sauce Tasting</button>"
  return $btn
}

# Insert or replace inside a matched nav block
function Ensure-SauceButton-In-Block {
  param(
    [string]$Html,
    [System.Text.RegularExpressions.Match]$Match
  )

  $open  = $Match.Groups[1].Value
  $inner = $Match.Groups[2].Value
  $close = $Match.Groups[3].Value

  # If a Sauce BUTTON already exists, leave unchanged
  $patSauceBtn = '(?is)<button\b[^>]*\bonclick\s*=\s*["''][^"'']*\.\/sauce\.html[^"'']*["''][^>]*>.*?</button>'
  if ([regex]::IsMatch($inner, $patSauceBtn)) {
    return @{ Html = $Html; Changed = $false }
  }

  $sauceButton = Build-SauceButton $inner

  # If a Sauce LINK exists, replace it with the button
  $patSauceLink = '(?is)<a\b[^>]*\bhref\s*=\s*["'']\./sauce\.html["''][^>]*>.*?</a>'
  if ([regex]::IsMatch($inner, $patSauceLink)) {
    $newInner = [regex]::Replace($inner, $patSauceLink, $sauceButton, 1)
  } else {
    # Otherwise append the button to the end of the nav content
    $newInner = $inner.TrimEnd() + "`r`n  " + $sauceButton + "`r`n"
  }

  # Rebuild the file content
  $newBlock = $open + $newInner + $close
  $prefix = $Html.Substring(0, $Match.Index)
  $suffix = $Html.Substring($Match.Index + $Match.Length)
  return @{ Html = ($prefix + $newBlock + $suffix); Changed = $true }
}

# ---- main ----
if (!(Test-Path $BlindPath)) { throw "File not found: $BlindPath" }

$html = Read-Utf8NoBom $BlindPath

# Try <nav id="wholehog-nav">
$m = [regex]::Match($html, $navScope)
if ($m.Success) {
  $res = Ensure-SauceButton-In-Block -Html $html -Match $m
  if ($res.Changed) {
    Backup $BlindPath | Out-Null
    Write-Utf8NoBom $BlindPath $res.Html
    Write-Host "✅ Added a proper Sauce nav BUTTON to $BlindPath (inside #wholehog-nav)."
    exit 0
  } else {
    Write-Host "ℹ️ Sauce button already present in #wholehog-nav. No change."
    exit 0
  }
}

# Fallback: <div id="top-go-buttons">
$m2 = [regex]::Match($html, $topScope)
if ($m2.Success) {
  $res2 = Ensure-SauceButton-In-Block -Html $html -Match $m2
  if ($res2.Changed) {
    Backup $BlindPath | Out-Null
    Write-Utf8NoBom $BlindPath $res2.Html
    Write-Host "✅ Added a proper Sauce nav BUTTON to $BlindPath (inside #top-go-buttons)."
    exit 0
  } else {
    Write-Host "ℹ️ Sauce button already present in #top-go-buttons. No change."
    exit 0
  }
}

Write-Host "⚠️ Couldn’t find a known nav container (id=""wholehog-nav"" or id=""top-go-buttons""). No changes made."
