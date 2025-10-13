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

# Scopes for your nav containers
$navScope = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
$topScope = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'

# Find first existing button/anchor class in a nav, so we can reuse it
function Get-NavButtonClass([string]$innerHtml){
  $m = [regex]::Match($innerHtml, '(?is)<(?:a|button)\b[^>]*\bclass\s*=\s*["'']([^"'']+)["'']')
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return $null
}

# Replace any Sauce <a> with a <button>, otherwise insert a Sauce <button>
function Ensure-Sauce-Button-In-Inner([string]$innerHtml){
  $classToUse = Get-NavButtonClass $innerHtml
  $btnOpen = '<button type="button" onclick="location.href=''./sauce.html''"'
  if ($classToUse) { $btnOpen += ' class="' + $classToUse + '"' }
  $btnOpen += '>'
  $sauceButton = $btnOpen + 'Go to Sauce Tasting</button>'

  # Patterns
  $anchorPat = '(?is)\s*<a\b[^>]*\bhref\s*=\s*["'']\./sauce\.html["''][^>]*>.*?</a>\s*'
  $buttonPat = '(?is)\s*<button\b[^>]*\bonclick\s*=\s*["'']\s*location\.href\s*=\s*''\./sauce\.html''\s*["''][^>]*>.*?</button>\s*'

  # If a sauce BUTTON already exists, keep innerHtml as-is
  if ([regex]::IsMatch($innerHtml, $buttonPat)) { return $innerHtml }

  # If a sauce LINK exists, replace it with the button
  if ([regex]::IsMatch($innerHtml, $anchorPat)) {
    return [regex]::Replace($innerHtml, $anchorPat, "`r`n  $sauceButton`r`n")
  }

  # Otherwise, insert the button at the end of the nav’s inner content
  return ($innerHtml.TrimEnd() + "`r`n  $sauceButton`r`n")
}

function Patch-Nav([string]$html, [string]$scopePat){
  $m = [regex]::Match($html, $scopePat)
  if (-not $m.Success) { return @{ Html = $html; Changed = $false } }

  $open  = $m.Groups[1].Value
  $inner = $m.Groups[2].Value
  $close = $m.Groups[3].Value

  $newInner = Ensure-Sauce-Button-In-Inner $inner
  if ($newInner -ceq $inner) { return @{ Html = $html; Changed = $false } }

  $newBlock = $op
