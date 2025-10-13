# add-blind-page.ps1  (PowerShell 5.1 & 7 compatible)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Backup-Once([string[]]$Files){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $WebRoot ("BACKUP_blind_" + $stamp)
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

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }

$OnsiteHtml = Join-Path $WebRoot 'onsite.html'
$BlindHtml  = Join-Path $WebRoot 'blind.html'
$BlindJs    = Join-Path $WebRoot 'blind-sb.js'
$CssPath    = Join-Path $WebRoot 'styles.css'

# Require onsite.html and styles.css so we can reuse header + styles
$missing = @()
foreach($f in @($OnsiteHtml,$CssPath)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`r`n" + ($missing -join "`r`n")) }

Backup-Once @('blind.html','blind-sb.js','styles.css')

# ---- Extract header from onsite.html, tweak title only ----
$onsite = Read-Text $OnsiteHtml
$reHeader = New-Object System.Text.RegularExpressions.Regex '(?is)<header\b[^>]*>.*?</header>'
$m = $reHeader.Match($onsite)
$header = $null
if($m.Success){
  $header = $m.Value
  # If there is an <h1>, replace its text with "Blind Taste Scoring". Else, inject an <h1>.
  $reH1 = New-Object System.Text.RegularExpressions.Regex '(?is)<h1\b[^>]*>.*?</h1>'
  if($reH1.IsMatch($header)){
    $header = $reH1.Replace($header, '<h1>Blind Taste Scoring</h1>', 1)
  } else {
    $header = $header -replace '(?is)(<header\b[^>]*>)','$1' + '<h1>Blind Taste Scoring</h1>'
  }
} else {
  # Fallback header (in case onsite.html has a custom structure)
  $header = @"
<header class=""app-header"">
  <h1>Blind Taste Scoring</h1>
</header>
"@
}

# ---- Blind page HTML skeleton; we’ll drop the copied header where <!--HEADER--> is ----
$blindHtml = @"
<!doctype html>
<html lang=""en"">
<head>
  <meta charset=""utf-8""/>
  <meta name=""viewport"" content=""width=device-width,initial-scale=1""/>
  <title>Blind Taste Scoring</title>
  <link rel=""stylesheet"" href=""styles.css"">
  <script src=""supabase-config.js""></script>
</head>
<body>
  <!--HEADER-->
  <main class=""page-wrap"">
    <section class=""panel"">
      <div class=""grid-two"">
        <div class=""card"">
          <h2>Judge & Chip</h2>
          <div class=""row"">
            <label for=""judgeSelect"">Judge</label>
            <select id=""judgeSelect""><option value="""">Loading judges…</option></select>
          </div>
          <div class=""row"">
            <label for=""chipInput"">Chip Number</label>
            <input id=""chipInput"" type=""text"" placeholder=""e.g., 203"" />
          </div>
        </div>

        <div class=""card"" id=""scoringCard"">
          <h2>Scores</h2>
          <div class=""score-grid"">
            <div class=""mini-card"" id=""cardAppearance"">
              <div class=""mini-head"">Appearance <span class=""range"">(2–40)</span></div>
              <button class=""picker-btn"" data-for=""appearance""><span class=""sel"">Choose</span></button>
              <div class=""options"" data-for=""appearance""></div>
            </div>

            <div class=""mini-card"" id=""cardTenderness"">
              <div class=""mini-head"">Tenderness <span class=""range"">(2–40)</span></div>
              <button class=""picker-btn"" data-for=""tenderness""><span class=""sel"">Choose</span></button>
              <div class=""options"" data-for=""tenderness""></div>
            </div>

            <div class=""mini-card"" id=""cardTaste"">
              <div class=""mini-head"">Taste <span class=""range"">(4–80)</span></div>
              <button class=""picker-btn"" data-for=""taste""><span class=""sel"">Choose</span></button>
              <div class=""options"" data-for=""taste""></div>
            </div>
          </div>

          <div class=""total-row"">
            <div class=""total-label"">Total</div>
            <div class=""total-val"" id=""totalDisplay"">0</div>
            <button id=""saveBtn"" class=""btn-primary"">Save</button>
          </div>
        </div>
      </div>
    </section>

    <section class=""panel"">
      <h2>Leaderboard (Blind)</h2>
      <div id=""leaderboard"">Loading…</div>
    </section>
  </main>

  <script src=""blind-sb.js""></script>
</body>
</html>
"@

$blindHtml = $blindHtml.Replace('<!--HEADER-->', $header)
Write-Text $BlindHtml $blindHtml
Write-Host "Wrote blind.html" -ForegroundColor Cyan

# ---- blind-sb.js (Supabase wiring + UI pickers) ----
$blindJs = @"
(function(){
  'use strict';

  function $(sel){ return document.querySelector(sel); }
  function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }

  // Minimal fetch helpers (re-use WHOLEHOG.sb if present)
  function sbGet(path){
    if(window.WHOLEHOG && window.WHOLEHOG.sb && window.WHOLEHOG.sb.get){
      return window.WHOLEHOG.sb.get(path).then(r=>r.json());
    }
    // fallback (expects supabase-config.js set project/key)
    var url = (window.WHOLEHOG && WHOLEHOG.sbProjectUrl ? WHOLEHOG.sbProjectUrl : '') + path;
    return fetch(url, {
      method:'GET',
      headers:{
        'apikey': (WHOLEHOG && WHOLEHOG.sbAnonKey) || '',
        'Authorization':'Bearer ' + ((WHOLEHOG && WHOLEHOG.sbAnonKey) || '')
      }
    }).then(r=>r.json());
  }
  function sbPost(path, body){
    if(window.WHOLEHOG && window.WHOLEHOG.sb && window.WHOLEHOG.sb.post){
      return window.WHOLEHOG.sb.post(path, body).then(r=>r.json());
    }
    var url = (WHOLEHOG && WHOLEHOG.sbProjectUrl ? WHOLEHOG.sbProjectUrl : '') + path;
    return fetch(url, {
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
          // show selection on the button label
          var btn = document.querySelector('button.picker-btn[data-for="'+key+'"] .sel');
          if(btn){ btn.textContent = String(val); }
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
      // close others
      $all('div.options.show').forEach(function(el){ if(el!==box) el.classList.remove('show'); });
      box.classList.toggle('show');
    });
  }

  function updateTotal(){
    var a = scores.appearance||0, t = scores.tenderness||0, ta = scores.taste||0;
    $('#totalDisplay').textContent = String(a+t+ta);
  }

  function loadJudges(){
    var sel = $('#judgeSelect');
    sel.innerHTML = '<option value="""">Loading…</option>';
    sbGet('/rest/v1/judges?select=id,name&order=name').then(function(rows){
      sel.innerHTML = '<option value="""">Select judge…</option>';
      rows.forEach(function(r){
        var o = document.createElement('option');
        o.value = r.id; o.textContent = r.name;
        sel.appendChild(o);
      });
    }).catch(function(){
      sel.innerHTML = '<option value="""">Error loading judges</option>';
    });
  }

  function saveEntry(){
    var judgeId = $('#judgeSelect').value;
    var chip = ($('#chipInput').value||'').trim();
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
    sbPost('/rest/v1/blind_entries', body).then(function(resp){
      if(Array.isArray(resp) && resp.length){
        // reset UI and refresh leaderboard
        scores.appearance = scores.tenderness = scores.taste = null;
        $all('.picker-btn .sel').forEach(function(s){ s.textContent='Choose'; });
        updateTotal();
        $('#chipInput').value='';
        refreshLeaderboard();
      } else {
        console.warn('Save response', resp);
        alert('Could not save (check Supabase table & RLS).');
      }
    }).catch(function(err){
      console.error(err);
      alert('Error saving score.');
    });
  }

  function refreshLeaderboard(){
    // Expect a view v_blind_leaderboard (see SQL below)
    sbGet('/rest/v1/v_blind_leaderboard?select=chip_number,total_points,tie_taste,tie_tenderness,tie_appearance&order=total_points.desc,tie_taste.desc,tie_tenderness.desc,tie_appearance.desc&limit=20')
      .then(function(rows){
        if(!rows || !rows.length){ $('#leaderboard').textContent='No scores yet.'; return; }
        var html = '<table class="lb"><thead><tr><th>Rank</th><th>Chip</th><th>Total</th></tr></thead><tbody>';
        rows.forEach(function(r, idx){
          html += '<tr><td>'+(idx+1)+'</td><td>'+r.chip_number+'</td><td>'+r.total_points+'</td></tr>';
        });
        html += '</tbody></table>';
        $('#leaderboard').innerHTML = html;
      }).catch(function(){
        $('#leaderboard').textContent = 'Leaderboard view missing (run SQL step).';
      });
  }

  // Init
  document.addEventListener('click', function(e){
    // click outside closes menus
    if(!e.target.closest('.mini-card')){ $all('.options.show').forEach(function(x){ x.classList.remove('show'); }); }
  });

  attachPicker('appearance', 2, 40, 2);
  attachPicker('tenderness', 2, 40, 2);
  attachPicker('taste', 4, 80, 4);
  updateTotal();
  loadJudges();
  refreshLeaderboard();

  var saveBtn = $('#saveBtn');
  if(saveBtn){ saveBtn.addEventListener('click', saveEntry); }
})();
"@

