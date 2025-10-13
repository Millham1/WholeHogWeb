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
$backupPath = Join-Path $backupDir ("{0}_{1}" -f $File, $stamp)
Copy-Item $path $backupPath -ErrorAction SilentlyContinue

$html = Read-FileUtf8NoBom $path

# ---- Scoring Card (drop-in) ----
$card = @'
<section class="card" id="scoring-card" aria-labelledby="scoring-card-title">
  <h2 id="scoring-card-title">On-Site Scoring Card</h2>

  <div class="row">
    <div class="field">
      <label>Team</label>
      <input id="teamDisplay" type="text" readonly placeholder="(from Landing)" />
    </div>
    <div class="field">
      <label>Judge</label>
      <input id="judgeDisplay" type="text" readonly placeholder="(from Landing)" />
    </div>
  </div>

  <div class="row">
    <div class="field">
      <label for="appearance">Appearance (2–40)</label>
      <select id="appearance"></select>
    </div>
    <div class="field">
      <label for="color">Color (2–40)</label>
      <select id="color"></select>
    </div>
  </div>

  <div class="row">
    <div class="field">
      <label for="skin">Skin Crispness (4–80)</label>
      <select id="skin"></select>
    </div>
    <div class="field">
      <label for="moisture">Moisture (4–80)</label>
      <select id="moisture"></select>
    </div>
  </div>

  <div class="row">
    <div class="field">
      <label for="taste">Meat &amp; Sauce Taste (4–80)</label>
      <select id="taste"></select>
    </div>
    <div class="field"></div>
  </div>

  <fieldset class="card" style="margin-top:10px">
    <legend>Completeness (8 pts each)</legend>
    <div class="row">
      <div class="field">
        <label for="siteClean">Site &amp; Cooker Cleanliness</label>
        <select id="siteClean">
          <option value="0">No</option>
          <option value="8">Yes</option>
        </select>
      </div>
      <div class="field">
        <label for="knives">Four Sharp Knives</label>
        <select id="knives">
          <option value="0">No</option>
          <option value="8">Yes</option>
        </select>
      </div>
    </div>
    <div class="row">
      <div class="field">
        <label for="sauceCups">Four Sauce Bowls/Cups</label>
        <select id="sauceCups">
          <option value="0">No</option>
          <option value="8">Yes</option>
        </select>
      </div>
      <div class="field">
        <label for="drinksTowels">Four Drinks &amp; Towels</label>
        <select id="drinksTowels">
          <option value="0">No</option>
          <option value="8">Yes</option>
        </select>
      </div>
    </div>
    <div class="row">
      <div class="field">
        <label for="thermometers">Two Functioning Meat Thermometers</label>
        <select id="thermometers">
          <option value="0">No</option>
          <option value="8">Yes</option>
        </select>
      </div>
      <div class="field"></div>
    </div>
  </fieldset>

  <div class="row" style="margin-top:10px">
    <div class="field">
      <label>Total</label>
      <input id="totalScore" type="text" readonly />
    </div>
    <div class="field">
      <label>Tie-Breaker Vector</label>
      <input id="tiebreak" type="text" readonly placeholder="Taste → Skin → Moisture" />
    </div>
  </div>

  <button id="submit-score" type="button">Submit Score</button>

  <p style="font-size:.85rem; color:#888; margin-top:8px">
    Tie-breaker order: Meat &amp; Sauce Taste, then Skin Crispness, then Moisture. (2025 Series rule)
  </p>
</section>

