param(
  [string]$Root = ".",
  [string]$Target = "blind.html"
)

$ErrorActionPreference = "Stop"

$rootPath  = Resolve-Path $Root
$target    = Join-Path $rootPath $Target

# Find likely backup files (from any earlier scripts or manual copies)
$patterns = @("blind.backup-*.html", "*.backup-*.html", "*backup*.html")
$backups = foreach ($p in $patterns) {
  Get-ChildItem -Path $rootPath -Recurse -Filter $p -ErrorAction SilentlyContinue
}
$backups = $backups | Where-Object { $_.PSIsContainer -eq $false } | Sort-Object LastWriteTime -Descending

if (-not $backups -or $backups.Count -eq 0) {
  Write-Error "No backup files found under $rootPath. Looked for: $($patterns -join ', ')"
  exit 1
}

# Pick the most recent valid-looking HTML backup (size > 0 and contains <html)
$chosen = $null
foreach ($b in $backups) {
  try {
    if ($b.Length -gt 0) {
      $content = Get-Content $b.FullName -Raw -ErrorAction Stop
      if ($content -match '<html' -or $content -match '<!DOCTYPE') {
        $chosen = $b
        break
      }
    }
  } catch { }
}

if (-not $chosen) {
  $chosen = $backups[0]
}

Write-Host "Restoring from: $($chosen.FullName)"
Copy-Item -Path $chosen.FullName -Destination $target -Force

# Sanity-check restored file
if (-not (Test-Path $target)) { Write-Error "Restore failed: $target not found after copy."; exit 1 }
$restored = Get-Content $target -Raw
if ($restored.Trim().Length -eq 0) { Write-Error "Restore failed: $target is empty."; exit 1 }

Write-Host "✅ Restored $Target from backup: $($chosen.Name)"
Write-Host "Now hard refresh the page (Ctrl+F5)."
