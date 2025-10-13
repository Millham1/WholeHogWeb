param(
  [string]$Root = ".",
  [string]$LandingFile = "landing.html",
  [string]$BlindFile   = "blind.html"
)

$ErrorActionPreference = "Stop"

$rootPath    = Resolve-Path $Root
$landingPath = Join-Path $rootPath $LandingFile
$blindPath   = Join-Path $rootPath $BlindFile

if (!(Test-Path $landingPath)) {
  Write-Error "Landing file not found: $landingPath"
  exit 1
}

# --- Read landing and extract <header>...</header> ---
$landing = Get-Content $landingPath -Raw
$headerMatch = [regex]::Match($landing, '(?is)<header\b[^>]*>.*?</header>')
if (-not $headerMatch.Success) {
  Write-Host "⚠️ No <header> found in landing.html. Using a minimal fallback header."
  $headerHtml = @"
<header class=""site-header"">
  <div class=""container bar"">
    <a class=""brand"" href=""landing.html"">
      <div class=""logo"" aria-hidden=""true""></div>
      <div class=""title"">Blind Taste</div>
    </a>
    <nav class=""nav"" aria-label=""Main"">
      <a href=""landing.html"">Home</a>
      <a href=""leaderboard.html"">Leaderboard</a>
      <a href=""blind.html"" aria-current=""page"">Blind Taste</a>
    </nav>
  </div>
</header>
"@
} else {
  $headerHtml = $headerMatch.Value
  # Replace common visible title nodes with "Blind Taste" (first hit only)
  $headerHtml = [regex]::Replace($headerHtml, '(?is)(<h1\b[^>]*>)(.*?)(</h1>)', '${1}Blind Taste${3}', 1)
  $headerHtml = [regex]::Replace($headerHtml, '(?is)(<div\b[^>]*class=["''][^"'']*title[^"'']*["''][^>]*>)(.*?)(</div>)', '${1}Blind Taste${3}', 1)
}

# --- Minimal, safe CSS (so header looks sane even if landing CSS is separate) ---
$baseCss = @'
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
'@

# --- Blind page HTML that READS localStorage lists (no seeding here) ---
$blindHtml = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Blind Taste</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
__BASE_CSS__
  </style>
</head>
<body>

