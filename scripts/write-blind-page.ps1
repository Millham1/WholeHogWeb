# write-blind-page.ps1  (PS 5.1 & 7)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }

$blindHtmlPath = Join-Path $WebRoot 'blind.html'
$blindJsPath   = Join-Path $WebRoot 'blind-sb.js'

# ---------- HTML ----------
$html = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Blind Taste Scoring</title>
  <link rel="stylesheet" href="styles.css">
  <script src="supabase-config.js"></script>
  <style>
    /* Force header to 2.25in and vertically center left/right images */
    header.header { position: relative; height: 2.25in; min-height: 2.25in; line-height: normal; }
    header.header img#logoLeft { position:absolute; left:18px; top:50%; transform:translateY(-50%); height:calc(100% - 24px); width:auto; }
    header.header img.right-img { position:absolute; right:18px; top:50%; transform:translateY(-50%); height:calc(100% - 24px); width:auto; }
    header.header h1 { margin:0; text-align:center; position:absolute; left:0; right:0; top:50%; transform:translateY(-50%); }
    /* Minimal card layout if styles.css is sparse */
    .page-wrap{max-width:1200px;margin:0 auto;padding:12px;}
    .panel{margin:10px 0;}
    .grid-two{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:14px;}
    .card{background:#fff;border:1px solid #ddd;border-radius:14px;padding:14px;}
    .row{display:grid;grid-template-columns:160px 1fr;gap:10px;align-items:center;margin:8px 0;}
    .score-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;}
    .mini-card{background:#fff;border:1px solid #ddd;border-radius:12px;padding:10px;position:relative;min-height:96px;}
    .mini-head{font-weight:700;margin-bottom:8px;}
    .range{color:#666;font-weight:400;margin-left:4px;}
    .picker-btn{width:100%;padding:10px 12px;border:1px solid #bbb;border-radius:10px;background:#f8f8f8;cursor:pointer;font-weight:600;}
    .options{display:none;margin-top:8px;border-top:1px dashed #ddd;padding-top:8px;}
    .options.show{display:block;}
    .options .opt{margin:4px 4px 0 0;padding:6px 8px;border:1px solid #bbb;background:#fff;border-radius:8px;cursor:pointer;}
    .total-row{display:grid;grid-template-columns:60px 1fr auto;gap:10px;align-items:center;margin-top:12px;}
    .total-label{font-weight:700;}
    .total-val{font-weight:800;font-size:1.2rem;}
    .btn-primary{background:#0b4fff;color:#fff;border:0;border-radius:10px;padding:10px 16px;font-weight:700;cursor:pointer;}
    table.lb{width:100%;border-collapse:collapse;}
    table.lb th,table.lb td{border-bottom:1px solid #eee;padding:8px 6px;text-align:left;}
  </style>
</head>
<body>
  <header class="header">
    <img id="logoLeft" src="Legion whole hog logo.png" alt="Whole Hog">
    <h1>Blind Taste Scoring</h1>
    <img class="right-img" src="AL Medallion.png" alt="American Legion">
  </header>

  <main class="page-wrap">
    <section class="panel">
      <div class="grid-two">
        <div class="card">
          <h2>Judge & Chip</h2>
          <div class="row">
            <label for="judgeSelect">Judge</label>
            <select id="judgeSelect"><option value="">Loading judges…</option></select>
          </div>
          <div class="row">
            <label for="chipInput">Chip Number</label>
            <input id="chipInput" type="text" placeholder="e.g., 203"/>
          </div>
        </div>

        <div class="card" id="scoringCard">
          <h2>Scores</h2>
          <div class="score-grid">
            <div class="mini-card" id="cardAppearance">
              <div class="mini-head">Appearance <span class="range">(2-40)</span></div>
              <button class="picker-btn" data-for="appearance"><span class="sel">Choose</span></button>
              <div class="options" data-for="appearance"></div>
            </div>

            <div class="mini-card" id="cardTenderness">
              <div class="mini-head">Tenderness <span class="range">(2-40)</span></div>
              <button class="picker-btn" data-for="tenderness"><span class="sel">Choose</span></button>
              <div class="options" data-for="tenderness"></div>
            </div>

            <div class="mini-card" id="cardTaste">
              <div class="mini-head">Taste <span class="range">(4-80)</span></div>
              <button class="picker-btn" data-for="taste"><span class="sel">Choose</span></button>
              <div class="options" data-for="taste"></div>
            </div>
          </div>

          <div class="total-row">
            <div class="total-label">Total</div>
            <div class="total-val" id="totalDisplay">0</div>
            <button id="saveBtn" class="btn-primary">Save</button>
          </div>
        </div>
      </div>
    </section>

    <section class="panel">
      <h2>Leaderboard (Blind)</h2>
      <div id="leaderboard">Loading…</div>
    </section>
  </main>

  <script src="blind-sb.js"></script>
</body>
</html>
'@

# ---------- JS ----------
$js = @'
(function(){
  'use strict';

  function $(sel){ return document.querySelector(sel); }
  function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }

  // GET helper that reuses WHOLEHOG.sb if present
  function sbGet(path){
    if(window.WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.get){
      return WHOLEHOG.sb.get(path).then(r=>r.json());
    }
    var base = (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) ? WHOLEHOG.sbProjectUrl : '';
    return fetch(base + path, {
      method:'GET',
      headers:{
        'apikey': (WHOLEHOG && WHOLEHOG.sbAnonKey) || '',
        'Authorization':'Bearer ' + ((WHOLEHOG && WHOLEHOG.sbAnonKey) || '')
      }
    }).then(r=>r.json());
  }

  // POST helper that reuses WHOLEHOG.sb if present
  function sbPost(path, body){
    if(window.WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.post){
      return WHOLEHOG.sb.post(path, body).then(r=>r.json());
    }
    var base = (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) ? WHOLEHOG.sbProjectUrl : '';
    return fetch(base + path, {
      method:'POST',
      headers:{
        'apikey': (WHOLEHOG && WHOLEHOG.sbAnonKey) || '',
        'Authorization':'Bearer ' + ((WHOLEHOG && WHOLEHOG.sbAnonKey) || ''),
        'Content-Type':'application/json',
        'Prefer':'return=representation'
      },
      body: JSON.stringify(body)
    }).then(r=>r.json());
  }

  // Build score pickers
  var scores = { appearance:null, tenderness:null, taste:null };

  function buildOptions(container, min, max, step){
    var frag = document.createDocumentFragment();
    for(var v=min; v<=max; v+=step){
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'opt';
      b.textContent = String(v);
      (function(val){
        b.addEventListener('click', function(){
          var key = container.getAttribute('data-for');
          scores[key] = val;
          var lab = document.querySelector('button.picker-btn[data-for="'+key+'"] .sel');
          if(lab){ lab.textContent = String(val); }
          container.classList.remove('show');
          updateTotal();
        });
      })(v);
      frag.appendChild(b);
    }
    container.innerHTML = '';
    container.appendChild(frag);
  }

  function attachPicker(key, min, max, step){
    var btn = document.querySelector('button.picker-btn[data-for="'+key+'"]');
    var box = document.querySelector('div.options[data-for="'+key+'"]');
    if(!btn || !box) return;
    buildOptions(box, min, max, step);
    btn.addEventListener('click', function(){
      $all('div.options.show').forEach(function(el){ if(el!==box) el.classList.remove('show'); });
      box.classList.toggle('show');
    });
  }

  function updateTotal(){
    var a = scores.appearance||0, t = scores.tenderness||0, ta = scores.taste||0;
    var td = document.getElementById('totalDisplay');
    if(td) td.textContent = String(a+t+ta);
  }

  function loadJudges(){
    var sel = document.getElementById('judgeSelect');
    if(!sel) return;
    sel.innerHTML = '<option value="">Loading…</option>';
    sbGet('/rest/v1/judges?select=id,name&order=name')
      .then(function(rows){
        sel.innerHTML = '<option value="">Select judge…</option>';
        (rows||[]).forEach(function(r){
          var o = document.createElement('option');
          o.value = r.id; o.textContent = r.name;
          sel.appendChild(o);
        });
      })
      .catch(function(){
        sel.innerHTML = '<option value="">Error loading judges</option>';
      });
  }

  function saveEntry(){
    var judgeId = document.getElementById('judgeSelect').value;
    var chip = (document.getElementById('chipInput').value||'').trim();
    if(!judgeId){ alert('Pick a judge'); return; }
    if(!chip){ alert('Enter a chip number'); return; }
    if(scores.appearance==null || scores.tenderness==null || scores.taste==null){
      alert('Pick all three scores'); return;
    }
    var body = [{
      judge_id: judgeId,
      chip_number: chip,
      appearance: scores.appearance,
      tenderness: scores.tenderness,
      taste: scores.taste
    }];
    sbPost('/rest/v1/blind_entries', body)
      .then(function(resp){
        if(Array.isArray(resp) && resp.length){
          // reset and refresh
          scores.appearance = scores.tenderness = scores.taste = null;
          $all('.picker-btn .sel').forEach(function(s){ s.textContent='Choose'; });
          updateTotal();
          document.getElementById('chipInput').value='';
          refreshLeaderboard();
        } else {
          console.warn('Save response', resp);
          alert('Could not save (check Supabase table & RLS).');
        }
      })
      .catch(function(err){
        console.error(err);
        alert('Error saving score.');
      });
  }

  function refreshLeaderboard(){
    // Requires a view v_blind_leaderboard
    sbGet('/rest/v1/v_blind_leaderboard?select=chip_number,total_points,tie_taste,tie_tenderness,tie_appearance&order=total_points.desc,tie_taste.desc,tie_tenderness.desc,tie_appearance.desc&limit=20')
      .then(function(rows){
        var host = document.getElementById('leaderboard');
        if(!host) return;
        if(!rows || !rows.length){ host.textContent='No scores yet.'; return; }
        var html = '<table class="lb"><thead><tr><th>Rank</th><th>Chip</th><th>Total</th></tr></thead><tbody>';
        rows.forEach(function(r, idx){
          html += '<tr><td>'+(idx+1)+'</td><td>'+r.chip_number+'</td><td>'+r.total_points+'</td></tr>';
        });
        html += '</tbody></table>';
        host.innerHTML = html;
      })
      .catch(function(){
        var host = document.getElementById('leaderboard');
        if(host) host.textContent = 'Leaderboard view missing (run SQL).';
      });
  }

  // Init
  document.addEventListener('click', function(e){
    if(!e.target.closest('.mini-card')){
      $all('.options.show').forEach(function(x){ x.classList.remove('show'); });
    }
  });

  attachPicker('appearance', 2, 40, 2);
  attachPicker('tenderness', 2, 40, 2);
  attachPicker('taste', 4, 80, 4);
  updateTotal();
  loadJudges();
  refreshLeaderboard();

  var saveBtn = document.getElementById('saveBtn');
  if(saveBtn){ saveBtn.addEventListener('click', saveEntry); }
})();
'@

# Write files
Write-Text $blindHtmlPath $html
Write-Text $blindJsPath   $js

Write-Host "Wrote:" -ForegroundColor Cyan
Write-Host " - $blindHtmlPath"
Write-Host " - $blindJsPath"

# Show what exists
Get-Item $blindHtmlPath, $blindJsPath | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize

# Try to open
try { Start-Process $blindHtmlPath } catch {}
Write-Host "Done. If your browser cached old content, press Ctrl+F5." -ForegroundColor Green
