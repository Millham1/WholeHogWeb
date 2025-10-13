param(
  [string]$Root = ".",
  [string]$File = "onsite.html"
)

function Read-FileUtf8NoBom([string]$path) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $path), $enc)
}
function Write-FileUtf8NoBom([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $enc)
}

# Paths + backup
$path = Join-Path $Root $File
if (!(Test-Path $path)) { throw "File not found: $path" }

$backupDir = Join-Path $Root "backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path $backupDir ("{0}_{1}" -f $File,$stamp)
Copy-Item $path $backupPath -ErrorAction SilentlyContinue

$html = Read-FileUtf8NoBom $path

# ---- Box-style scoring card (double-quoted here-string; closing "@ on its own line) ----
$card = @"
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
  .alert-ok{display:none;margin-top:10px;padding:8px 12px;border-radius:8px;background:#184;color:#efe;border:1px solid #0a3}
</style>

<section class="card" id="scoring-card" aria-labelledby="scoring-card-title">
  <h2 id="scoring-card-title">On-Site Scoring Card</h2>

  <div class="wh-row">
    <div class="wh-field">
      <label>Team</label>
      <input id="teamDisplay" type="text" readonly placeholder="(from Landing)">
    </div>
    <div class="wh-field">
      <label>Judge</label>
      <input id="judgeDisplay" type="text" readonly placeholder="(from Landing)">
    </div>
    <div class="wh-field" style="max-width:240px">
      <label for="suitable">Suitable for Consumption</label>
      <select id="suitable">
        <option value="">—</option>
        <option value="Yes">Yes</option>
        <option value="No">No</option>
      </select>
    </div>
  </div>

  <!-- Appearance & Color (2–40 by 2) -->
  <div class="wh-row">
    <div class="wh-field">
      <label>Appearance <span id="val-appearance" class="score-value"></span></label>
      <div class="score-box" data-id="appearance" data-start="2" data-end="40" data-step="2">
        <div class="score-grid"></div>
      </div>
    </div>
    <div class="wh-field">
      <label>Color <span id="val-color" class="score-value"></span></label>
      <div class="score-box" data-id="color" data-start="2" data-end="40" data-step="2">
        <div class="score-grid"></div>
      </div>
    </div>
  </div>

  <!-- Skin, Moisture, Taste (4–80 by 4) -->
  <div class="wh-row">
    <div class="wh-field">
      <label>Skin Crispness <span id="val-skin" class="score-value"></span></label>
      <div class="score-box" data-id="skin" data-start="4" data-end="80" data-step="4">
        <div class="score-grid"></div>
      </div>
    </div>
    <div class="wh-field">
      <label>Moisture <span id="val-moisture" class="score-value"></span></label>
      <div class="score-box" data-id="moisture" data-start="4" data-end="80" data-step="4">
        <div class="score-grid"></div>
      </div>
    </div>
  </div>

  <div class="wh-row">
    <div class="wh-field">
      <label>Meat &amp; Sauce Taste <span id="val-taste" class="score-value"></span></label>
      <div class="score-box" data-id="taste" data-start="4" data-end="80" data-step="4">
        <div class="score-grid"></div>
      </div>
    </div>
    <div class="wh-field"></div>
  </div>

  <!-- Completeness (Yes=8 / No=0) -->
  <fieldset class="card" style="margin-top:10px">
    <legend>Completeness (8 points each)</legend>
    <div class="wh-row">
      <div class="wh-field">
        <label for="siteClean">Site &amp; Cooker Cleanliness</label>
        <select id="siteClean">
          <option value="">—</option><option value="0">No</option><option
