# PowerShell 5.1 - restore from latest BACKUP_* folder in your web root
param(
  [string]$WebRoot    = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  # Optional: if you want a specific backup folder, pass its name here (e.g., BACKUP_pages_20250929_170501)
  [string]$BackupName = ""
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Require-Path([string]$Path){
  if(-not (Test-Path $Path)){ throw "Path not found: $Path" }
}

function Copy-IfExists([string]$Src, [string]$DstDir){
  if(Test-Path $Src){
    $leaf = Split-Path $Src -Leaf
    Copy-Item $Src (Join-Path $DstDir $leaf) -Force
    return $true
  }
  return $false
}

Require-Path $WebRoot

# Find backup folders
$backups = Get-ChildItem -Path $WebRoot -Directory | Where-Object { $_.Name -like "BACKUP_*" } | Sort-Object LastWriteTime -Descending
if(-not $backups -or $backups.Count -eq 0){
  Write-Host "No BACKUP_* folders found in $WebRoot." -ForegroundColor Red
  Write-Host "If you use OneDrive, you can also use OneDrive 'Version history' to restore previous versions of the files."
  exit 1
}

# Choose source
if([string]::IsNullOrWhiteSpace($BackupName)){
  $source = $backups[0]
  Write-Host ("Using most recent backup: {0}" -f $source.FullName) -ForegroundColor Yellow
} else {
  $source = Join-Path $WebRoot $BackupName
  if(-not (Test-Path $source)){ throw "Specified backup not found: $source" }
  $source = Get-Item $source
  Write-Host ("Using specified backup: {0}" -f $source.FullName) -ForegroundColor Yellow
}

# Snapshot current files before rollback
$stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$snapshotDir = Join-Path $WebRoot ("SNAPSHOT_BEFORE_ROLLBACK_" + $stamp)
New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null

# These are the common files we’ve been touching; we’ll snapshot whichever exist now
$currentFiles = @(
  "landing.html","onsite.html","styles.css",
  "app.js","landing-sb.js","onsite-sb.js","supabase-config.js"
)
foreach($f in $currentFiles){
  $p = Join-Path $WebRoot $f
  if(Test-Path $p){ Copy-Item $p (Join-Path $snapshotDir $f) -Force }
}
Write-Host ("Snapshot of current files saved to: {0}" -f $snapshotDir) -ForegroundColor Cyan

# Restore anything that was in the backup folder (we only copied files we changed when making backups)
$restored = @()
$filesInBackup = Get-ChildItem -Path $source.FullName -File
foreach($bf in $filesInBackup){
  $dst = Join-Path $WebRoot $bf.Name
  Copy-Item $bf.FullName $dst -Force
  $restored += $bf.Name
}

if($restored.Count -gt 0){
  Write-Host "Restored these files from backup:" -ForegroundColor Green
  $restored | ForEach-Object { Write-Host (" - {0}" -f $_) }
} else {
  Write-Host "Backup folder had no files to restore. Nothing changed." -ForegroundColor DarkYellow
}

Write-Host "`nRollback complete. Press Ctrl+F5 in your browser to bypass cache." -ForegroundColor Green
