param(
  [string]$Root = ".",
  [string]$LandingFile = "landing.html",
  [string]$BlindFile = "blind.html"
)

$ErrorActionPreference = "Stop"

# Resolve paths
$rootPath   = Resolve-Path $Root
$landingPath = Join-Path $rootPath $LandingFile
$blindPath   = Join-Path $rootPath $BlindFile

if (!(Test-Path $landingPath)) {
  Write-Error "Landing file not found: $landingPath"
  exit 1
}

# -----------------------------
# 1) Patch landing.html: add Setup panel that writes judgesList & chipsList to localStorage
# -----------------------------
$landing = Get-Content $landingPath -Raw

# Remove any prior injected block
$landing = [regex]::Replace($landing, '<!--\s*BEGIN\s*JudgesChipsSetup\s*-->.*?<!--\s*END\s*JudgesChipsSetup\s*-->', '', 'Singleline, IgnoreCase')

$setupBlock = @'
<!-- BEGIN JudgesChipsSetup -->
<style>
  .setup-card{max-width:1100px;margin:16px auto;padding:16px;border-radius:14px;background:#fff;box-shadow:0 6px 24px rgba(0,0,0,.06);font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}
  .setup-card h2{margin:0 0 8px 0}
  .setup-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}
  .setup-grid label{font-weight:700;display:block;margin-bottom:6px}
  .setup-grid textarea{width:100%;height:160px;padding:10px12px;border:1px solid #d1d5db;border-radius:10px;resize:vertical}
  .setup-actions{display:flex;flex-wrap:wrap;gap:10px;margin-top:12px}
  .setup-btn{border:0;border-radius:10px;padding:10px14px;cursor:pointer;font-weight:700}
  .primary{background:#0d6efd;color:#fff}
  .ghost{background:transparent;border:1px solid #d1d5db;color:#111}
  .ok{background:#198754;color:#fff}
  .muted{color:#6b7280;font-size:12px;margin-top:6px}
</style>
<section class="setup-card" id="judges-chips-setup" aria-labelledby="setup-title">
  <h2 id="setup-title">Setup: Judges & Chips</h2>
  <div class="muted">Enter one item per line. Click <b>Save Lists</b> to publish to this browser. Blind Taste will read these lists automatically.</div>
  <div class="setup-grid" style="margin-top:12px">
    <div>
      <label for="setup-judges">Judges (one per line)</label>
      <textarea id="setup-judges" placeholder="Judge A&#10;Judge B&#10;Judge C"></textarea>
    </div>
    <div>
      <label for="setup-chips">Chip #s (one per line)</label>
      <textarea id="setup-chips" placeholder="1&#10;2&#10;3&#10;4&#10;5"></textarea>
    </div>
  </div>
  <div class="setup-actions">
    <button type="button" class="setup-btn primary" id="setup-save">Save Lists</button>
    <button type="button" class="setup-btn ghost"   id="setup-load">Load Current</button>
    <button type="button" class="setup-btn ghost"   id="setup-clear">Clear Storage</button>
    <button type="button" class="setup-btn ok"      id="setup-open-blind">Open Blind Taste</button>
  </div>
  <div class="muted">Storage keys: <code>localStorage.judgesList</code>, <code>localStorage.chipsList</code>. (Per browser.)</div>
</section>
<script>
(function(){
  const KJ='judgesList', KC='chipsList';
  const $ = s=>document.querySelector(s);
  const txtJ = $('#setup-judges'), txtC = $('#setup-chips');

  function parseLines(t){
    return Array.from(new Set(
      String(t||'').split(/\r?\n/).map(s=>s.trim()).filter(Boolean)
    ));
  }
  function save(){
    const judges = parseLines(txtJ.value);
    let chips    = parseLines(txtC.value);
    // chips: keep numeric-looking only; sort numeric
    chips = chips.filter(x=>/^\d+$/.test(x)).sort((a,b)=>Number(a)-Number(b));
    try{
      localStorage.setItem(KJ, JSON.stringify(judges));
      localStorage.setItem(KC, JSON.stringify(chips));
      alert('Saved '+judges.length+' judges and '+chips.length+' chips to localStorage.');
    }catch(e){ alert('Unable to save to localStorage: '+e); }
  }
  function load(){
    try{
      const j = JSON.parse(localStorage.getItem(KJ)||'[]');
      const c = JSON.parse(localStorage.getItem(KC)||'[]');
      txtJ.value = j.join('\n');
      txtC.value = c.join('\n');
      alert('Loaded current lists from localStorage.');
    }catch(e){ alert('Unable to read localStorage: '+e); }
  }
  function clearAll(){
    try{
      localStorage.removeItem(KJ);
      localStorage.removeItem(KC);
      alert('Cleared judgesList and chipsList from localStorage.');
    }catch(e){ alert('Unable to clear localStorage: '+e); }
  }
  function openBlind(){
    const here = location.href;
    const blind = here.replace(/[^\/]+$/, '') + 'blind.html';
    window.open(blind, '_blank');
  }

  document.getElementById('setup-save').addEventListener('click', save);
  document.getElementById('setup-load').addEventListener('click', load);
  document.getElementById('setup-clear').addEventListener('click', clearAll);
  document.getElementById('setup-open-blind').addEventListener('click', openBlind);

  // Prefill from current storage if present
  try{
    if(localStorage.getItem(KJ) || localStorage.getItem(KC)){ 
      const j = JSON.parse(localStorage.getItem(KJ)||'[]');
      const c = JSON.parse(localStorage.getItem(KC)||'[]');
      if (j.length) txtJ.value = j.join('\n');
      if (c.length) txtC.value = c.join('\n');
    }
  }catch(e){}
})();
</script>
<!-- END JudgesChipsSetup -->
'@

if ($landing -match '</body\s*>') {
  $landing = [regex]::Replace($landing, '</body\s*>', "`r`n$setupBlock`r`n</body>", 'IgnoreCase')
} elseif ($landing -match '</html\s*>') {
  $landing = [regex]::Replace($landing, '</html\s*>', "`r`n$setupBlock`r`n</html>", 'IgnoreCase')
} else {
  $landing += "`r`n$setupBlock`r`n"
}

# Backup and write landing
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $landingPath (Join-Path $rootPath ("landing.backup-" + $stamp + ".html")) -Force
$landing | Set-Content -Path $landingPath -Encoding UTF8

# -----------------------------
# 2) Generate blind.html (reads judgesList & chipsList)
# -----------------------------
$blindHtml = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Blind Taste</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root { --brand:#0d6efd; --ok:#198754; --warn:#ffc107; --bg:#f7f7fb; --ink:#1e1e2a; --muted:#6b7280; --line:#d1d5db; }
    *{box-sizing:border-box}
    body{margin:0; font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif; color:var(--ink); background:var(--bg);}
    .container{max-width:1100px; margin:0 auto; padding:16px;}
    .site-header{background:#111; color:#fff; border-bottom:1px solid rgba(255,255,255,.08);}
    .site-header .bar{display:flex; align-items:center; gap:16px; padding:14px 16px;}
    .brand{display:flex; align-items:center; gap:10px; text-decoration:none; color:#fff;}
    .brand .logo{width:32px; height:32px; border-radius:8px; background:linear-gradient(135deg,#0d6efd,#6610f2);}
    .brand .title{font-size:18px; font-weight:800; letter-spacing:.3px;}
    .nav{margin-left:auto; display:flex; gap:16px;}
    .nav a{color:#cbd5e1; text-decoration:none; font-size:14px}
    .nav a:hover{color:#fff}
    .card{background:#fff; border-radius:14px; padding:16px; box-shadow:0 6px 24px rgba(0,0,0,.06); margin-top:16px;}
    .row{display:grid; grid-template-columns:220px 1fr; gap:16px; align-items:center; margin-bottom:12px;}
    label{font-weight:600;}
    input[type="text"], select{width:100%; padding:10px 12px; border:1px solid var(--line); border-radius:10px; font-size:14px; background:#fff;}
    .muted{color:var(--muted); font-size:12px;}
    .score-grid{display:grid; grid-template-columns:repeat(auto-fill,minmax(56px,1fr)); gap:8px; margin-top:8px;}
    .score-btn{border:1px solid var(--line); border-radius:10px; padding:10px 0; text-align:center; cursor:pointer; background:#fff; user-select:none; font-weight:700;}
    .score-btn.selected{background:var(--warn); border-color:#eab308;}
    .totals{display:flex; align-items:center; gap:10px; font-weight:800; font-size:18px; margin-top:8px;}
    .actions{display:flex; flex-wrap:wrap; gap:10px; margin-top:16px;}
    .btn{border:0; border-radius:10px; padding:10px 14px; cursor:pointer; font-weight:700;}
    .btn-primary{background:var(--brand); color:#fff;}
    .btn-ok{background:var(--ok); color:#fff;}
    .btn-ghost{background:transparent; border:1px solid var(--line); color:#111;}
    .inline{display:flex; gap:8px; align-items:center;}
    .grow{flex:1}
    .status{margin-top:8px; font-size:13px;}
    .status.ok{color:var(--ok)}
    .status.err{color:#b00020}
  </style>
</head>
<body>
  <header class="site-header">
    <div class="container bar">
      <a class="brand" href="landing.html">
        <div class="logo" aria-hidden="true"></div>
        <div class="title">Blind Taste</div>
      </a>
      <nav class="nav" aria-label="Main">
        <a href="landing.html">Home</a>
        <a href="leaderboard.html">Leaderboard</a>
        <a href="blind.html" aria-current="page">Blind Taste</a>
      </nav>
    </div>
  </header>

  <main class="container">
    <form id="blind-form" class="card" autocomplete="off">
      <h2 style="margin:0 0 12px 0;">Entry</h2>

      <div class="row">
        <label for="judge-select">Judge</label>
        <div>
          <select id="judge-select">
            <option value="" selected disabled>Select judge</option>
          </select>
          <div class="muted">Pulled from <code>localStorage.judgesList</code>. Set on the landing page.</div>
        </div>
      </div>

      <div class="row">
        <label for="chip-select">Chip #</label>
        <div>
          <div class="inline">
            <select id="chip-select">
              <option value="" selected disabled>Select chip #</option>
            </select>
            <input id="chip-add-input" class="grow" type="text" placeholder="Add chip # (e.g., 12)" />
            <button type="button" class="btn btn-ghost" id="chip-add-btn">Add</button>
          </div>
          <div class="muted">Pulled from <code>localStorage.chipsList</code>. You can add more here.</div>
        </div>
      </div>

      <div class="card" style="margin-top:8px;">
        <h3 style="margin:0 0 8px 0;">Appearance (2–40)</h3>
        <div id="scores-appearance" class="score-grid" data-category="appearance"></div>
      </div>

      <div class="card" style="margin-top:8px;">
        <h3 style="margin:0 0 8px 0;">Tenderness (2–40)</h3>
        <div id="scores-tenderness" class="score-grid" data-category="tenderness"></div>
      </div>

      <div class="card" style="margin-top:8px;">
        <h3 style="margin:0 0 8px 0;">Taste (4–80)</h3>
        <div id="scores-flavor" class="score-grid" data-category="flavor"></div>
      </div>

      <div class="totals">
        <span>Total:</span>
        <span id="score-total">0</span>
        <span class="muted">(Max 160)</span>
      </div>

      <div class="actions">
        <button type="submit" class="btn btn-primary" id="save-blind-taste">Save Blind Taste</butto


'@
