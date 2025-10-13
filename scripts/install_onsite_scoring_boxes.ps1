param(
  [string]$Root = ".",
  [string]$File = "onsite.html"
)

function Read-FileUtf8NoBom([string]$path) {
  return [System.IO.File]::ReadAllText((Resolve-Path $path), (New-Object System.Text.UTF8Encoding($false)))
}
function Write-FileUtf8NoBom([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $enc)
}

$path = Join-Path $Root $File
if (!(Test-Path $path)) { throw "File not found: $path" }

# Backup
$backupDir = Join-Path $Root "backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path $backupDir ("{0}_{1}" -f $File,$stamp)
Copy-Item $path $backupPath -ErrorAction SilentlyContinue

$html = Read-FileUtf8NoBom $path

# ----------- New Scoring Card (box-style) -----------
$card = @'
<!-- ON-SITE SCORING CARD BEGIN -->
<style id="onsite-boxes-style">
  .wh-row{display:flex;gap:12px;flex-wrap:wrap}
  .wh-field{flex:1;min-width:220px}
  .wh-field label{display:block;font-weight:600;margin:6px 0 6px}
  .score-box{border:1px solid #333;border-radius:12px;padding:10px}
  .score-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(46px,1fr));gap:8px}
  .score-btn{padding:8px 0;border:1px solid #444;border-radius:8px;text-align:center;cursor:pointer;user-select:none}
  .score-btn:hover{filter:brightness(1.1)}
  .score-btn.selected{outline:2px solid #2fb67e;border-color:#2fb67e}
  .score-value{font-weight:700;margin-left:6px}
  .alert-ok{display:none;margin-top:10px;padding:8px 12px;border-radius:8px;background:#184; color:#efe; border:1px solid #0a3}
</style>

<section class="card" id="scoring-card" aria-labelledby="scoring-card-title">
  <h2 id="scoring-card-title">On-Site Scoring Card</h2>

  <div class="wh-row">
    <div class="wh-field">
      <label>Team</label>
      <in