__HEADER_HTML__

  <main class="container">
    <form id="blind-form" class="card" autocomplete="off">
      <h2 style="margin:0 0 12px 0;">Entry</h2>

      <div class="row">
        <label for="judge-select">Judge</label>
        <div>
          <select id="judge-select">
            <option value="" selected disabled>Select judge</option>
          </select>
          <div class="muted">Pulled from <code>localStorage.judgesList</code> (set on landing page Setup panel).</div>
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
        <button type="submit" class="btn btn-primary" id="save-blind-taste">Save Blind Taste</button>
        <button type="button" class="btn btn-ok" id="export-csv">Export CSV</button>
        <button type="button" class="btn btn-ghost" id="clear-form">Clear Form</button>
      </div>

      <div id="status" class="status" aria-live="polite"></div>
    </form>
  </main>

  <script>
  (function(){
    // Keys
    const LS_ENTRIES='blindTasteEntries', LS_JUDGES='judgesList', LS_CHIPS='chipsList';
    // Elements
    const form=document.getElementById('blind-form');
    const judgeSelect=document.getElementById('judge-select');
    const chipSelect=document.getElementById('chip-select');
    const chipAddIn=document.getElementById('chip-add-input');
    const chipAddBtn=document.getElementById('chip-add-btn');
    const totalEl=document.getElementById('score-total');
    const statusEl=document.getElementById('status');
    const exportBtn=document.getElementById('export-csv');
    const clearBtn=document.getElementById('clear-form');

    const readJSON=(k,d)=>{try{const v=localStorage.getItem(k);return v?JSON.parse(v):d;}catch{return d;}};
    const writeJSON=(k,v)=>localStorage.setItem(k,JSON.stringify(v));
    const setStatus=(m,ok=false)=>{statusEl.textContent=m||'';statusEl.className='status '+(ok?'ok':(m?'err':''));if(m)setTimeout(()=>setStatus(''),3000);};

    // Build scoring ranges (Appearance/Tenderness 2–40 step 2; Taste 4–80 step 4)
    const APPEAR=Array.from({length:20},(_,i)=>2*(i+1));
    const TENDER=Array.from({length:20},(_,i)=>2*(i+1));
    const FLAVOR=Array.from({length:20},(_,i)=>4*(i+1));

    function buildCat(id,vals){
      const host=document.getElementById(id); host.innerHTML='';
      vals.forEach(v=>{
        const b=document.createElement('button');
        b.type='button'; b.className='score-btn'; b.textContent=v; b.dataset.value=String(v);
        b.addEventListener('click',()=>{host.querySelectorAll('.score-btn').forEach(x=>x.classList.remove('selected'));b.classList.add('selected');updateTotal();});
        host.appendChild(b);
      });
    }
    const pickVal=id=>{const sel=document.getElementById(id).querySelector('.score-btn.selected');return sel?Number(sel.dataset.value):0;};
    const clearScores=()=>{document.querySelectorAll('.score-grid .score-btn.selected').forEach(x=>x.classList.remove('selected'));updateTotal();};
    const updateTotal=()=>{totalEl.textContent=String(pickVal('scores-appearance')+pickVal('scores-tenderness')+pickVal('scores-flavor'));};

    function uniqueClean(arr){return Array.from(new Set(arr.map(s=>String(s).trim()).filter(Boolean)));}

    function renderJudges(){
      const judges=uniqueClean(readJSON(LS_JUDGES,[]));
      judgeSelect.innerHTML='<option value="" disabled>Select judge</option>'+judges.map(j=>`<option value="${j.replace(/"/g,'&quot;')}">${j}</option>`).join('');
      judgeSelect.selectedIndex=0;
      if(!judges.length){setStatus('No judges found. Open landing page and click "Save Lists".');}
    }
    function renderChips(){
      let chips=uniqueClean(readJSON(LS_CHIPS,[])); chips=chips.filter(x=>/^\\d+$/.test(x)).sort((a,b)=>Number(a)-Number(b));
      chipSelect.innerHTML='<option value="" disabled>Select chip #</option>'+chips.map(c=>`<option value="${c.replace(/"/g,'&quot;')}">${c}</option>`).join('');
      chipSelect.selectedIndex=0;
      if(!chips.length){setStatus('No chips found. Open landing page and click "Save Lists".');}
    }
    function addChip(){
      const v=String(chipAddIn.value||'').trim();
      if(!/^\\d+$/.test(v)){setStatus('Chip # must be a number.');return;}
      const chips=readJSON(LS_CHIPS,[]);
      if(!chips.includes(v)){chips.push(v);writeJSON(LS_CHIPS,chips);}
      chipAddIn.value=''; renderChips(); setStatus('Chip # added.',true);
    }

    const readEntries=()=>readJSON(LS_ENTRIES,[]);
    const writeEntries=a=>writeJSON(LS_ENTRIES,a||[]);
    const isDup=(j,c)=>readEntries().some(r=>String(r.judge_id).trim().toLowerCase()===j.trim().toLowerCase() && String(r.chip_number)===String(c));

    function exportCSV(){
      const rows=readEntries();
      if(!rows.length){setStatus('No entries to export.');return;}
      const headers=["timestamp","judge_id","chip_number","score_appearance","score_tenderness","score_flavor","score_total"];
      const lines=[headers.join(",")];
      rows.forEach(r=>{
        const out=headers.map(h=>{const v=(r[h]===undefined||r[h]===null)?'':String(r[h]).replace(/"/g,'""');return `"${v}"`;}).join(",");
        lines.push(out);
      });
      const blob=new Blob([lines.join("\\n")],{type:"text/csv"});
      const url=URL.createObjectURL(blob); const a=document.createElement('a');
      a.href=url; a.download='blind_taste_export.csv'; document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url);
      setStatus('CSV exported.',true);
    }

    function clearForm(){judgeSelect.selectedIndex=0;chipSelect.selectedIndex=0;clearScores();setStatus('Form cleared.',true);}

    function onSave(e){
      e.preventDefault();
      const judge=String(judgeSelect.value||'').trim();
      const chip=String(chipSelect.value||'').trim();
      if(!judge){setStatus('Please select a Judge.');return;}
      if(!chip){setStatus('Please select a Chip #.');return;}
      if(isDup(judge,chip)){alert('Error: This Judge + Chip # has already been saved.');return;}
      const row={
        timestamp:new Date().toISOString(),
        judge_id:judge,
        chip_number:Number(chip),
        score_appearance:pickVal('scores-appearance'),
        score_tenderness:pickVal('scores-tenderness'),
        score_flavor:pickVal('scores-flavor'),
        score_total:Number(totalEl.textContent||'0')
      };
      const all=readEntries(); all.push(row); writeEntries(all);
      alert(`Saved! Chip #${row.chip_number}, Judge ${row.judge_id}.`);
      clearForm();
    }

    function init(){
      buildCat('scores-appearance',APPEAR);
      buildCat('scores-tenderness',TENDER);
      buildCat('scores-flavor',FLAVOR);
      renderJudges(); renderChips();
      chipAddBtn.addEventListener('click',addChip);
      chipAddIn.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();addChip();}});
      form.addEventListener('submit',onSave);
      exportBtn.addEventListener('click',exportCSV);
      clearBtn.addEventListener('click',clearForm);
      window.addEventListener('storage',e=>{if(e.key==='judgesList')renderJudges(); if(e.key==='chipsList')renderChips();});
    }
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
  })();
  </script>
</body>
</html>
'@

# Inject CSS and Header into the template
$blindHtml = $blindHtml.Replace('__BASE_CSS__', $baseCss).Replace('__HEADER_HTML__', $headerHtml)

# Backup and write blind.html
if (Test-Path $blindPath) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  Copy-Item $blindPath (Join-Path $rootPath ("blind.backup-" + $stamp + ".html")) -Force
}
$blindHtml | Set-Content -Path $blindPath -Encoding UTF8

Write-Host "✅ Copied header from $LandingFile into $BlindFile"
Write-Host "✅ $BlindFile reads judgesList & chipsList from localStorage"
Write-Host "Next: open landing.html, enter Judges & Chips in the Setup panel, click 'Save Lists', then reload blind.html."
Write-Host ("landing: file:///" + ((Resolve-Path $landingPath).Path -replace '\\','/'))
Write-Host ("blind  : file:///" + ((Resolve-Path $blindPath).Path   -replace '\\','/'))
