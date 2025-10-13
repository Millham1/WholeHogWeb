<#  organize-project.ps1

Purpose:
  - Make ./scripts and ./backups
  - Move non-app files into those folders safely.

Usage:
  pwsh .\organize-project.ps1
  pwsh .\organize-project.ps1 -Root .\WholeHogWeb
  pwsh .\organize-project.ps1 -Root . -DryRun
#>

param(
  [string]$Root = ".",
  [switch]$DryRun
)

function New-DirIfMissing([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function SafeMove {
  param(
    [Parameter(Mandatory)] [System.IO.FileInfo] $File,
    [Parameter(Mandatory)] [string] $DestDir,
    [switch] $DryRun
  )
  New-DirIfMissing -Path $DestDir

  $target = Join-Path $DestDir $File.Name
  if (Test-Path -LiteralPath $target) {
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    $ext = $File.Extension
    $target = Join-Path $DestDir ("{0}.{1}{2}" -f $nameNoExt,$ts,$ext)
  }

  if ($DryRun) {
    Write-Host "[DRY] Move" -NoNewline
    Write-Host "  $($File.FullName)" -ForegroundColor Yellow -NoNewline
    Write-Host "  ->  $target" -ForegroundColor Cyan
  } else {
    Move-Item -LiteralPath $File.FullName -Destination $target -Force
    Write-Host "Moved " -NoNewline
    Write-Host "$($File.Name)" -ForegroundColor Green -NoNewline
    Write-Host " -> $((Split-Path $target -Leaf))" -ForegroundColor DarkGray
  }
}

# --- Start ---
$Root = (Resolve-Path -LiteralPath $Root).Path
Write-Host "Organizing project at: $Root" -ForegroundColor Cyan

$scriptsDir = Join-Path $Root "scripts"
$backupsDir = Join-Path $Root "backups"
New-DirIfMissing $scriptsDir
New-DirIfMissing $backupsDir

# Don’t walk into these directories
$excludeDirs = @(
  [IO.Path]::GetFullPath($scriptsDir),
  [IO.Path]::GetFullPath($backupsDir)
)

# Collect top-level files only (don’t recurse by default to avoid moving app assets)
$files = Get-ChildItem -LiteralPath $Root -File

# Define patterns to classify files
$scriptPatterns = @('*.ps1')  # all helper/utility scripts
$backupPatterns = @(
  '*.bak','*.bak_*','*.backup','*.old','*.orig','*.tmp','*.temp','*~','*.swp','*.swo','*.log'
)

# Also treat any file whose name contains "backup" (any extension) as a backup
function IsBackupByName([string]$name) {
  return ($name -match '(?i)backup')
}

# Decide destination for a file, or $null to keep it in place
function Classify([IO.FileInfo]$f) {
  $full = [IO.Path]::GetFullPath($f.FullName)
  foreach ($ex in $excludeDirs) {
    if ($full.StartsWith($ex, [StringComparison]::OrdinalIgnoreCase)) { return $null }
  }

  # scripts: *.ps1
  foreach ($pat in $scriptPatterns) {
    if ($f.Name -like $pat) { return @{ kind='script'; dest=$scriptsDir } }
  }

  # backups by pattern
  foreach ($pat in $backupPatterns) {
    if ($f.Name -like $pat) { return @{ kind='backup'; dest=$backupsDir } }
  }

  # backups by name containing "backup"
  if (IsBackupByName $f.Name) { return @{ kind='backup'; dest=$backupsDir } }

  # keep common app files in place (html/css/js/json/png/jpg/svg/ico/ttf/woff/woff2)
  if ($f.Extension -match '^(?i)\.(html?|css|js|json|png|jpe?g|svg|ico|ttf|woff2?)$') { return $null }

  # keep csv or pdf if they’re part of the app
  if ($f.Extension -match '^(?i)\.(csv|pdf)$') { return $null }

  # default: leave in place
  return $null
}

# Move files
$scriptCount = 0
$backupCount = 0

foreach ($f in $files) {
  $cls = Classify $f
  if ($null -ne $cls) {
    SafeMove -File $f -DestDir $cls.dest -DryRun:$DryRun
    if ($cls.kind -eq 'script') { $scriptCount++ }
    elseif ($cls.kind -eq 'backup') { $backupCount++ }
  }
}

Write-Host ""
if ($DryRun) {
  Write-Host "DRY RUN SUMMARY — no files moved." -ForegroundColor Yellow
} else {
  Write-Host "Done." -ForegroundColor Green
}
Write-Host "Scripts moved: $scriptCount"
Write-Host "Backups moved: $backupCount"
Write-Host "Targets: $scriptsDir , $backupsDir"
