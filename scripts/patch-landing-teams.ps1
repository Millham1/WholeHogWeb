param(
  # Your current site folder:
  [string]$WebRoot    = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",

  # Your Supabase credentials (defaults filled with what you gave me)
  [string]$ProjectUrl = "https://wiolulxxfyetvdpnfusq.supabase.co",
  [string]$AnonKey    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc"
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
function Backup-Once([string]$Path){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path (Split-Path $Path -Parent) ((Split-Path $Path -Leaf) + ".bak_" + $stamp)
  Copy-Item $Path $bak -Force
  Write-Host ("Backup saved: {0}" -f $bak) -ForegroundColor Yellow
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }
$LandingHtml = Join-Path $WebRoot 'landing.html'
if(-not (Test-Path $LandingHtml)){ throw "landing.html not found at $LandingHtml" }

# 1) Ensure supabase-config.js exists (only create if missing)
$CfgJsPath = Join-Path $WebRoot 'supabase-config.js'
if(-not (Test-Path $CfgJsPath)){
  $cfg = @"
(function(){
  window.WHOLEHOG = window.WHOLEHOG || {};
  window.WHOLEHOG.sbProjectUrl = "$ProjectUrl";
  window.WHOLEHOG.sbAnonKey    = "$AnonKey";
})();
"@
  Write-Text $CfgJsPath $cfg
  Write-Host "Created supabase-config.js" -ForegroundColor Cyan
} else {
  Write-Host "supabase-config.js already exists; left untouched." -ForegroundColor DarkGray
}

# 2) Write/refresh landing-teams.js (idempotent; we always overwrite this helper)
$LandingJsPath = Join-Path $WebRoot 'landing-teams.js'
$landingJs = @"
(function(){
  function headers(){
    var key = (window.WHOLEHOG && WHOLEHOG.sbAnonKey) || "";
    return {
      "apikey": key,
      "Authorization": "Bearer " + key,
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    };
  }
  function base(){
    return (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) || "";
  }

  function qsel(id){ return document.getElementById(id); }
  function esc(s){ var d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

  function renderTeams(list){
    var ul = qsel('whTeamsList');
    if(!ul) return;
    if(!Array.isArray(list) || list.length === 0){
      ul.innerHTML = '<li style="color:#666;padding:6px 8px;">No teams yet</li>';
      return;
    }
    var html = list.map(function(t){
      var label = esc(t.name) + ' (Site ' + esc(t.site_number || '') + ')';
      return (
        '<li style="display:flex;align-items:center;justify-content:space-between;padding:8px 10px;border:1px solid #ddd;border-radius:8px;margin:6px 0;">' +
          '<span>' + label + '</span>' +
          '<button data-id="' + esc(t.id) + '" class="wh-remove-team" style="background:#fff;color:#b10020;border:2px solid #b10020;border-radius:8px;padding:6px 10px;cursor:pointer;">Remove</button>' +
        '</li>'
      );
    }).join('');
    ul.innerHTML = html;

    // wire remove buttons
    var btns = ul.querySelectorAll('button.wh-remove-team');
    Array.prototype.forEach.call(btns, function(btn){
      btn.addEventListener('click', function(){
        var id = btn.getAttribute('data-id');
        if(!id) return;
        if(!confirm('Remove this team? (This will fail if the team already has scoring entries.)')) return;

        fetch(base() + '/rest/v1/teams?id=eq.' + encodeURIComponent(id), {
          method: 'DELETE',
          headers: headers()
        })
        .then(function(r){ return r.ok ? r.text() : r.text().then(function(t){ throw new Error(t || r.statusText); }); })
        .then(function(){
          loadTeams(); // refresh after deletion
        })
        .catch(function(err){
          alert('Delete failed (team may have linked scores): ' + err.message);
        });
      });
    });
  }

  function loadTeams(){
    var url = base() + '/rest/v1/teams?select=id,name,site_number&order=site_number.asc';
    fetch(url, { method:'GET', headers: headers() })
      .then(function(r){ return r.ok ? r.json() : r.text().then(function(t){ throw new Error(t || r.statusText); }); })
      .then(renderTeams)
      .catch(function(err){ console.error('Load teams failed:', err); });
  }

  function addTeam(){
    var name = (qsel('whTeamName') && qsel('whTeamName').value || '').trim();
    var site = (qsel('whSiteNumber') && qsel('whSiteNumber').value || '').trim();
    if(!name || !site){ alert('Enter both Team Name and Site #'); return; }

    var body = [{ name: name, site_number: site }];

    fetch(base() + '/rest/v1/teams', {
      method:'POST',
      headers: headers(),
      body: JSON.stringify(body)
    })
    .then(function(r){ return r.ok ? r.json() : r.text().then(function(t){ throw new Error(t || r.statusText); }); })
    .then(function(){
      if(qsel('whTeamName')) qsel('whTeamName').value = '';
      if(qsel('whSiteNumber')) qsel('whSiteNumber').value = '';
      loadTeams();
    })
    .catch(function(err){ alert('Add failed: ' + err.message); });
  }

  function ensureWiring(){
    var btn = qsel('whBtnAddTeam');
    if(btn && !btn._wh_wired){
      btn.addEventListener('click', addTeam);
      btn._wh_wired = true;
    }
  }

  function init(){
    ensureWiring();
    loadTeams();
  }

  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
"@
Write-Text $LandingJsPath $landingJs
Write-Host "Wrote landing-teams.js" -ForegroundColor Cyan

# 3) Inject/refresh a compact Teams UI block in landing.html (idempotent, between markers)
$html = Read-Text $LandingHtml
$startMarker = "<!-- WHOLEHOG LANDING TEAMS UI START -->"
$endMarker   = "<!-- WHOLEHOG LANDING TEAMS UI END -->"

$uiBlock = @"
$startMarker
<section id="whTeamsCard" style="margin:18px auto;max-width:1000px;border:1px solid #ddd;border-radius:12px;padding:14px;background:#fff;">
  <h2 style="margin:0 0 12px 0;">Teams</h2>
  <div style="display:flex;gap:14px;align-items:flex-end;flex-wrap:wrap;">
    <div style="flex:1 1 280px;">
      <label for="whTeamName" style="display:block;font-weight:600;margin-bottom:4px;">Team Name</label>
      <input id="whTeamName" type="text" style="width:100%;padding:8px 10px;border:1px solid #bbb;border-radius:8px;" placeholder="e.g., Demo Team" />
    </div>
    <div style="flex:0 0 200px;">
      <label for="whSiteNumber" style="display:block;font-weight:600;margin-bottom:4px;">Site #</label>
      <input id="whSiteNumber" type="text" style="width:100%;padding:8px 10px;border:1px solid #bbb;border-radius:8px;" placeholder="e.g., 101" />
    </div>
    <div style="flex:0 0 auto;">
      <button id="whBtnAddTeam" class="btn-red-black" style="background:#b10020;color:#111;border:2px solid #111;border-radius:10px;padding:10px 16px;font-weight:700;cursor:pointer;">Add Team</button>
    </div>
  </div>

  <div style="margin-top:14px;">
    <ul id="whTeamsList" style="list-style:none;padding:0;margin:0;"></ul>
  </div>

  <p style="margin-top:10px;color:#666;font-size:12px;">Tip: Use Remove to delete a team added in error. (If the team already has scoring entries, removal will be blocked.)</p>
</section>
$endMarker
"@

$changed = $false
if($html -like "*$startMarker*`*"){
  # Replace existing block between markers
  $i1 = $html.IndexOf($startMarker)
  $i2 = $html.IndexOf($endMarker)
  if($i1 -ge 0 -and $i2 -gt $i1){
    $before = $html.Substring(0, $i1)
    $after  = $html.Substring($i2 + $endMarker.Length)
    $html = $before + $uiBlock + $after
    $changed = $true
  }
} else {
  # Insert the block after </header> if possible, else after <body>
  $inserted = $false
  $idxHeader = $html.IndexOf("</header>", [StringComparison]::OrdinalIgnoreCase)
  if($idxHeader -ge 0){
    $pos = $idxHeader + 9
    $html = $html.Substring(0,$pos) + "`r`n" + $uiBlock + "`r`n" + $html.Substring($pos)
    $inserted = $true
  } else {
    $idxBody = $html.IndexOf("<body", [StringComparison]::OrdinalIgnoreCase)
    if($idxBody -ge 0){
      $idxGT = $html.IndexOf(">", $idxBody)
      if($idxGT -ge 0){
        $pos = $idxGT + 1
        $html = $html.Substring(0,$pos) + "`r`n" + $uiBlock + "`r`n" + $html.Substring($pos)
        $inserted = $true
      }
    }
  }
  if($inserted){ $changed = $true }
}

# 4) Ensure script tags are present before </body>
function EnsureScriptTag([string]$Html,[string]$Src){
  if($Html -like "*$Src*"){ return $Html }
  $idx = $Html.LastIndexOf("</body>", [StringComparison]::OrdinalIgnoreCase)
  $tag = "<script src=""$Src""></script>"
  if($idx -ge 0){
    return $Html.Substring(0,$idx) + " `r`n  $tag`r`n" + $Html.Substring($idx)
  } else {
    return $Html + "`r`n$tag`r`n"
  }
}
$orig = $html
$html = EnsureScriptTag $html "supabase-config.js"
$html = EnsureScriptTag $html "landing-teams.js"
if($html -ne $orig){ $changed = $true }

if($changed){
  Backup-Once $LandingHtml
  Write-Text $LandingHtml $html
  Write-Host "landing.html patched. Hard-refresh your browser (Ctrl+F5)." -ForegroundColor Cyan
} else {
  Write-Host "landing.html already had the Teams UI and scripts; no changes written." -ForegroundColor DarkGray
}

Write-Host "Done." -ForegroundColor Green
