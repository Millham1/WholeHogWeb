# fix-landing-judges-and-teams.ps1  (PS 5.1 & 7)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path,$Content,[Text.Encoding]::UTF8)
}
function Backup-Once([string[]]$Files){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $WebRoot ("BACKUP_landing_fix_" + $stamp)
  $did = $false
  foreach($f in $Files){
    $p = Join-Path $WebRoot $f
    if(Test-Path $p){
      if(-not $did){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $did=$true }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($did){ Write-Host "Backup saved at: $bak" -ForegroundColor Yellow }
}

# -------- Helpers to remove duplicate Teams card --------
function Find-LastCardOpenBefore([string]$Html, [int]$Pos){
  # Find the last '<div ... class="...card..." ...>' whose end of tag occurs before $Pos
  $regex = New-Object System.Text.RegularExpressions.Regex '(?is)<div\b[^>]*class\s*=\s*(["'+"'" + '])[^"'+ "'" + ']*\bcard\b[^"'+ "'" + ']*\1[^>]*>'
  $m = $regex.Match($Html)
  $last = $null
  while($m.Success){
    if($m.Index + $m.Length -le $Pos){ $last = $m } else { break }
    $m = $m.NextMatch()
  }
  return $last
}
function Find-CardBlock([string]$Html, [int]$CardOpenIndex){
  # Starting at a known <div ...card...> tag, walk forward to find the matching closing </div>
  $openRegex  = New-Object System.Text.RegularExpressions.Regex '(?is)<div\b[^>]*>'
  $closeRegex = New-Object System.Text.RegularExpressions.Regex '(?is)</div\s*>'
  $pos = $CardOpenIndex
  $depth = 0
  # First tag at pos MUST be the card open
  $mOpen = $openRegex.Match($Html, $pos)
  if(-not $mOpen.Success -or $mOpen.Index -ne $CardOpenIndex){ return $null }
  $depth = 1
  $scanPos = $mOpen.Index + $mOpen.Length
  while($scanPos -lt $Html.Length){
    $mNextOpen  = $openRegex.Match($Html,  $scanPos)
    $mNextClose = $closeRegex.Match($Html, $scanPos)
    if(-not $mNextClose.Success -and -not $mNextOpen.Success){ break }
    $takeOpen = $false
    if($mNextOpen.Success -and $mNextClose.Success){
      $takeOpen = ($mNextOpen.Index -lt $mNextClose.Index)
    } elseif($mNextOpen.Success){
      $takeOpen = $true
    } else {
      $takeOpen = $false
    }
    if($takeOpen){
      $depth += 1
      $scanPos = $mNextOpen.Index + $mNextOpen.Length
    } else {
      $depth -= 1
      $scanPos = $mNextClose.Index + $mNextClose.Length
      if($depth -eq 0){
        return @{ Start = $CardOpenIndex; End = $scanPos; Length = ($scanPos - $CardOpenIndex) }
      }
    }
  }
  return $null
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }
$LandingHtml = Join-Path $WebRoot 'landing.html'
$LandingJs   = Join-Path $WebRoot 'landing-sb.js'
$SbCfg       = Join-Path $WebRoot 'supabase-config.js'

$missing = @()
foreach($f in @($LandingHtml,$SbCfg)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`r`n" + ($missing -join "`r`n")) }

Backup-Once @('landing.html','landing-sb.js')

# --- 1) Remove duplicate Teams cards ---
$html = Read-Text $LandingHtml
$opts = [System.Text.RegularExpressions.RegexOptions]::Singleline -bor `
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
# Find all h2s containing 'Team'
$h2Re = New-Object System.Text.RegularExpressions.Regex '(?is)<h2\b[^>]*>[^<]*Team[^<]*</h2>'
$h2Matches = $h2Re.Matches($html)
if($h2Matches.Count -gt 1){
  $cardRanges = New-Object System.Collections.Generic.List[object]
  for($i=0; $i -lt $h2Matches.Count; $i++){
    $h2 = $h2Matches[$i]
    $cardOpen = Find-LastCardOpenBefore -Html $html -Pos $h2.Index
    if($cardOpen -ne $null){
      $range = Find-CardBlock -Html $html -CardOpenIndex $cardOpen.Index
      if($range -ne $null){ $cardRanges.Add($range) }
    }
  }
  if($cardRanges.Count -gt 1){
    # Keep the first one (smallest Start), remove the rest from the end
    $ordered = $cardRanges | Sort-Object { $_.Start }
    $toRemove = @($ordered[1..($ordered.Count-1)])
    $toRemove = $toRemove | Sort-Object { $_.Start } -Descending
    foreach($r in $toRemove){
      $html = $html.Remove($r.Start, $r.Length)
    }
    Write-Text $LandingHtml $html
    Write-Host "Removed duplicate Teams card(s); kept the first." -ForegroundColor Cyan
  } else {
    Write-Host "Found multiple Team headers, but only one card container matched." -ForegroundColor DarkGray
  }
} else {
  Write-Host "Zero or one Teams header found; nothing to remove." -ForegroundColor DarkGray
}

# --- 2) Install robust landing-sb.js that auto-finds cards and lists judges (with remove) ---
$js = @'
(function(){
  "use strict";

  function byId(id){ return document.getElementById(id); }
  function qs(sel, root){ return (root||document).querySelector(sel); }
  function qsa(sel, root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }

  function makeHeaders(){
    return {
      "apikey": (window.WHOLEHOG && WHOLEHOG.sbAnonKey) || "",
      "Authorization": "Bearer " + ((window.WHOLEHOG && WHOLEHOG.sbAnonKey) || ""),
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    };
  }
  function apiUrl(path){
    var root = (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) || "";
    return root + path;
  }
  function sbGet(path){
    if(window.WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.get){
      return WHOLEHOG.sb.get(path).then(function(r){ return r.json(); });
    }
    return fetch(apiUrl(path), { method:"GET", headers: makeHeaders() }).then(function(r){ return r.json(); });
  }
  function sbPost(path, body){
    if(window.WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.post){
      return WHOLEHOG.sb.post(path, body).then(function(r){ return r.json(); });
    }
    return fetch(apiUrl(path), { method:"POST", headers: makeHeaders(), body: JSON.stringify(body) }).then(function(r){ return r.json(); });
  }
  function sbDelete(path){
    return fetch(apiUrl(path), { method:"DELETE", headers: makeHeaders() }).then(function(r){
      if(!r.ok) throw new Error("Delete failed: " + r.status);
      return true;
    });
  }

  function findCardByTitleWord(word){
    var cards = qsa(".card");
    for(var i=0;i<cards.length;i++){
      var h2 = qs("h2", cards[i]);
      if(!h2) continue;
      if((h2.textContent||"").toLowerCase().indexOf(word.toLowerCase()) !== -1){
        return cards[i];
      }
    }
    return null;
  }

  // ------- Teams (read-only) -------
  function ensureTeamsListEl(){
    var card = findCardByTitleWord("team");
    if(!card) return null;
    var list = byId("teamsList") || qs("#teamList", card) || qs("#teams-list", card);
    if(!list){
      list = document.createElement("div");
      list.id = "teamsList";
      // place after h2
      var h2 = qs("h2", card);
      if(h2 && h2.parentNode){ h2.parentNode.insertBefore(list, h2.nextSibling); }
      else { card.appendChild(list); }
    }
    return list;
  }
  function renderTeams(rows){
    var cont = ensureTeamsListEl();
    if(!cont) return;
    if(!rows || !rows.length){ cont.innerHTML = '<div class="muted">No teams yet.</div>'; return; }
    var html = '<ul class="simple-list">';
    rows.forEach(function(r){
      var label = r.name + (r.site_number ? " (Site " + r.site_number + ")" : "");
      html += "<li>" + label + "</li>";
    });
    html += "</ul>";
    cont.innerHTML = html;
  }
  function loadTeams(){
    sbGet("/rest/v1/teams?select=id,name,site_number&order=site_number.asc,name.asc")
      .then(renderTeams)
      .catch(function(){ /* ignore */ });
  }

  // ------- Judges (list + add + remove) -------
  function ensureJudgesListEl(){
    var card = findCardByTitleWord("judge");
    if(!card) return null;
    var list = byId("judgesList") || qs("#judges-list", card);
    if(!list){
      list = document.createElement("div");
      list.id = "judgesList";
      var h2 = qs("h2", card);
      if(h2 && h2.parentNode){ h2.parentNode.insertBefore(list, h2.nextSibling); }
      else { card.appendChild(list); }
    }
    return list;
  }
  function renderJudges(rows){
    var cont = ensureJudgesListEl();
    if(!cont) return;
    if(!rows || !rows.length){ cont.innerHTML = '<div class="muted">No judges yet.</div>'; return; }
    var html = '<ul class="judge-list">';
    rows.forEach(function(r){
      html += '<li class="judge-row"><span class="name">' + (r.name||"(unnamed)") + '</span> ' +
              '<button type="button" class="btn-remove" data-id="' + r.id + '">Remove</button></li>';
    });
    html += '</ul>';
    cont.innerHTML = html;
  }
  function loadJudges(){
    sbGet("/rest/v1/judges?select=id,name&order=name.asc")
      .then(renderJudges)
      .catch(function(){ /* ignore */ });
  }
  function hookJudgeAdd(){
    var card = findCardByTitleWord("judge");
    if(!card) return;

    // find/create input
    var inp = byId("judgeName") || qs('input[type="text"]', card);
    if(!inp){
      inp = document.createElement("input");
      inp.type = "text";
      inp.id = "judgeName";
      inp.placeholder = "Judge name";
      card.appendChild(inp);
    } else {
      inp.removeAttribute("disabled");
      inp.disabled = false;
      if(!inp.id) inp.id = "judgeName";
    }

    // find/create button
    var btn = byId("btnAddJudge") || qs('button, a', card);
    if(!btn || ((btn.textContent||"").toLowerCase().indexOf("add") === -1)){
      btn = document.createElement("button");
      btn.type = "button";
      btn.id = "btnAddJudge";
      btn.textContent = "Add Judge";
      card.appendChild(btn);
    } else {
      if(!btn.id) btn.id = "btnAddJudge";
    }

    btn.addEventListener("click", function(){
      var name = (inp.value||"").trim();
      if(!name){ alert("Enter judge name"); return; }
      sbPost("/rest/v1/judges", [{ name: name }]).then(function(resp){
        inp.value = "";
        loadJudges();
      }).catch(function(err){
        console.error(err);
        alert("Could not add judge.");
      });
    });
  }
  function hookJudgeRemove(){
    var list = ensureJudgesListEl();
    if(!list) return;
    list.addEventListener("click", function(ev){
      var t = ev.target;
      if(t && t.classList && t.classList.contains("btn-remove")){
        var id = t.getAttribute("data-id");
        if(!id) return;
        if(!confirm("Remove this judge?")) return;
        sbDelete("/rest/v1/judges?id=eq." + encodeURIComponent(id))
          .then(function(){ loadJudges(); })
          .catch(function(e){ console.error(e); alert("Could not remove judge."); });
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function(){
    loadTeams();
    loadJudges();
    hookJudgeAdd();
    hookJudgeRemove();
  });
})();
'@

Write-Text $LandingJs $js
Write-Host "Updated landing-sb.js with robust Teams/Judges logic." -ForegroundColor Cyan

Write-Host "`nDone. Hard-refresh landing.html (Ctrl+F5)." -ForegroundColor Green


