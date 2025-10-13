param(
  [string]$WebRoot    = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$ProjectUrl = "https://wiolulxxfyetvdpnfusq.supabase.co",
  [string]$AnonKey    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Ensure-ScriptTag([string]$Html,[string]$Src){
  if($Html -like "*$Src*"){ return $Html }
  $idx = $Html.LastIndexOf("</body>", [StringComparison]::OrdinalIgnoreCase)
  $tag = "<script src=""$Src""></script>"
  if($idx -ge 0){
    return $Html.Substring(0,$idx) + "`r`n  $tag`r`n" + $Html.Substring($idx)
  } else {
    return $Html + "`r`n$tag`r`n"
  }
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }
$landingHtml = Join-Path $WebRoot 'landing.html'
$onsiteHtml  = Join-Path $WebRoot 'onsite.html'

if(-not (Test-Path $landingHtml)){ throw "landing.html not found: $landingHtml" }
if(-not (Test-Path $onsiteHtml)){  throw "onsite.html not found: $onsiteHtml"  }

# 1) supabase-config.js (create/update to ensure correct URL/Key)
$cfgPath = Join-Path $WebRoot 'supabase-config.js'
$cfgJs = @"
(function(){
  window.WHOLEHOG = window.WHOLEHOG || {};
  window.WHOLEHOG.sbProjectUrl = "$ProjectUrl";
  window.WHOLEHOG.sbAnonKey    = "$AnonKey";
})();
"@
Write-Text $cfgPath $cfgJs

# 2) migrate-teams.js — runs on LANDING page, one-time migration from any localStorage array
$migratePath = Join-Path $WebRoot 'migrate-teams.js'
$migrateJs = @"
(function(){
  try {
    if (!window.WHOLEHOG) window.WHOLEHOG = {};
    var base = (WHOLEHOG.sbProjectUrl || '').replace(/\/+$/,'');
    var key  = WHOLEHOG.sbAnonKey || '';
    if (!base || !key) return;

    if (localStorage.getItem('WH_MIGRATED_TEAMS_TO_SB') === 'yes') return;

    function headers(){
      return {
        'apikey': key,
        'Authorization': 'Bearer ' + key,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      };
    }

    function looksLikeTeams(arr){
      if (!Array.isArray(arr) || arr.length === 0) return false;
      // accept objects with name + (site or site_number)
      var ok = arr.some(function(o){
        return o && typeof o === 'object' &&
               typeof o.name === 'string' &&
               (typeof o.site === 'string' || typeof o.site_number === 'string');
      });
      return ok;
    }

    function normalizeTeam(o){
      return {
        name: (o.name || '').trim(),
        site_number: (o.site_number || o.site || '').toString().trim()
      };
    }

    function uniqByNameSite(list){
      var seen = {};
      var out = [];
      list.forEach(function(t){
        var k = (t.name + '|' + t.site_number).toLowerCase();
        if (!seen[k] && t.name && t.site_number){ seen[k] = true; out.push(t); }
      });
      return out;
    }

    // scan localStorage for arrays that look like teams
    var candidates = [];
    for (var i=0;i<localStorage.length;i++){
      var k = localStorage.key(i);
      try {
        var v = localStorage.getItem(k);
        var j = JSON.parse(v);
        if (looksLikeTeams(j)){
          j.forEach(function(o){ candidates.push(normalizeTeam(o)); });
        }
      } catch(_){}
    }
    candidates = uniqByNameSite(candidates);
    if (candidates.length === 0){ localStorage.setItem('WH_MIGRATED_TEAMS_TO_SB','yes'); return; }

    // fetch existing teams from Supabase to avoid duplicates
    fetch(base + '/rest/v1/teams?select=name,site_number&limit=1000', {method:'GET', headers:headers()})
      .then(function(r){ return r.ok ? r.json() : []; })
      .then(function(existing){
        var exist = {};
        existing.forEach(function(t){
          var k = (t.name + '|' + t.site_number).toLowerCase();
          exist[k] = true;
        });
        var toInsert = candidates.filter(function(t){
          var key = (t.name + '|' + t.site_number).toLowerCase();
          return !exist[key];
        });
        if (toInsert.length === 0){
          localStorage.setItem('WH_MIGRATED_TEAMS_TO_SB','yes');
          return;
        }
        // insert in small batches
        var chunk = 50, idx = 0;
        function next(){
          if (idx >= toInsert.length){
            localStorage.setItem('WH_MIGRATED_TEAMS_TO_SB','yes');
            return;
          }
          var batch = toInsert.slice(idx, idx+chunk);
          idx += chunk;
          fetch(base + '/rest/v1/teams', {
            method:'POST',
            headers:headers(),
            body: JSON.stringify(batch)
          }).then(function(){ next(); }).catch(function(){ next(); });
        }
        next();
      });
  } catch(e){
    // silent
  }
})();
"@
Write-Text $migratePath $migrateJs

# 3) onsite-sync-teams.js — runs on ONSITE page, populates team dropdown(s) from Supabase
$syncPath = Join-Path $WebRoot 'onsite-sync-teams.js'
$syncJs = @"
(function(){
  function base(){ return (window.WHOLEHOG && WHOLEHOG.sbProjectUrl || '').replace(/\/+$/,''); }
  function key(){  return (window.WHOLEHOG && WHOLEHOG.sbAnonKey) || ''; }
  function headers(){
    var k = key();
    return {'apikey':k,'Authorization':'Bearer '+k,'Content-Type':'application/json'};
  }
  function findTeamSelects(){
    var sels = Array.prototype.slice.call(document.querySelectorAll('select'));
    // Prefer selects whose id/name/class mentions 'team'
    var good = sels.filter(function(s){
      var id = (s.id||'').toLowerCase();
      var nm = (s.name||'').toLowerCase();
      var cl = (s.className||'').toLowerCase();
      return id.indexOf('team')>=0 || nm.indexOf('team')>=0 || cl.indexOf('team')>=0;
    });
    if (good.length) return good;
    // Fallback: first select with many text options like "Team (Site ...)"
    var guess = sels.filter(function(s){ return s.options && s.options.length >= 1; });
    return guess;
  }
  function label(t){ 
    var n = (t.name||'').trim();
    var s = (t.site_number||'').toString().trim();
    return s ? (n + ' (Site ' + s + ')') : n; 
  }
  function populate(selects, teams){
    if (!selects || !selects.length) return;
    var opts = teams.map(function(t){
      return '<option value="'+ (t.id||'') +'">'+ label(t) +'</option>';
    }).join('');
    selects.forEach(function(sel){
      var hasPlaceholder = sel.options.length && sel.options[0].value==="";
      var ph = hasPlaceholder ? sel.options[0].outerHTML : '<option value="">Select a team...</option>';
      sel.innerHTML = ph + opts;
    });
    // Expose to any other scripts
    window.WHOLEHOG = window.WHOLEHOG || {};
    window.WHOLEHOG.teams = teams;
  }
  function load(){
    var b = base(), k = key();
    if(!b || !k) return;
    fetch(b + '/rest/v1/teams?select=id,name,site_number&order=site_number.asc', {method:'GET', headers:headers()})
      .then(function(r){ return r.ok ? r.json() : []; })
      .then(function(list){
        var selects = findTeamSelects();
        populate(selects, list || []);
      })
      .catch(function(e){ console.warn('Team sync failed:', e); });
  }
  if (document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', load);
  } else {
    load();
  }
})();
"@
Write-Text $syncPath $syncJs

# 4) Inject the scripts into pages
$lh = Read-Text $landingHtml
$oh = Read-Text $onsiteHtml

$lh2 = Ensure-ScriptTag (Ensure-ScriptTag (Ensure-ScriptTag $lh  "supabase-config.js") "migrate-teams.js") "landing-teams.js"
# (If you don’t use landing-teams.js, this still no-ops; having the tag is harmless.)
$oh2 = Ensure-ScriptTag (Ensure-ScriptTag $oh "supabase-config.js") "onsite-sync-teams.js"

if($lh2 -ne $lh){ Write-Text $landingHtml $lh2; Write-Host "Updated landing.html script tags." -ForegroundColor Cyan }
if($oh2 -ne $oh){ Write-Text $onsiteHtml  $oh2; Write-Host "Updated onsite.html script tags."  -ForegroundColor Cyan }

Write-Host "Done. Open both pages and press Ctrl+F5 (hard refresh)." -ForegroundColor Green
