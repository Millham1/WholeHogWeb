# PowerShell 7+
param(
  [string]$WebRoot   = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$LeftName  = "Legion whole hog logo.png",
  [string]$RightName = "AL Medallion.png"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path -LiteralPath $Path)){ throw "File not found: $Path" }
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Backup([string]$Path){
  $bak = "$Path.bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  Copy-Item -LiteralPath $Path -Destination $bak -Force
  Write-Host "Backup: $bak" -ForegroundColor Yellow
}

function Ensure-MetaUtf8([string]$Html){
  if([regex]::IsMatch($Html,'(?is)<meta\s+charset\s*=\s*["'']?utf-?8["'']?')){ return $Html }
  return [regex]::Replace($Html,'(?is)(<head[^>]*>)','$1'+"`r`n  <meta charset=""utf-8"">",1)
}
function Repair-IfMojibake([string]$Text){
  if([string]::IsNullOrEmpty($Text)){ return $Text }
  if($Text -match '[Ãâ]'){
    try{
      $cp1252 = [Text.Encoding]::GetEncoding(1252)
      $bytes  = $cp1252.GetBytes($Text)
      $fixed  = [Text.Encoding]::UTF8.GetString($bytes)
      $b = ([regex]::Matches($Text,'Ã|â')).Count
      $a = ([regex]::Matches($fixed,'Ã|â')).Count
      if($a -lt $b){ return $fixed }
    } catch {}
  }
  return $Text
}

function Is-Image([string]$Path){
  if(-not (Test-Path -LiteralPath $Path)){ return $false }
  $fi = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
  if(-not $fi -or $fi.Length -lt 16){ return $false }
  $fs = [IO.File]::OpenRead($Path)
  try{
    $buf = New-Object byte[] 12
    $null = $fs.Read($buf,0,$buf.Length)
    # PNG magic: 89 50 4E 47 0D 0A 1A 0A
    if($buf[0] -eq 0x89 -and $buf[1] -eq 0x50 -and $buf[2] -eq 0x4E -and $buf[3] -eq 0x47 -and
       $buf[4] -eq 0x0D -and $buf[5] -eq 0x0A -and $buf[6] -eq 0x1A -and $buf[7] -eq 0x0A){ return $true }
    # JPEG magic: FF D8 FF
    if($buf[0] -eq 0xFF -and $buf[1] -eq 0xD8 -and $buf[2] -eq 0xFF){ return $true }
    return $false
  } finally { $fs.Dispose() }
}

function Find-Image([string]$Name){
  $leaf = Split-Path $Name -Leaf
  $root = $env:USERPROFILE
  Get-ChildItem -LiteralPath $root -Recurse -File -Include *.png,*.jpg,*.jpeg -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq $leaf -or $_.Name -like ("*" + ($leaf -replace '\.png$','') + "*") } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Ensure-Image([string]$TargetName){
  $targetPath = Join-Path $WebRoot $TargetName
  if(Is-Image $targetPath){ return $TargetName } # good
  Write-Host "Missing or invalid image: $TargetName. Searching..." -ForegroundColor Yellow
  $found = Find-Image $TargetName
  if($found -and (Is-Image $found.FullName)){
    # Copy into webroot using the exact target name
    Copy-Item -LiteralPath $found.FullName -Destination $targetPath -Force
    Write-Host "Copied: $($found.FullName) -> $targetPath" -ForegroundColor Green
    return $TargetName
  }
  Write-Host "Did not find a usable file for $TargetName. Place it in $WebRoot and re-run." -ForegroundColor Red
  return $TargetName
}

function Fix-LeftImg([string]$Html,[string]$Src){
  $m = [regex]::Match($Html,'(?is)<img\b[^>]*\bid\s*=\s*["'']logoLeft["''][^>]*>')
  if($m.Success){
    $img = $m.Value
    $img2 = [regex]::Replace($img,'(?i)\bsrc\s*=\s*([''"])[^''"]*\1',{ param($mm) 'src="' + $Src + '"' },1)
    if($img2 -eq $img){ $img2 = $img -replace '(?is)^<img','<img src="' + $Src + '"' }
    return $Html.Substring(0,$m.Index) + $img2 + $Html.Substring($m.Index+$m.Length)
  }
  return $Html
}
function Fix-RightImg([string]$Html,[string]$Src){
  $m = [regex]::Match($Html,'(?is)<img\b[^>]*\b(class|id)\s*=\s*["''][^"'']*(right-img)[^"'']*["''][^>]*>')
  if($m.Success){
    $img = $m.Value
    $img2 = [regex]::Replace($img,'(?i)\bsrc\s*=\s*([''"])[^''"]*\1',{ param($mm) 'src="' + $Src + '"' },1)
    if($img2 -eq $img){ $img2 = $img -replace '(?is)^<img','<img src="' + $Src + '"' }
    return $Html.Substring(0,$m.Index) + $img2 + $Html.Substring($m.Index+$m.Length)
  }
  return $Html
}

if(-not (Test-Path -LiteralPath $WebRoot)){ throw "Web root not found: $WebRoot" }

# 1) Make sure the two images actually exist and are valid; if not, try to find and copy them in.
$leftRel  = Ensure-Image $LeftName
$rightRel = Ensure-Image $RightName

# 2) Patch pages to point to the working files and ensure UTF-8 + mojibake repair
$pages = @('landing.html','onsite.html','blind.html') | ForEach-Object {
  $p = Join-Path $WebRoot $_
  if(Test-Path -LiteralPath $p){ $p }
}

foreach($file in $pages){
  $html0 = Read-Text $file
  $html1 = Ensure-MetaUtf8 $html0
  $html1 = Repair-IfMojibake $html1
  $html1 = Fix-LeftImg  $html1 $leftRel
  $html1 = Fix-RightImg $html1 $rightRel

  if($html1 -ne $html0){
    Backup $file
    Write-Text $file $html1
    Write-Host ("Patched: {0}" -f (Split-Path $file -Leaf)) -ForegroundColor Green
  } else {
    Write-Host ("No changes needed: {0}" -f (Split-Path $file -Leaf)) -ForegroundColor DarkGray
  }
}

Write-Host "`nDone. Press Ctrl+F5 in the browser. If an image still does not show, confirm the PNG/JPG actually exists in $WebRoot and is not 0 bytes." -ForegroundColor Cyan
