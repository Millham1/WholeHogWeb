# PowerShell 7+
param(
  [string]$WebRoot   = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$LeftLogo  = "Legion whole hog logo.png",
  [string]$RightLogo = "AL Medallion.png"
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

# Add <meta charset="utf-8"> if missing
function Ensure-MetaUtf8([string]$Html){
  if([regex]::IsMatch($Html,'(?is)<meta\s+charset\s*=\s*["'']?utf-?8["'']?')){ return $Html }
  return [regex]::Replace($Html,'(?is)(<head[^>]*>)','$1'+"`r`n  <meta charset=""utf-8"">",1)
}

# Repair mojibake by round-tripping CP-1252 -> UTF-8 if we detect typical sequences.
function Repair-IfMojibake([string]$Text){
  if([string]::IsNullOrEmpty($Text)){ return $Text }
  # Heuristics: if it contains the lead chars that appear in mojibake, try repair once
  if($Text -match '[Ãâ]'){
    try{
      $cp1252  = [Text.Encoding]::GetEncoding(1252)
      $bytes   = $cp1252.GetBytes($Text)
      $fixed   = [Text.Encoding]::UTF8.GetString($bytes)
      # Only keep if it actually improved the telltale strings
      $scoreBefore = ([regex]::Matches($Text,'Ã|â')).Count
      $scoreAfter  = ([regex]::Matches($fixed,'Ã|â')).Count
      if($scoreAfter -lt $scoreBefore){ return $fixed }
    } catch {}
  }
  return $Text
}

# Replace or insert src="..." for an <img> with id="logoLeft"
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

# Replace or insert src="..." for an <img> with class containing right-img, or id="right-img"
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

# Resolve image names to a path relative to $WebRoot if they’re in subfolders; otherwise keep name
function Resolve-Img([string]$root,[string]$name){
  $p = Join-Path $root $name
  if(Test-Path -LiteralPath $p){ return $name }
  $f = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq (Split-Path $name -Leaf) } | Select-Object -First 1
  if($f){
    return [IO.Path]::GetRelativePath($root, $f.FullName)
  }
  return $name
}

if(-not (Test-Path -LiteralPath $WebRoot)){ throw "Web root not found: $WebRoot" }

$leftRel  = Resolve-Img $WebRoot $LeftLogo
$rightRel = Resolve-Img $WebRoot $RightLogo

$pages = @('landing.html','onsite.html','blind.html') | ForEach-Object {
  $p = Join-Path $WebRoot $_
  if(Test-Path -LiteralPath $p){ $p }
}

if(-not $pages){ throw "No landing.html / onsite.html / blind.html found to patch." }

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

Write-Host "`nDone. Hard-refresh (Ctrl+F5) to see images and cleaned text." -ForegroundColor Cyan