Write-Text $BlindJs $blindJs
Write-Host "Wrote blind-sb.js" -ForegroundColor Cyan

# ---- Add light styles (non-destructive) for mini cards & leaderboard ----
$css = Read-Text $CssPath
$marker = '/* WH: blind scoring add-ons */'
if($css -notmatch [regex]::Escape($marker)){
  $addon = @"
$marker
.page-wrap { max-width: 1200px; margin: 0 auto; padding: 12px; }
.grid-two { display: grid; grid-template-columns: repeat(auto-fit,minmax(340px,1fr)); gap: 14px; }
.panel { margin: 10px 0; }
.card { background: #fff; border: 1px solid #ddd; border-radius: 14px; padding: 14px; }
.card h2 { margin: 0 0 10px 0; }
.row { display: grid; grid-template-columns: 160px 1fr; gap: 10px; align-items: center; margin: 8px 0; }
.score-grid { display: grid; grid-template-columns: repeat(auto-fit,minmax(220px,1fr)); gap: 12px; }
.mini-card { background:#fff; border:1px solid #ddd; border-radius:12px; padding:10px; position:relative; min-height:96px; }
.mini-head { font-weight:700; margin-bottom:8px; }
.range { color:#666; font-weight:400; margin-left:4px; }
.picker-btn { width:100%; padding:10px 12px; border:1px solid #bbb; border-radius:10px; background:#f8f8f8; cursor:pointer; font-weight:600; }
.options { display:none; margin-top:8px; border-top:1px dashed #ddd; padding-top:8px; }
.options.show { display:block; }
.options .opt { margin:4px 4px 0 0; padding:6px 8px; border:1px solid #bbb; background:#fff; border-radius:8px; cursor:pointer; }
.total-row { display:grid; grid-template-columns: 60px 1fr auto; gap:10px; align-items:center; margin-top:12px; }
.total-label { font-weight:700; }
.total-val { font-weight:800; font-size:1.2rem; }
.btn-primary { background:#0b4fff; color:#fff; border:0; border-radius:10px; padding:10px 16px; font-weight:700; cursor:pointer; }
table.lb { width:100%; border-collapse:collapse; }
table.lb th, table.lb td { border-bottom:1px solid #eee; padding:8px 6px; text-align:left; }
"@
  $css = $css + "`r`n" + $addon + "`r`n"
  Write-Text $CssPath $css
  Write-Host "Appended blind styles to styles.css" -ForegroundColor Cyan
} else {
  Write-Host "Blind styles already present." -ForegroundColor DarkGray
}

Write-Host "`nDone. Open blind.html (Ctrl+F5 if cached) and try a save." -ForegroundColor Green
