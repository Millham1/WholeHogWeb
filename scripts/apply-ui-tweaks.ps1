# PowerShell 7 script: apply-ui-tweaks.ps1
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

# Helpers
function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  return [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}
function Backup-Once([string[]]$Files){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $WebRoot ("BACKUP_ui_" + $stamp)
  $did = $false
  foreach($f in $Files){
    $p = Join-Path $WebRoot $f
    if(Test-Path $p){
      if(-not $did){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $did = $true }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($did){ Write-Host "Backup saved to $bak" -ForegroundColor Yellow }
}

# Paths
$LandingHtml = Join-Path $WebRoot 'landing.html'
$OnsiteHtml  = Join-Path $WebRoot 'onsite.html'
$CssPath     = Join-Path $WebRoot 'styles.css'

$missing = @()
foreach($f in @($LandingHtml,$OnsiteHtml,$CssPath)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`n" + ($missing -join "`n")) }

Backup-Once @('landing.html','onsite.html','styles.css')

# 1) Append CSS for header height + logo vertical centering + button styles
$css = Read-Text $CssPath
$marker = '/* === WHOLEHOG header & button tweaks === */'
if($css -notmatch [regex]::Escape($marker)){
  $block = @"
$marker
header{
  height: 2.25in;
  display:flex;
  align-items:center;   /* vertical center */
  justify-content:center; /* center title horizontally */
  position:relative;
  box-sizing:border-box;
}
header img#logoLeft,
header .left-img,
header .brand-left img{
  position:absolute; left:18px; top:50%;
  transform:translateY(-50%);
  max-height:calc(100% - 24px);
  width:auto; display:block;
}
header img#logoRight,
header .right-img,
header .brand-right img{
  position:absolute; right:18px; top:50%;
  transform:translateY(-50%);
  max-height:calc(100% - 24px);
  width:auto; display:block;
}
header .title, header h1{ margin:0; text-align:center; }

/* Buttons: red bg with black text */
.wh-btn{
  background:#b10020; color:#000;
  border:2px solid #000;
  padding:10px 16px; border-radius:8px;
  font-weight:600; cursor:pointer;
}

/* Center the Go button under header */
#goOnsiteBtn{ display:block; margin:20px auto; }
"@
  $css += "`r`n" + $block + "`r`n"
  Write-Text $CssPath $css
  Write-Host "Appended CSS tweaks to styles.css" -ForegroundColor Cyan
} else {
  Write-Host "CSS tweaks already present; leaving styles.css as-is." -ForegroundColor DarkGray
}

# 2) Ensure landing button exists below header and is styled
$landing = Read-Text $LandingHtml

# Remove any existing goOnsiteBtn (so we can reinsert it just after </header>)
$landing = [regex]::Replace($landing, '(?is)<button\b[^>]*id\s*=\s*"(?:goOnsiteBtn)"[^>]*>.*?</button>', '')

# Find first </header> to inject after it
$idx = $landing.IndexOf("</header>", [StringComparison]::OrdinalIgnoreCase)
$inject = @"
<button id="goOnsiteBtn" class="wh-btn" onclick="location.href='onsite.html'">
  Go to On-Site Scoring
</button>
"@

if($idx -ge 0){
  $before = $landing.Substring(0, $idx + 9)
  $after  = $landing.Substring($idx + 9)
  $landing = $before + "`r`n" + $inject + "`r`n" + $after
  Write-Host "Inserted 'Go to On-Site Scoring' button under header in landing.html" -ForegroundColor Cyan
} else {
  # Fallback: put it near top of <body>
  $landing = [regex]::Replace($landing, '(?is)(<body\b[^>]*>)', "`$1`r`n$inject`r`n", 1)
  Write-Host "No </header> found; placed button at top of body in landing.html" -ForegroundColor Yellow
}

# Add .wh-btn to Add Team / Add Judge buttons if present
$addIds = @("addTeamBtn","addJudgeBtn")
foreach($id in $addIds){
  $landing = [regex]::Replace(
    $landing,
    "(?is)<button([^>]*\bid\s*=\s*""$id""[^>]*)>",
    {
      param($m)
      $inside = $m.Groups[1].Value
      if($inside -match '(?i)\bclass\s*=\s*"([^"]*)"'){
        $classes = $Matches[1]
        if($classes -notmatch '(^|\s)wh-btn(\s|$)'){
          $newClasses = ($classes + " wh-btn").Trim()
          return "<button" + ($inside -replace '(?i)\bclass\s*=\s*"[^"]*"', 'class="' + $newClasses + '"') + ">"
        } else {
          return "<button$inside>"
        }
      } else {
        return "<button$inside class=""wh-btn"">"
      }
    },
    1
  )
}

Write-Text $LandingHtml $landing
Write-Host "Updated landing.html button placement/styling" -ForegroundColor Cyan

Write-Host "`nDone. Hard refresh the browser (Ctrl+F5) on both pages." -ForegroundColor Green