<script>
(function(){
  // Pull team/judge from Landing (expected to set these):
  var team = localStorage.getItem('selectedTeamName') || '';
  var judge = localStorage.getItem('selectedJudgeName') || '';
  var teamEl = document.getElementById('teamDisplay');
  var judgeEl = document.getElementById('judgeDisplay');
  if (teamEl) teamEl.value = team || '';
  if (judgeEl) judgeEl.value = judge || '';

  // Build dropdowns per 2025 sheet:
  function fillRange(selectId, start, end, step) {
    var sel = document.getElementById(selectId);
    if (!sel) return;
    sel.innerHTML = '';
    for (var v = start; v <= end; v += step) {
      var opt = document.createElement('option');
      opt.value = v; opt.textContent = v;
      sel.appendChild(opt);
    }
  }
  // Appearance & Color: 2..40 by 2
  fillRange('appearance', 2, 40, 2);
  fillRange('color', 2, 40, 2);
  // Skin/Moisture/Taste: 4..80 by 4
  fillRange('skin', 4, 80, 4);
  fillRange('moisture', 4, 80, 4);
  fillRange('taste', 4, 80, 4);

  // Defaults roughly mid-range
  ['appearance','color','skin','moisture','taste'].forEach(function(id){
    var sel = document.getElementById(id);
    if (sel && sel.options.length) sel.selectedIndex = Math.floor(sel.options.length/2);
  });

  function calcTotal(){
    function val(id){ var el=document.getElementById(id); return el ? (+el.value||0) : 0; }
    var core = val('appearance') + val('color') + val('skin') + val('moisture') + val('taste');
    var comp = val('siteClean') + val('knives') + val('sauceCups') + val('drinksTowels') + val('thermometers');
    var total = core + comp;
    var tb = [val('taste'), val('skin'), val('moisture')].join(' ▸ ');
    var out = document.getElementById('totalScore'); if (out) out.value = total;
    var tbEl = document.getElementById('tiebreak'); if (tbEl) tbEl.value = tb;
  }

  document.querySelectorAll('#scoring-card select').forEach(function(el){
    el.addEventListener('change', calcTotal);
  });
  calcTotal();

  // Submit placeholder (wire to your backend/API as needed)
  var btn = document.getElementById('submit-score');
  if (btn){
    btn.addEventListener('click', function(){
      var payload = {
        team: teamEl ? teamEl.value : '',
        judge: judgeEl ? judgeEl.value : '',
        appearance: +document.getElementById('appearance').value,
        color: +document.getElementById('color').value,
        skin: +document.getElementById('skin').value,
        moisture: +document.getElementById('moisture').value,
        taste: +document.getElementById('taste').value,
        siteClean: +document.getElementById('siteClean').value,
        knives: +document.getElementById('knives').value,
        sauceCups: +document.getElementById('sauceCups').value,
        drinksTowels: +document.getElementById('drinksTowels').value,
        thermometers: +document.getElementById('thermometers').value,
        total: +document.getElementById('totalScore').value,
        tiebreak: document.getElementById('tiebreak').value
      };
      console.log('Submit payload:', payload);
      alert('Score ready to submit for ' + payload.team + ' (Total: ' + payload.total + ')');
      // TODO: replace with real POST to your endpoint
    });
  }
})();
</script>
'@

# --- Remove any existing scoring card ---
$patCard = '(?is)<section[^>]*id="scoring-card"[^>]*>.*?</section>'
$html = [regex]::Replace($html, $patCard, "")

# --- Ensure a single nav exists (do not touch if already correct) ---
$patNav = '(?is)<nav[^>]*id="top-go-buttons"[^>]*>.*?</nav>'
$hasNav = [regex]::IsMatch($html, $patNav)

# --- Insert new card right after the nav if present, else after </header>, else prepend ---
if ($hasNav) {
  $navMatch = [regex]::Match($html, $patNav)
  $insertAt = $navMatch.Index + $navMatch.Length
  $html = $html.Substring(0,$insertAt) + "`r`n" + $card + $html.Substring($insertAt)
} elseif ([regex]::IsMatch($html, '(?is)</header>')) {
  $m = [regex]::Match($html, '(?is)</header>')
  $insertAt = $m.Index + $m.Length
  $html = $html.Substring(0,$insertAt) + "`r`n" + $card + $html.Substring($insertAt)
} else {
  $html = $card + "`r`n" + $html
}

Write-FileUtf8NoBom $path $html
Write-Host "✅ Scoring card rebuilt and installed into $File. Backup: $backupPath"
