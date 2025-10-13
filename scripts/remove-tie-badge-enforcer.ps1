param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -Path $Path)) {
  Write-Error "File not found: $Path"
  exit 1
}

# Read file
$orig = Get-Content -Path $Path -Raw

# Backup first
$bak = "$Path.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -Path $Path -Destination $bak -Force

# Regex to remove exactly the enforcer block (case-insensitive, singleline)
$pat = @'
(?is)<script[^>]*id=["']enforce-top2-tiebreak-badge["'][\s\S]*?</script>
'@

$clean = [regex]::Replace($orig, $pat, '')

# Only write if changed
if ($clean -ne $orig) {
  Set-Content -Path $Path -Value $clean -Encoding UTF8
  Write-Host "✅ Removed tie-badge enforcer from $Path" -ForegroundColor Green
  Write-Host "Backup saved to $bak"
} else {
  Write-Host "ℹ️ No enforcer block found in $Path. No changes written." -ForegroundColor Yellow
  Write-Host "Backup still saved to $bak"
}
