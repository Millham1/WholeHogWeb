param([string]$Root = ".")

$Root      = Resolve-Path $Root
$indexPath = Join-Path $Root "index.html"

$snippet = @'
<label>Chip #:
  <select id="chip-select" name="chip-select"></select>
</label>
'@

if (-not (Test-Path $indexPath)) {
  @"
<!doctype html>
<html><head><meta charset='utf-8'><title>BBQ</title></head>
<body>
  <form id="add-team-form">
    $snippet
  </form>
</body></html>
"@ | Set-Content -Path $indexPath -Encoding UTF8
  Write-Host "[created] index.html with chip-select"
  exit
}

$html = Get-Content $indexPath -Raw

# If chip-select already present, do nothing
if ($html -match 'id\s*=\s*["'']chip-select["'']') {
  Write-Host "[skip] chip-select already present in index.html"
  exit
}

# Try to inject inside an existing form with id="add-team-form"
$formRegex = '<form[^>]*id=["'']add-team-form["''][\s\S]*?</form>'
if ($html -match $formRegex) {
  $updated = [regex]::Replace($html, '</form>', ("`n    $snippet`n</form>"), 'IgnoreCase', [TimeSpan]::FromSeconds(1))
  $updated | Set-Content -Path $indexPath -Encoding UTF8
  Write-Host "[updated] inserted chip-select inside #add-team-form"
  exit
}

# Otherwise inject before </body>
if ($html -match '</body>') {
  $updated = [regex]::Replace($html, '</body>', ("`n  $snippet`n</body>"), 'IgnoreCase', [TimeSpan]::FromSeconds(1))
  $updated | Set-Content -Path $indexPath -Encoding UTF8
  Write-Host "[updated] inserted chip-select before </body>"
} else {
  # Fallback: append
  ($html + "`n$snippet`n") | Set-Content -Path $indexPath -Encoding UTF8
  Write-Host "[updated] appended chip-select to end of index.html"
}
